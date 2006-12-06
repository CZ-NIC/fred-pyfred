#!/usr/bin/env python

import sys, getopt, os
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
	sys.stderr.write("""filemanager_client [options]

Options:
    -h, --help            Print this help message.
    -i, --input FILE      Send FILE to FileManager.
    -l, --label NAME      Name under which the file is accessible in FileManager.
                          Should be a relative path.
    -n, --nameservice HOST[:PORT] Set host where corba nameservice runs.
    -o, --output FILE     Write data from FileManager to FILE.

""")


def safefile(fm, label, input):
	"""
Save file to filemanager.
	"""
	f = open(input, "rb")
	octets = f.read()
	f.close()
	#
	# Call filemanager's function
	try:
		fm.save(label, octets)
	except ccReg.FileManager.InternalError, e:
		sys.stderr.write("Internal error on server: %s\n" % e.message)
		sys.exit(10)
	except ccReg.FileManager.InvalidName, e:
		sys.stderr.write("Invalid name of file: '%s'\n" % e.filename)
		sys.exit(11)
	except Exception, e:
		sys.stderr.write("Corba call failed: %s\n" % e)
		sys.exit(3)
	print "File was successfully saved under name '%s'." % label


def loadfile(fm, label, output):
	"""
Get file from filemanager.
	"""
	#
	# Call filemanager's function
	try:
		octets, mimetype = fm.load(label)
	except ccReg.FileManager.InternalError, e:
		sys.stderr.write("Internal error on server: %s\n" % e.message)
		sys.exit(10)
	except ccReg.FileManager.InvalidName, e:
		sys.stderr.write("Invalid name of file: '%s'\n" % e.filename)
		sys.exit(11)
	except Exception, e:
		sys.stderr.write("Corba call failed: %s\n" % e)
		sys.exit(3)
	f = open(output, "wb")
	f.write(octets)
	f.close()
	print "File was successfully loaded and saved under name '%s'." % output
	print "MIME type is '%s'" % mimetype


def main():
	try:
		opts, args = getopt.getopt(sys.argv[1:],
				"hi:l:n:o:",
				["help", "input", "label", "nameservice",
					"output"])
	except getopt.GetoptError:
		usage()
		sys.exit(1)

	input = ""
	label = ""
	ns = "localhost"
	output = ""
	for o, a in opts:
		if o in ("-h", "--help"):
			usage()
			sys.exit()
		elif o in ("-i", "--input"):
			input = a
		elif o in ("-l", "--label"):
			label = a
		elif o in ("-n", "--nameservice"):
			ns = a
		elif o in ("-o", "--output"):
			output = a
	# options check
	if (not input and not output) or (input and output):
		sys.stderr.write("One of options --input, --output "
				"must be specified.\n")
		usage()
		sys.exit(1)
	if not label:
		sys.stderr.write("Option --label must be specified.\n")
		usage()
		sys.exit(1)

	#
	# Initialise the ORB
	orb = CORBA.ORB_init(["-ORBInitRef", "NameService=corbaname::" + ns],
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
	filemanager_obj = obj._narrow(ccReg.FileManager)
	if (filemanager_obj is None):
		sys.stderr.write("Object reference is not a ccReg::FileManager\n")
		sys.exit(2)

	if input:
		safefile(filemanager_obj, label, input)
	else:
		loadfile(filemanager_obj, label, output)


if __name__ == "__main__":
	main()
