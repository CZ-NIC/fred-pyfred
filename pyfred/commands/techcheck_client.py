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


def usage():
    """
    Print usage information.
    """
    sys.stderr.write("""techcheck_client [options] NSSET

    NSSET is handle of nsset which should be tested and must be given.

Options:
    -e, --file=FILE               Configuration file name.
    -c, --cltestid=STRING         ID of test assigned by client.
    -d, --dig                     Dig all domain fqdns which use nsset and
                                  test them too.
    -f, --fqdn=NAME               FQDN of domain which should be tested with
                                  nsset. May be specified multipletimes.
    -h, --help                    Print this help message.
    -l, --level=NUMBER            Explicit specification of test level (1-10).
    -n, --nameservice=HOST[:PORT] Set host where CORBA nameservice runs.
    -x, --context=CONTEXT         Set CORBA nameservice context name.
    -r, --regid                   Set handle of registrator whom should be
                                  queued the message with results. This means
                                  that the test will be run asynchronously.
    -s, --save                    Save the result of tech check in database.

Option cltestid is taken into account only if running in asynchronous mode.
""")

def convStatus(status):
    if status == 0:
        return "Passed"
    elif status == 1:
        return "Failed"
    return "Unknown"

def run_techcheck_client():
    try:
        opts, args = getopt.getopt(sys.argv[1:],
                "c:df:hl:n:r:se:x:",
                ["cltestid=", "dig", "fqdn=", "help", "level=", "nameservice=",
                    "regid=", "save", "file=", "context="]
                )
    except getopt.GetoptError:
        usage()
        sys.exit(1)

    configfile = '/etc/fred/pyfred.conf'

    for o, a in opts:
        if o in ('-e', '--file'):
            configfile = a

    conf = ConfigParser.ConfigParser()
    conf.read(configfile)

    cltestid = ""
    dig = False
    fqdn = []
    level = 0
    nameservice = "localhost"
    context = "fred"
    regid = False
    save = False

    if conf.has_option('General', 'nshost'):
        nameservice = conf.get('General', 'nshost')
    if conf.has_option('General', 'nsport'):
        nameservice = nameservice + ":" + conf.get('General', 'nsport')
    if conf.has_option('General', 'nscontext'):
        context = conf.get('General', 'nscontext')

    for o, a in opts:
        if o in ("-c", "--cltestid"):
            cltestid = a
        elif o in ("-d", "--dig"):
            dig = True
        elif o in ("-f", "--fqdn"):
            fqdn.append(a)
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-l", "--level"):
            level = int(a)
        elif o in ("-n", "--nameservice"):
            nameservice = a
        elif o in ("-r", "--regid"):
            regid = a
        elif o in ("-s", "--save"):
            save = True
        elif o in ('-x', '--context'):
            context = a

    # last argument must be nsset
    if len(sys.argv) < 2:
        usage()
        sys.exit(2)
    nsset = sys.argv[-1]
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
        sys.exit(1)
    # Resolve the name "fred.context/TechCheck.Object"
    name = [CosNaming.NameComponent(context, "context"),
            CosNaming.NameComponent("TechCheck", "Object")]
    try:
        obj = rootContext.resolve(name)
    except CosNaming.NamingContext.NotFound, e:
        sys.stderr.write("Could not get object's reference. Is object "
                "registered? (%s)\n" % e)
        sys.exit(1)
    # Narrow the object to an ccReg::TechCheck
    tc_obj = obj._narrow(ccReg.TechCheck)
    if (tc_obj is None):
        sys.stderr.write("Object reference is not a ccReg::TechCheck\n")
        sys.exit(1)

    #
    # Call techcheck's function
    try:
        if regid:
            tc_obj.checkNssetAsynch(regid, nsset, level, dig, save,
                    ccReg.CHKR_MANUAL, fqdn, cltestid)
            print "Asynchronous technical check was successfuly submitted."
            return # there is nothing to be printed
        # synchronous technical test
        testlist = tc_obj.checkGetTests()
        results, checkid, status = tc_obj.checkNsset(nsset, level, dig, save,
                    ccReg.CHKR_MANUAL, fqdn)
    except ccReg.TechCheck.InternalError, e:
        sys.stderr.write("Internal error on server: %s\n" % e.message)
        sys.exit(10)
    except ccReg.TechCheck.NssetNotFound, e:
        sys.stderr.write("Nsset does not exist.\n")
        sys.exit(11)
    except Exception, e:
        sys.stderr.write("Corba call failed: %s\n" % e)
        sys.exit(3)
    # Print result of synchronous tech check
    tests = {}
    for item in testlist:
        tests[item.id] = item
    print "--- Status report ------------------------------------"
    print
    print "Check id: %d" % checkid
    print "Overall status: %s" % convStatus(status)
    print "Results of individual tests:"
    for result in results:
        print "Test's name:        %s" % tests[result.testid].name
        print "    Test ID:        %d" % result.testid
        print "    Level:          %d" % tests[result.testid].level
        print "    Domain-centric: %s" % tests[result.testid].domain_centric
        print "    Status:         %s" % convStatus(result.status)
        print "    Note:           %s" % result.note
        print "    Data:           %s" % result.data
    print
    print "--- End of Status report -----------------------------"

if __name__ == "__main__":
    run_techcheck_client()
