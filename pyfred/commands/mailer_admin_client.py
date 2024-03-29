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
    sys.stderr.write("""mailer_admin_client <command> [options]

Script is a testing utility for admin interface of mailer daemon.
Command is one of resend, listtypes or search. You can constraint
search in mail archive by various criteria given on command line.

Options of resend:
    -i, --id NUMBER               Get messages with given ID.

Options of search:
    -a, --attachment=NAME         Get messages with given attachment.
    -c, --chunk=NUMBER            Obtain messages in chunks of given size.
    -f, --fulltext=STRING         Get messages containing given string.
    -i, --id=NUMBER               Get messages with given ID.
    -l, --handle=NAME             Get messages with given associated handle.
    -o, --lowerdate=DATETIME      Lower bound on creation date of email.
    -q, --quiet                   Do not display mail bodies.
    -s, --status=NUMBER           Get messages with given status.
    -t, --type=NUMBER             Id of mail type.
    -u, --upperdate=DATETIME      Upper bound on creation date of email.

Common options for all three commands:
    -h, --help                    Print this help message.
    -e, --file=FILENAME           Configuration file.
    -n, --nameservice=HOST[:PORT] Set host where CORBA nameservice runs.
    -x, --context=CONTEXT         Set CORBA nameservice context name.
    -v, --verbose                 Switch to verbose mode.

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

def run_mailer_admin_client():
    if len(sys.argv) < 2:
        usage()
        sys.exit(1)
    command = sys.argv[1]
    if command not in ("resend", "listtypes", "search"):
        usage()
        sys.exit(1)
    try:
        opts, args = getopt.getopt(sys.argv[2:],
                "a:c:f:hi:l:n:o:qs:t:u:ve:x:",
                ["attachment=", "chunk=", "fulltext=", "help", "id=", "handle=",
                    "nameservice=", "lowerdate=", "quiet", "status=", "type=",
                    "upperdate=", "verbose", "file=", "context="]
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

    attach = -1
    chunk = 1
    fulltext = ""
    mailid = -1
    handle = ""
    nameservice = "localhost"
    context = "fred"
    quiet = False
    status = -1
    mailtype = -1
    verbose = False
    l_crdate = ""
    u_crdate = ""

    if conf.has_option('General', 'nshost'):
        nameservice = conf.get('General', 'nshost')
    if conf.has_option('General', 'nsport'):
        nameservice = nameservice + ":" + conf.get('General', 'nsport')
    if conf.has_option('General', 'nscontext'):
        context = conf.get('General', 'nscontext')

    for o, a in opts:
        if o in ("-a", "--attachment"):
            attach = int(a)
        if o in ("-c", "--chunk"):
            chunk = int(a)
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-f", "--fulltext"):
            fulltext = a
        elif o in ("-i", "--id"):
            mailid = int(a)
        elif o in ("-l", "--handle"):
            handle = a
        elif o in ("-n", "--nameservice"):
            nameservice = a
        elif o in ("-o", "--lowerdate"):
            l_crdate = a
        elif o in ("-q", "--quiet"):
            quiet = True
        elif o in ("-s", "--status"):
            status = int(a)
        elif o in ("-t", "--type"):
            mailtype = int(a)
        elif o in ("-u", "--upperdate"):
            u_crdate = a
        elif o in ("-v", "--verbose"):
            verbose = True
        elif o in ("-x", "--context"):
            context = a
    #
    if command == "resend" and mailid == -1:
        sys.stderr.write("resend needs option --id\n")
        sys.exit(1)
    if l_crdate:
        try:
            fromdate = str2date(l_crdate)
        except Exception, e:
            sys.stderr.write("Bad format of date. See usage "
                    "(--help).\n")
            sys.exit(1)
    else:
        fromdate = str2date("0000-00-00T00:00:00")
    if u_crdate:
        try:
            todate = str2date(u_crdate)
        except Exception, e:
            sys.stderr.write("Bad format of date. See usage "
                    "(--help).\n")
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
    # Resolve the name "fred.context/Mailer.Object"
    name = [CosNaming.NameComponent(context, "context"),
            CosNaming.NameComponent("Mailer", "Object")]
    try:
        obj = rootContext.resolve(name)
    except CosNaming.NamingContext.NotFound, e:
        sys.stderr.write("Could not get object's reference. Is object "
                "registered? (%s)\n" % e)
        sys.exit(2)
    # Narrow the object to an ccReg::Mailer
    mailer_obj = obj._narrow(ccReg.Mailer)
    if (mailer_obj is None):
        sys.stderr.write("Object reference is not a ccReg::Mailer\n")
        sys.exit(2)

    if command == "listtypes":
        try:
            list = mailer_obj.getMailTypes()
        except ccReg.Mailer.InternalError, e:
            sys.stderr.write("Internal error on server: %s\n" %
                    e.message)
            sys.exit(10)
        except Exception, e:
            sys.stderr.write("Corba call failed: %s\n" % e)
            sys.exit(3)
        print "Mapping between existing IDs and names of email types:"
        for item in list:
            print "  %02d - %s" % (item.id, item.name)
        sys.exit(0)

    if command == "resend":
        try:
            mailer_obj.resend(mailid)
        except ccReg.Mailer.UnknownMailid, e:
            sys.stderr.write("Unknown id %d of archived mail.\n" %
                    e.mailid)
            sys.exit(10)
        except ccReg.Mailer.InternalError, e:
            sys.stderr.write("Internal error on server: %s\n" %
                    e.message)
            sys.exit(11)
        except Exception, e:
            sys.stderr.write("Corba call failed: %s\n" % e)
            sys.exit(3)
        print "Request for email resend was successfully submitted."
        sys.exit(0)

    if verbose: print "Constructing filter ... ",
    interval = ccRegDateTimeInterval(ccReg, fromdate, todate)
    filter = ccReg.MailFilter(mailid, mailtype, status, handle, attach,
            fulltext, interval)
    if verbose: print "ok"
    #
    # Obtain search object
    try:
        if verbose: print "Obtaining search object ... ",
        search_object = mailer_obj.createSearchObject(filter)
        if verbose: print "done"
    except ccReg.Mailer.InternalError, e:
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
        emails = [1]
        print "Retrieving matched emails"
        print "*" * 50
        while emails:
            emails = search_object.getNext(chunk)
            for mail in emails:
                print "id: %d" % mail.mailid
                print "type: %d" % mail.mailtype
                print "creation date: %s" % mail.crdate
                print "status: %s" % mail.status
                print "status update date: %s" % mail.moddate
                print "associated handles:",
                for handle in mail.handles:
                    print handle,
                print
                print "attachments:",
                for attach in mail.attachments:
                    print attach,
                print
                if quiet:
                    print "content: supressed"
                else:
                    print "content:\n\n%s" % mail.content
                print "*" * 50
        print "End of data transfer"
        search_object.destroy()
    except ccReg.MailSearch.NotActive, e:
        sys.stderr.write("Search object is not active anymore.\n")
        sys.exit(11)
    except ccReg.MailSearch.InternalError, e:
        sys.stderr.write("Internal error on server: %s\n" % e.message)
        sys.exit(12)
    print "Work done successfully"

if __name__ == "__main__":
    run_mailer_admin_client()
