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
    sys.stderr.write("""mailer_client [options]

Options:
    -f, --file=FILENAME           Configuration file name.
    -a, --attachment=NAME         Identificator of attachment.
    -d, --data=FILE               Read data used in template from file.
    -e, --header=FILE             Read header values from file.
    -h, --help                    Print this help message.
    -n, --nameservice=HOST[:PORT] Set host where CORBA nameservice runs.
    -c, --context=CONTEXT         Set CORBA nameservice context name.
    -s, --sendmail                Really send mail and not just generate preview.
    -t, --type=NAME               Type of email to be send or rendered.

    If you don't specify -d switch, the program will read data from standard
    input. The same holds for -e switch.

""")

def createPairs(keyvalues):
    """
Create sequence of key-value pairs acceptable for corba.
    """
    return [ ccReg.KeyValue(key, value) for key, value in keyvalues ]

def run_mailer_client():
    try:
        opts, args = getopt.getopt(sys.argv[1:],
                "a:d:e:hn:st:f:c:",
                ["attachment=", "data=", "header=", "help", "nameservice=",
                    "sendmail", "type=", "file=", "context="]
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

    dfile = ""
    hfile = ""
    nameservice = "localhost"
    context = "fred"
    mailtype = ""
    attachs = []
    sendmail = False

    if conf.has_option('General', 'nshost'):
        nameservice = conf.get('General', 'nshost')
    if conf.has_option('General', 'nsport'):
        nameservice = nameservice + ":" + conf.get('General', 'nsport')
    if conf.has_option('General', 'nscontext'):
        context = conf.get('General', 'nscontext')

    for o, a in opts:
        if o in ("-a", "--attachment"):
            attachs.append(int(a))
        elif o in ("-d", "--data"):
            dfile = a
        elif o in ("-e", "--header"):
            hfile = a
        elif o in ("-f", "--file"):
            tfile.append(a)
        elif o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-n", "--nameservice"):
            nameservice = a
        elif o in ("-s", "--sendmail"):
            sendmail = True
        elif o in ("-t", "--type"):
            mailtype = a
        elif o in ('-c', '--context'):
            context = a

    if not mailtype:
        sys.stderr.write("Email type must be specified.\n")
        usage()
        sys.exit(1)
    # Read data
    pairs = []
    if dfile:
        f = open(dfile, "r")
    else:
        f = sys.stdin
        print "Interactive setting of data set."
        print "(Type Ctrl-D when done)"
    line = f.readline()
    while line:
        delim = line.find(" ")
        if delim >= 0:
            pairs.append((line[:delim], line[delim:].strip("\n\t ")))
        line = f.readline()
    if dfile:
        f.close()
    # Read header
    header = ccReg.MailHeader("", "", "", "", "", "", "")
    if hfile:
        f = open(hfile, "r")
    else:
        f = sys.stdin
        print "Interactive setting of header."
        print "(Type Ctrl-D when done)"
    line = f.readline()
    while line:
        parsed_line = line.split(":")
        if len(parsed_line) == 2:
            hname = parsed_line[0].upper()
            hvalue = parsed_line[1].strip()
            if hname == "TO":
                header.h_to = hvalue
            elif hname == "FROM":
                header.h_from = hvalue
            elif hname == "CC":
                header.h_cc = hvalue
            elif hname == "BCC":
                header.h_bcc = hvalue
            elif hname == "REPLY-TO":
                header.h_reply_to = hvalue
            elif hname == "ERRORS-TO":
                header.h_errors_to = hvalue
            elif hname == "ORGANIZATION":
                header.h_organization = hvalue
        line = f.readline()
    if hfile:
        f.close()

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

    # Prepare data for mailer's function
    corba_pairs = [ ccReg.KeyValue(key, value) for key, value in pairs ]
    #
    # Call mailer's function
    try:
        mailid, result = mailer_obj.mailNotify(mailtype, header,
                corba_pairs, [], attachs, not sendmail)
        if not sendmail:
            # Print rendered result
            print "Rendered result:"
            print result
        print "Mail ID: %d" % mailid
    except ccReg.Mailer.UnknownMailType, e:
        sys.stderr.write("Unknown mail type '%s'.\n" % e.typename)
        sys.exit(10)
    except ccReg.Mailer.InvalidHeader, e:
        sys.stderr.write("Invalid value of header '%s'.\n" % e.header)
        sys.exit(11)
    except ccReg.Mailer.InternalError, e:
        sys.stderr.write("Internal error on server: %s\n" % e.message)
        sys.exit(12)
    except ccReg.Mailer.SendMailError, e:
        sys.stderr.write("Error when sending the email.\n")
        sys.exit(13)
    except Exception, e:
        sys.stderr.write("Corba call failed: %s\n" % e)
        sys.exit(3)

if __name__ == "__main__":
    run_mailer_client()
