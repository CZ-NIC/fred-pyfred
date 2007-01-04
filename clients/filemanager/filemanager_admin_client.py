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
	sys.stderr.write("""filemanager_admin_client [options]

Script is a testing utility for admin interface of filemanager daemon.
You can constraint search by various criteria given on command line.

Options:
    -c, --chunk NUMBER            Obtain files in chunks of given size.
    -h, --help                    Print this help message.
    -i, --id NUMBER               Get file with given ID.
    -l, --label NAME              Get files with given label (name).
    -n, --nameservice HOST[:PORT] Set host where corba nameservice runs.
    -m, --mime TYPE               Get file with given MIME type.
    -o, --lowerdate DATETIME      Lower bound on creation date of file.
    -p, --path PATH               Get file stored under given path.
    -u, --upperdate DATETIME      Upper bound on creation date of file.
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
				"c:hi:l:n:m:o:p:u:v",
				["chunk", "help", "id", "label", "nameservice",
				"mime", "lowerdate", "path", "upperdate",
				"verbose"]
				)
	except getopt.GetoptError:
		usage()
		sys.exit(1)

	chunk  = 1
	id = -1
	label = ""
	ns = "localhost"
	mime = ""
	path = ""
	verbose = False
	l_crdate = ""
	u_crdate = ""
	for o, a in opts:
		if o in ("-c", "--chunk"):
			chunk = int(a)
		elif o in ("-h", "--help"):
			usage()
			sys.exit()
		elif o in ("-i", "--id"):
			id = int(a)
		elif o in ("-l", "--label"):
			label = a
		elif o in ("-n", "--nameservice"):
			ns = a
		elif o in ("-m", "--mime"):
			mime = a
		elif o in ("-o", "--lowerdate"):
			l_crdate = a
		elif o in ("-p", "--path"):
			path = a
		elif o in ("-v", "--verbose"):
			verbose = True
		elif o in ("-u", "--upperdate"):
			u_crdate = a
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
	# Resolve the name "fred.context/FileManager.Object"
	name = [CosNaming.NameComponent("fred", "context"),
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

	if verbose: print "Constructing filter ... ",
	interval = ccReg.DateTimeInterval(fromdate, todate)
	filter = ccReg.FileFilter(id, label, path, mime, interval)
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
	main()