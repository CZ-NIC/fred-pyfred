#!/usr/bin/env python

import sys, getopt
from omniORB import CORBA
import CosNaming

# update import path
sys.path.insert(0, "idl")
sys.path.insert(0, "/usr/lib/pyfred/share")
import ccReg

def usage():
	"""
Print usage information.
	"""
	sys.stderr.write("""mailer_admin_client [options]

Script is a testing utility for admin interface of mailer daemon.
You can constraint search in mail archive by various criteria given on
command line.

Options:
    -a, --attachment NAME         Get messages with given attachment.
    -c, --chunk NUMBER            Obtain messages in chunks of given size.
    -f, --fulltext STRING         Get messages containing given string.
    -h, --help                    Print this help message.
    -i, --id NUMBER               Get messages with given ID.
    -l, --handle NAME             Get messages with given associated handle.
    -m, --mailtypes               Get mapping between id and name of mail types.
    -n, --nameservice HOST[:PORT] Set host where corba nameservice runs.
    -o, --lowerdate DATETIME      Lower bound on creation date of email.
    -q, --quiet                   Do not display mail bodies.
    -s, --status NUMBER           Get messages with given status.
    -t, --type NUMBER             Id of mail type.
    -u, --upperdate DATETIME      Upper bound on creation date of email.
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

def main():
	try:
		opts, args = getopt.getopt(sys.argv[1:],
				"a:c:f:hi:l:mn:o:qs:t:u:v",
				["attachment", "chunk", "fulltext", "help", "id",
				"handle", "mailtypes", "nameservice",
				"lowerdate", "quiet", "status", "type",
				"upperdate", "verbose"]
				)
	except getopt.GetoptError:
		usage()
		sys.exit(1)

	attach = -1
	chunk  = 1
	fulltext = ""
	mailid = -1
	handle = ""
	listmailtypes = False
	ns = "localhost"
	quiet = False
	status = -1
	mailtype = -1
	verbose = False
	l_crdate = ""
	u_crdate = ""
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
		elif o in ("-m", "--mailtypes"):
			listmailtypes = True
		elif o in ("-n", "--nameservice"):
			ns = a
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
	#
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
			"-ORBInitRef", "NameService=corbaname::" + ns],
			CORBA.ORB_ID)
	# Obtain a reference to the root naming context
	obj = orb.resolve_initial_references("NameService")
	rootContext = obj._narrow(CosNaming.NamingContext)
	if rootContext is None:
		sys.stderr.write("Failed to narrow the root naming context\n")
		sys.exit(2)
	# Resolve the name "fred.context/Mailer.Object"
	name = [CosNaming.NameComponent("fred", "context"),
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

	if listmailtypes:
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

	if verbose: print "Constructing filter ... ",
	interval = ccReg.DateTimeInterval(fromdate, todate)
	filter = ccReg.MailFilter(mailid, mailtype, status, handle, attach,
			interval, fulltext)
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
	main()
