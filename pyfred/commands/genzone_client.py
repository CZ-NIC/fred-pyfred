#!/usr/bin/python2
#
# Copyright (C) 2007-2021  CZ.NIC, z. s. p. o.
#
# This file is part of FRED.
#
# FRED is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# FRED is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FRED.  If not, see <https://www.gnu.org/licenses/>.

"""
Script for generating zone file for given zone name.

The script uses zone module which encapsulates complexity of CORBA communication.
"""
import commands
import ConfigParser
import difflib
import getopt
import os.path
import re
import shutil
import sys
import tempfile
import time

import pyfred.zone


def pcb():
    """
    Definition of progress callback. This callback prints one dot to stderr
    each time it is called.
    """
    sys.stderr.write('.')

def usage():
    """
    Print usage information.
    """
    sys.stdout.write(
"""%s [options] [zone1 zone2 ...]

Script for generating zone file(s) for given zone(s) in BIND format.
The generated zone files are saved in directory zonedir under name
db.{zonename}. If there is any previous file of the same name, it is
automatically backuped in backupdir. If anything during this process
failes, the original zone file stays intact.

Either create configuration file or use command line options. Default
configuration file is /etc/fred/genzone.conf. Command line options override
config options. Whereas in config file each zone can have its own options,
the option on command line holds for all generated zones.

If you run the script and don't specify any zone to be generated, then
zones from config file will be GENERATED. If you run the script and specify
zone(s) to be generated on command line, then the zones to be generated from
config file will be IGNORED!

options:
    -b, --backupdir=PATH          Directory used for zone file backups (default
                                  is the zonedir directory).
    -c, --chunk=NUMBER            Number of domains transfered in one CORBA
                                  call.
    -e, --header=PATH             Path to file which will be prepended to zone
                                  file.
    -f, --file=PATH               Configuration file for genzone.
    -h, --help                    Print this information.
    -m, --maxchanges=NUMBER[%%]    Maximal number of changed lines compared to
                                  previously generated zone. If you prepend '%%'
                                  to the number, then it means a procentual
                                  change.
    -n, --nameservice=HOST[:port] Set host where corba nameservice runs.
    -x, --context=STRING          Set context in corba nameservice.
    -o, --nobackups               Disable creation of zone backups.
    -p, --post-hook=CMDLINE       Execute specified command line after every
                                  zone is generated (see README).
    -v, --verbose                 Print progress graf to stderr (one dot
                                  represents one transfered chunk).
    -t, --footer=PATH             Path to file which will be appended to zone
                                  file.
    -z, --zonedir=PATH            Directory where the zone file(s) should be
                                  generated (default is current directory).
    -g, --bind-conf=PATH          Path to file where bind configuration
                                  will be generated

Option maxchanges is taken into account only if the previous zone file is found.
""" % sys.argv[0])

class ZoneConfig (object):
    """
    Genzone has its own class for configuration because the configuration
    schema is quite difficult. Each configuration option may be individualy
    set for each zone.
    """
    config = {}

    def __init__(self, zones):
        """
        This function initializes configuration with default values.
        """
        for zone in zones:
            self.config[zone] = {}
            zconf = self.config[zone]
            # set zone specific default values
            zconf["backupdir"] = None
            zconf["nobackups"] = False
            zconf["chunk"] = 100
            zconf["footer"] = None
            zconf["header"] = None
            zconf["maxchanges"] = -1
            zconf["mchproc"] = False # procentual change
            zconf["post-hook"] = ""
            zconf["zonedir"] = "./"

    def set(self, name, value, zone=""):
        """
        This function sets config value for all zones if optional zone parameter
        is not specified, or just for the specified zone.
        """
        if zone:
            self.config[zone][name] = value
            return
        for key in self.config:
            self.config[key][name] = value

    def weekset(self, name, value):
        """
        This function sets config value for all zones if the current value
        is evaluated as false in 'if' condition.
        """
        for key in self.config:
            if not self.config[key][name]:
                self.config[key][name] = value

    def get(self, name, zone):
        """
        This function gets configuration value for specific zone.
        """
        return self.config[zone][name]

def hook_subst(hookcmd, subst_dict):
    """
    Substitute special sequences in hook command line.
    """
    for key in subst_dict:
        hookcmd = hookcmd.replace('$' + key, subst_dict[key])
    return hookcmd


def run_genzone_client():
    try:
        # parse command line parameters
        opts, zonenames = getopt.getopt(sys.argv[1:],
                "b:c:e:f:hm:n:op:vt:z:x:g:",
                ["backupdir=", "chunk=", "header=", "file=", "help",
                 "maxchanges=", "nameservice=", "nobackups", "post-hook=",
                 "verbose", "footer=", "zonedir=", "context=", "bind-conf="])
    except getopt.GetoptError:
        usage()
        sys.exit(2)

    # set default values which are not zone specific
    configfile = '/etc/fred/genzone.conf'
    nameservice = "localhost"
    corba_context = "fred"
    pcb_param = None # progress callback
    verbose = False
    bind_conf = None

    # get only location of config file, the other options will be parsed later
    for o, a in opts:
        if o in ("-f", "--file"):
            configfile = a

    # read configuration file
    config = ConfigParser.ConfigParser()
    config.read(configfile)
    # set not zone specific configuration values
    if config.has_option("general", "nameservice"):
        nameservice = config.get("general", "nameservice")
    if config.has_option("general", "context"):
        corba_context = config.get("general", "context")
    if config.has_option("general", "verbose"):
        verbose = config.getboolean("general", "verbose")
        if verbose: pcb_param = pcb

    # get only nameservice the other options will be parsed later
    # because server must be contacted to gain list of all zones
    for o, a in opts:
        if o in ("-n", "--nameservice"):
            nameservice = a
        elif o in ("-x", "--context"):
            corba_context = a

    # process zones to be generated from config file only if there aren't any
    # on command line
    if len(zonenames) == 0:
        if config.has_option("general", "zones"):
            zonenames = config.get("general", "zones").split()

    # if no zones were specified in config file or on cmd line, then
    # load all zones from register
    if len(zonenames) == 0:
        zonenames = pyfred.zone.ZoneGeneratorObject().getObject(
            ns=nameservice, context=corba_context).getZoneNameList()
        if len(zonenames) == 0:
            usage()
            sys.exit(2)

    # create config and set default values which are zone specific
    zoneconf = ZoneConfig(zonenames)

    # set zone specific configuration values for each zone
    for zonename in zonenames:
        if config.has_option(zonename, "backupdir"):
            zoneconf.set("backupdir", config.get(zonename, "backupdir"),
                    zonename)
        if config.has_option(zonename, "chunk"):
            zoneconf.set("chunk", config.getint(zonename, "chunk"), zonename)
        if config.has_option(zonename, "header"):
            zoneconf.set("header", config.get(zonename, "header"), zonename)
        if config.has_option(zonename, "footer"):
            zoneconf.set("footer", config.get(zonename, "footer"), zonename)
        if config.has_option(zonename, "maxchanges"):
            value = config.get(zonename, "maxchanges")
            if value[-1] == '%':
                zoneconf.set("maxchanges", int(value[:-1]), zonename)
                zoneconf.set("mchproc", True, zonename)
            else:
                zoneconf.set("maxchanges", int(value), zonename)
        if config.has_option(zonename, "post-hook"):
            zoneconf.set("post-hook", config.get(zonename, "post-hook"), zonename)
        if config.has_option(zonename, "zonedir"):
            zoneconf.set("zonedir", config.get(zonename, "zonedir"), zonename)
        if config.has_option(zonename, "nobackups"):
            zoneconf.set("nobackups", config.getboolean(zonename, "nobackups"),
                    zonename)

    # get command line parameters' values
    for o, a in opts:
        if o in ("-b", "--backupdir"):
            zoneconf.set("backupdir", a)
        elif o in ("-c", "--chunk"):
            zoneconf.set("chunk", int(a))
        elif o in ("-e", "--header"):
            zoneconf.set("header", a)
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-m", "--maxchanges"):
            if a[-1] == '%':
                zoneconf.set("maxchanges", int(a[:-1]))
                zoneconf.set("mchproc", True)
            else:
                zoneconf.set("maxchanges", int(a))
        elif o in ("-o", "--nobackups"):
            zoneconf.set("nobackups", True)
        elif o in ("-p", "--post-hook"):
            zoneconf.set("post-hook", a)
        elif o in ("-v", "--verbose"):
            verbose = True
            pcb_param = pcb
        elif o in ("-t", "--footer"):
            zoneconf.set("footer", a)
        elif o in ("-z", "--zonedir"):
            zoneconf.set("zonedir", a)
        elif o in ("-g", "--bind-conf"):
            bind_conf = a

    # if backupdir is not set, it will be the same as zonedir
    for zone in zonenames:
        zoneconf.weekset("backupdir", zoneconf.get("zonedir", zone))

    # generate temporary zone files
    zonefiletmps = {}
    for zone in zonenames:
        if verbose: sys.stderr.write("Generating zone %s.\n" % zone)
        # open temporary output file for zone
        zonefiletmps[zone] = tempfile.TemporaryFile()

        # prepend contents of header file to zone file
        headerfile = zoneconf.get("header", zone)
        if headerfile:
            try:
                headerfd = open(headerfile, "r")
                zonefiletmps[zone].write(headerfd.read())
                headerfd.close()
            except Exception, e:
                sys.stderr.write("Error when reading header file %s: %s\n" %
                        (headerfile, e))
                sys.exit(1)

        # create BIND output filter
        bind_filter = pyfred.zone.BindFilter(zonefiletmps[zone])
        try:
            # initialize zone generator
            zone_obj = pyfred.zone.Zone(bind_filter, zone, ns=nameservice,
                    context=corba_context,
                    chunk=zoneconf.get("chunk", zone),
                    progress_callback=pcb_param)
            zone_obj.dump() # this will do the rest of the work
            zone_obj.cleanup() # cleanup server-side resources
        except pyfred.zone.ZoneException, e:
            sys.stderr.write("Error when generating zone: %s\n" % e)
            sys.exit(1)

        # append contents of header file to zone file
        footerfile = zoneconf.get("footer", zone)
        if footerfile:
            try:
                footerfd = open(footerfile, "r")
                zonefiletmps[zone].write(footerfd.read())
                footerfd.close()
            except Exception, e:
                sys.stderr.write("Error when reading footer file %s: %s\n" %
                        (footerfile, e))
                sys.exit(1)

    # backup old zone files and overwrite them with new ones
    timesuffix = "-%04d%02d%02d%02d%02d%02d" % time.localtime()[:6]
    error_zones = []
    for zone in zonefiletmps:
        zonefile = "db." + zone
        zonedir = zoneconf.get("zonedir", zone)
        zonefilepath = os.path.join(zonedir, zonefile)
        zonetmpfd = zonefiletmps[zone]
        zonetmpfd.seek(0) # rewind the temp file to beginning
        backupfile = "" # reinitialized later in code
        try:
            # if zone file already exists, we have to check amount of changes
            if os.access(zonefilepath, os.R_OK):
                # check the maxchanges constraint if it is active
                if zoneconf.get("maxchanges", zone) >= 0:
                    oldzonefd = open(zonefilepath, "r")
                    oldzonelines = oldzonefd.read().splitlines()
                    oldzonefd.close()
                    totallines = len(oldzonelines)
                    diffgen = difflib.unified_diff(oldzonelines,
                            zonetmpfd.read().splitlines(), "", "", "", "", 0, "")
                    # count changed lines
                    comp = re.compile("^@@ -\d+,(\d+) \+\d+,(\d+) @@$")
                    changedlines = 0
                    for line in diffgen:
                        matchobj = comp.match(line)
                        if matchobj:
                            c1, c2 = matchobj.groups()
                            if c1 >= c2:
                                changedlines += int(c1)
                            else:
                                changedlines += int(c2)
                    changedlines -= 1 # ignore change in serial number
                    if zoneconf.get("mchproc", zone):
                        percents = changedlines * 100 / totallines
                        if (percents > zoneconf.get("maxchanges", zone)):
                            raise Exception("%d%% of zone have changed!" %
                                    percents)
                    else:
                        if (changedlines > zoneconf.get("maxchanges", zone)):
                            raise Exception("%d zone records have changed!" %
                                    changedlines)
                    zonetmpfd.seek(0) # rewind the temp file to beginning
                # do backup if backups are not disabled
                if not zoneconf.get("nobackups", zone):
                    backupdir = zoneconf.get("backupdir", zone)
                    backupfile = os.path.join(backupdir, zonefile + timesuffix)
                    # the backup dir will be created if it does not exist
                    try:
                        if not os.access(backupdir, os.F_OK):
                            os.makedirs(backupdir)
                    except Exception, e:
                        os.makedirs(backupdir)
                    # copy zone file to backup directory
                    shutil.copy(zonefilepath, backupfile)
            # overwrite old zone file
            zonefd = open(zonefilepath, "w")
            zonefd.write(zonetmpfd.read())
            zonefd.close()
            # run hook if it is configured
            if zoneconf.get("post-hook", zone):
                subst_dict = { "file":zonefilepath,
                               "zone":zone,
                               "backup":backupfile }
                cmd = hook_subst(zoneconf.get("post-hook", zone), subst_dict)
                if verbose:
                    sys.stderr.write("Running post-hook: %s\n" % cmd)
                status, output = commands.getstatusoutput(cmd)
                if os.WEXITSTATUS(status) != 0:
                    sys.stderr.write("Error when running post-hook "
                            "(status = %d).\n%s\n" % (status, output))
                elif verbose:
                    sys.stderr.write(output)
        except Exception, e:
            sys.stderr.write("Error when overwriting old zone file %s. The "
                    "zone stays unchanged! (error: %s)\n" % (zonefile, e))
            error_zones.append(zone)

    if error_zones:
        sys.exit(-1)

    # generate bind configuration file
    if bind_conf:
        bconf = open(bind_conf, "w")
        for zone in zonenames:
            bconf.write("zone \"%s\" IN {\n" % zone)
            bconf.write("        type master;\n")
            bconf.write("        file \"%s/db.%s\";\n" % (zonedir, zone))
            bconf.write("};\n\n")

    sys.exit()

if __name__ == "__main__":
    run_genzone_client()
