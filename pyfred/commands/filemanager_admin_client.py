#!/usr/bin/python2
#
# Copyright (C) 2006-2021  CZ.NIC, z. s. p. o.
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

import ConfigParser
import getopt
import sys

import CosNaming
from fred_idl import ccReg
from omniORB import CORBA

from pyfred.utils import ccRegDateTimeInterval


def usage():
    """
    Print usage information.
    """
    sys.stderr.write("""filemanager_admin_client [options]

Script is a testing utility for admin interface of filemanager daemon.
You can constraint search by various criteria given on command line.

Options:
    -f, --file=FILENAME           File with configuration options.
    -c, --chunk=NUMBER            Obtain files in chunks of given size.
    -e, --enumtype                List enumetation of possible file types.
    -h, --help                    Print this help message.
    -i, --id=NUMBER               Get file with given ID.
    -l, --label=NAME              Get files with given label (name).
    -n, --nameservice=HOST[:PORT] Set host where CORBA nameservice runs.
    -c, --context=CONTEXT         Set CORBA nameservice context name.
    -m, --mime=TYPE               Get file with given MIME type.
    -o, --lowerdate=DATETIME      Lower bound on creation date of file.
    -p, --path=PATH               Get file stored under given path.
    -t, --type=NUMBER             Get file of given type.
    -u, --upperdate=DATETIME      Upper bound on creation date of file.
    -v, --verbose                 Switch to verbose mode.

The format of DATETIME is '{YYYY}-{MM}-{DD}T{HH}:{MM}:{SS}'.
Type of file may be zero for indication of non-typed file.
Option --enumtype may not be combined with any other option.
""")

def str2date(str):
    """
    Convert string to datetime CORBA structure.
    """
    if len(str) != 19:
        raise Exception("Bad format of date")
    year = int(str[:4])
    month = int(str[5:7])
    day = int(str[8:10])
    hour = int(str[11:13])
    minute = int(str[14:16])
    second = int(str[17:19])
    date = ccReg.DateType(day, month, year)
    return ccReg.DateTimeType(date, hour, minute, second)

def run_filemanager_admin_client():
    try:
        opts, args = getopt.getopt(sys.argv[1:],
                "f:c:ehi:l:n:c:m:o:p:t:u:v",
                ["file=", "chunk=", "enumtype", "help", "id=", "label=",
                "nameservice=", "context=", "mime=", "lowerdate=", "path=",
                "type=", "upperdate=", "verbose"]
                )
    except getopt.GetoptError:
        usage()
        sys.exit(1)

    configfile = '/etc/fred/pyfred.conf'

    for o, a in opts:
        if o in ('-f', '--file'):
            configfile = a

    conf = ConfigParser.SafeConfigParser({
        'nameservice':'localhost',
        'context':'fred',
        })
    conf.read(configfile)

    chunk = 1
    listtypes = False
    id = -1
    label = ""
    # pyfred.conf file has nameservice host and nameservice port options
    # separated into two, so merged is needed.
    nameservice = conf.get('General', 'nshost')
    if conf.has_option('General', 'nsport'):
        nameservice = nameservice + ":" + conf.get('General', 'nsport')

    context = conf.get('General', 'context')
    mime = ""
    path = ""
    type = -1
    verbose = False
    l_crdate = ""
    u_crdate = ""
    for o, a in opts:
        if o in ("-c", "--chunk"):
            chunk = int(a)
        elif o in ("-e", "--enumtype"):
            listtypes = True
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-i", "--id"):
            id = int(a)
        elif o in ("-l", "--label"):
            label = a
        elif o in ("-n", "--nameservice"):
            nameservice = a
        elif o in ("-c", "--context"):
            context = a
        elif o in ("-m", "--mime"):
            mime = a
        elif o in ("-o", "--lowerdate"):
            l_crdate = a
        elif o in ("-p", "--path"):
            path = a
        elif o in ("-t", "--type"):
            type = int(a)
        elif o in ("-v", "--verbose"):
            verbose = True
        elif o in ("-u", "--upperdate"):
            u_crdate = a
    #
    if l_crdate:
        try:
            fromdate = str2date(l_crdate)
        except Exception, e:
            sys.stderr.write("Bad format of date. See usage (--help).\n")
            sys.exit(1)
    else:
        fromdate = str2date("0000-00-00T00:00:00")
    if u_crdate:
        try:
            todate = str2date(u_crdate)
        except Exception, e:
            sys.stderr.write("Bad format of date. See usage (--help).\n")
            sys.exit(1)
    else:
        todate = str2date("0000-00-00T00:00:00")
    #
    # Initialise the ORB
    orb = CORBA.ORB_init(["-ORBnativeCharCodeSet", "UTF-8",
            "-ORBInitRef", "NameService=corbaname::" + nameservice],
            CORBA.ORB_ID)
    # Obtain a reference to the root naming context
    obj = orb.resolve_initial_references("NameService")
    rootContext = obj._narrow(CosNaming.NamingContext)
    if rootContext is None:
        sys.stderr.write("Failed to narrow the root naming context\n")
        sys.exit(2)
    # Resolve the name "fred.context/FileManager.Object"
    name = [CosNaming.NameComponent(context, "context"),
            CosNaming.NameComponent("FileManager", "Object")]
    try:
        obj = rootContext.resolve(name)
    except CosNaming.NamingContext.NotFound, e:
        sys.stderr.write("Could not get object's reference. Is object "
                "registered? (%s)\n" % e)
        sys.exit(2)
    # Narrow the object to an ccReg::FileManager
    fm_obj = obj._narrow(ccReg.FileManager)
    if (fm_obj is None):
        sys.stderr.write("Object reference is not ccReg::FileManager\n")
        sys.exit(2)

    # if we were asked just to get filetypes, do it quickly and exit
    if listtypes:
        try:
            typelist = fm_obj.getTypeEnum()
        except ccReg.FileManager.InternalError, e:
            sys.stderr.write("Internal error on server: %s\n" % e.message)
            sys.exit(10)
        except Exception, e:
            sys.stderr.write("Corba call failed: %s\n" % e)
            sys.exit(3)
        for type in typelist:
            print "%d\t%s" % (type.id, type.name)
        sys.exit()

    if verbose: print "Constructing filter ... ",
    interval = ccRegDateTimeInterval(ccReg, fromdate, todate)
    filter = ccReg.FileFilter(id, label, path, mime, type, interval)
    if verbose: print "ok"
    #
    # Obtain search object
    try:
        if verbose: print "Obtaining search object ... ",
        search_object = fm_obj.createSearchObject(filter)
        if verbose: print "done"
    except ccReg.FileManager.InternalError, e:
        if verbose: print "failed"
        sys.stderr.write("Internal error on server: %s\n" % e.message)
        sys.exit(10)
    except Exception, e:
        if verbose: print "failed"
        sys.stderr.write("Corba call failed: %s\n" % e)
        sys.exit(3)
    #
    # Retrieve results
    try:
        files = [1]
        print "Retrieving matched file information"
        print "*" * 50
        while files:
            files = search_object.getNext(chunk)
            for file in files:
                print "id: %d" % file.id
                print "name: %s" % file.name
                print "mime: %s" % file.mimetype
                print "type: %d" % file.filetype
                print "path: %s" % file.path
                print "creation date: %s" % file.crdate
                print "size: %d" % file.size
                print "*" * 50
        print "End of data transfer"
        search_object.destroy()
    except ccReg.FileSearch.NotActive, e:
        sys.stderr.write("Search object is not active anymore.\n")
        sys.exit(11)
    except ccReg.FileSearch.InternalError, e:
        sys.stderr.write("Internal error on server: %s\n" % e.message)
        sys.exit(12)
    print "Work done successfully"

if __name__ == "__main__":
    run_filemanager_admin_client()
