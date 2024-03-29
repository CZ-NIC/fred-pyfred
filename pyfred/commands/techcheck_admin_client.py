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
    sys.stderr.write("""techcheck_admin_client [options]

Options:
    -f, --file=FILENAME           Configuration file name.
    -c, --chunk=NUMBER            Obtain search records in chunks of given size.
    -h, --help                    Print this help message.
    -i, --nssetid=NUMBER          History ID of nsset.
    -k, --checkid=NUMBER          ID of technical check.
    -l, --lowerdate=DATETIME      Lower bound on execution date of check.
    -n, --nameservice=HOST[:PORT] Set host where CORBA nameservice runs.
    -x, --context=CONTEXT         Set CORBA nameservice context name.
    -r, --reason=REASON           Reason of technical check (one of ANY, EPP,
                                  MANUAL, REGULAR).
    -s, --status=STATUS           Overall status of technical test (0,1,2).
    -u, --uperdate=DATETIME       Upper bound on execution date of check.
    -v, --verbose                 Be verbose.

The format of DATETIME is '{YYYY}-{MM}-{DD}T{HH}:{MM}:{SS}'.
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

def convStatus(status):
    if status == 0:
        return "Passed"
    elif status == 1:
        return "Failed"
    return "Unknown"

def convReason(reason):
    if reason == ccReg.CHKR_EPP:
        return "EPP"
    if reason == ccReg.CHKR_MANUAL:
        return "MANUAL"
    if reason == ccReg.CHKR_REGULAR:
        return "REGULAR"
    return "Unknown"

def run_techcheck_admin_client():
    try:
        opts, args = getopt.getopt(sys.argv[1:],
                "c:hi:k:l:n:r:s:u:vf:x:", ["chunk=", "help", "nssetid=", "checkid=",
                    "lowerdate=", "nameservice=", "reason=", "status=", "upperdate=",
                    "verbose", "file=", "context="]
                )
    except getopt.GetoptError:
        usage()
        sys.exit(1)

    configfile = '/etc/fred/pyfred.conf'

    for o, a in opts:
        if o in ('-f', '--file'):
            configfile = a

    conf = ConfigParser.ConfigParser()
    conf.read(configfile)

    chunk = 1
    nssetid = -1
    checkid = -1
    lowerdate = ""
    nameservice = "localhost"
    context = "fred"
    reason = ccReg.CHKR_ANY
    status = -1
    upperdate = ""
    verbose = False

    if conf.has_option('General', 'nshost'):
        nameservice = conf.get('General', 'nshost')
    if conf.has_option('General', 'nsport'):
        nameservice = nameservice + ":" + conf.get('General', 'nsport')
    if conf.has_option('General', 'nscontext'):
        context = conf.get('General', 'nscontext')

    for o, a in opts:
        if o in ("-c", "--chunk"):
            chunk = int(a)
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-i", "--nssetid"):
            nssetid = int(a)
        if o in ("-k", "--checkid"):
            checkid = int(a)
        elif o in ("-l", "--lowerdate"):
            lowerdate = a
        elif o in ("-n", "--nameservice"):
            nameservice = a
        elif o in ("-r", "--reason"):
            if reason == "EPP":
                reason = ccReg.CHKR_EPP
            elif reason == "MANUAL":
                reason = ccReg.CHKR_MANUAL
            elif reason == "REGULAR":
                reason = ccReg.CHKR_REGULAR
            # ignore all other values
        elif o in ("-s", "--status"):
            status = int(a)
        elif o in ("-u", "--upperdate"):
            upperdate = a
        elif o in ("-v", "--verbose"):
            verbose = True
        elif o in ('-x', '--context'):
            context = a
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

    # construct filter
    if lowerdate:
        try:
            fromdate = str2date(lowerdate)
        except Exception, e:
            sys.stderr.write("Bad format of date. See usage (--help).\n")
            sys.exit(1)
    else:
        fromdate = str2date("0000-00-00T00:00:00")
    if upperdate:
        try:
            todate = str2date(upperdate)
        except Exception, e:
            sys.stderr.write("Bad format of date. See usage (--help).\n")
            sys.exit(1)
    else:
        todate = str2date("0000-00-00T00:00:00")

    check_filter = ccReg.CheckFilter(checkid, nssetid, status, reason,
            ccRegDateTimeInterval(ccReg, fromdate, todate))
    #
    # Call techcheck's function
    try:
        # download list of all enabled tests
        if verbose: print "Downloading test list ... ",
        testlist = tc_obj.checkGetTests()
        if verbose: print "ok"
        tests = {}
        for item in testlist:
            tests[item.id] = item
        # create search object
        if verbose: print "Submitting filter ... ",
        search_obj = tc_obj.createSearchObject(check_filter)
        if verbose: print "ok"
    except ccReg.TechCheck.InternalError, e:
        sys.stderr.write("Internal error on server: %s\n" % e.message)
        sys.exit(10)
    except Exception, e:
        sys.stderr.write("Corba call failed: %s\n" % e)
        sys.exit(3)

    try:
        # download results
        if verbose: print "Retrieving matched technical checks"
        print "*" * 50
        checks = [1]
        while checks:
            checks = search_obj.getNext(chunk)
            for check in checks:
                print "Technical check id: %d" % check.id
                print "Nsset history id:   %d" % check.nsset_hid
                print "Check date:         %s" % check.checkdate
                print "Reason:             %s" % convReason(check.reason)
                print "Overall status:     %s" % convStatus(check.status)
                for result in check.results:
                    print "    " + ("-" * 45)
                    print "    Test name:  %s" % tests[result.testid].name
                    print "    Test ID:    %d" % result.testid
                    print "    Level:      %d" % tests[result.testid].level
                    print "    Domain-cen: %s" % tests[result.testid].domain_centric
                    print "    Status:     %d" % result.status
                    print "    Note:       %s" % result.note
                    print "    Data:       %s" % result.data
                print "*" * 50
        search_obj.destroy()
    except ccReg.TechCheckSearch.NotActive, e:
        sys.stderr.write("Search object is not active.\n")
        sys.exit(11)
    except ccReg.TechCheckSearch.InternalError, e:
        sys.stderr.write("Internal error on server: %s\n" % e.message)
        sys.exit(10)


if __name__ == "__main__":
    run_techcheck_admin_client()
