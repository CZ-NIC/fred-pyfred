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
This is a simple nagios compatible script, which tests functionality of
CORBA genzone server. Nagios compatible means, that its return code and
output is in accordance to nagios expectations.

Tester sends a request for zone transfer and then closes the transfer without
transfering any data (only SOA record is transferred as result of openning
transaction). Therefore this test is not resource demanding.
"""
import ConfigParser
import getopt
import sys

import pyfred.zone


def usage():
    """
    Print usage information.
    """
    sys.stdout.write(
"""%s [-hn] zone

Script for testing functionality of genzone CORBA server. Last argument 'zone'
is a name of a zone for which should be retrieved a SOA record.

options:
    --help (-h)             Print this information.
    --ns (-n) host[:port]   Corba nameservice location. Default is localhost.
    --file (-f) filename    Configuration filename.
""" % sys.argv[0])


def run_check_pyfred_genzone():
    if len(sys.argv) < 2 or sys.argv[-1].startswith('-'):
        usage()
        sys.exit(2)
    # parse command line parameters
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hn:", ["help", "ns="])
    except getopt.GetoptError:
        usage()
        sys.exit(2)
    # set default values
    configfile = '/etc/fred/genzone.conf'
    nameservice = "localhost"
    zonename = sys.argv[-1]
    # get parameters
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-f", "--file"):
            configfile = a

    # initialize config parser and read config file
    config = ConfigParser.ConfigParser()
    config.read(configfile)
    # load nameservice option if present in config file
    if config.has_option("general", "nameservice"):
        nameservice = config.get("general", "nameservice")

    # now load command line options for nameservice if present
    for o, a in opts:
        if o in ('-n', '--ns'):
            nameservice = a

    try:
        # initialize zone generator
        zone_obj = pyfred.zone.Zone(None, zonename, nameservice)
    except pyfred.zone.ZoneException, e:
        print "GENZONE CRITICAL - initialization of transfer failed:", e
        sys.exit(2)
    print "GENZONE OK"
    sys.exit()


if __name__ == "__main__":
    run_check_pyfred_genzone()
