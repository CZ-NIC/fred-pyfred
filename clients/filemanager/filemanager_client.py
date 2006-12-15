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
    -n, --nameservice HOST[:PORT] Set host where corba nameservice runs.
    -o, --output FILE     Write file retrieved from FileManager to FILE.
    -t, --type MIMETYPE   MIME type of input file (use only with -i).
    -x, --id              ID of file.

Input and output parameter decides wether a file will be saved or loaded.
If none of them is specified then meta-info about file is retrieved.
""")


def getinfo(fm, id):
	"""
Get meta information about file.
	"""
	#
	# Call filemanager's function
	try:
		info = fm.info(id)
	except ccReg.FileManager.InternalError, e:
		sys.stderr.write("Internal error on server: %s\n" % e.message)
		sys.exit(10)
	except ccReg.FileManager.IdNotFound, e:
		sys.stderr.write("Id %d is not in database.\n" % id)
		sys.exit(13)
	except Exception, e:
		sys.stderr.write("Corba call failed: %s\n" % e)
		sys.exit(3)
	print "Meta information about file with id %d:" % id
	print "  id:       %d" % info.id
	print "  label:    %s" % info.name
	print "  mimetype: %s" % info.mimetype
	print "  created:  %s" % info.crdate
	print "  size:     %d" % info.size
	print "  repository path: %s" % info.path

def safefile(fm, type, input):
	"""
Save file to filemanager.
	"""
	f = open(input, "rb")
	octets = f.read()
	f.close()
	label = os.path.basename(input)
	#
	# Call filemanager's function
	try:
		id = fm.save(label, type, octets)
	except ccReg.FileManager.InternalError, e:
		sys.stderr.write("Internal error on server: %s.\n" % e.message)
		sys.exit(10)
	except Exception, e:
		sys.stderr.write("Corba call failed: %s.\n" % e)
		sys.exit(3)
	print "File was successfully saved and has id %d." % id

def loadfile(fm, id, output):
	"""
Get file from filemanager.
	"""
	#
	# Call filemanager's function
	try:
		octets = fm.load(id)
	except ccReg.FileManager.InternalError, e:
		sys.stderr.write("Internal error on server: %s\n" % e.message)
		sys.exit(10)
	except ccReg.FileManager.IdNotFound, e:
		sys.stderr.write("Id '%d' is not in database.\n" % id)
		sys.exit(13)
	except ccReg.FileManager.FileNotFound, e:
		sys.stderr.write("File described by id %d is missing.\n" % id)
		sys.exit(14)
	except Exception, e:
		sys.stderr.write("Corba call failed: %s\n" % e)
		sys.exit(3)
	f = open(output, "wb")
	f.write(octets)
	f.close()
	print "File was successfully loaded and saved under name '%s'." % output


def main():
	try:
		opts, args = getopt.getopt(sys.argv[1:],
				"hi:n:o:t:x:",
				["help", "input", "nameservice", "output",
					"type", "id"])
	except getopt.GetoptError:
		usage()
		sys.exit(1)

	input = ""
	ns = "localhost"
	output = ""
	type = ""
	id = None
	for o, a in opts:
		if o in ("-h", "--help"):
			usage()
			sys.exit()
		elif o in ("-i", "--input"):
			input = a
		elif o in ("-n", "--nameservice"):
			ns = a
		elif o in ("-o", "--output"):
			output = a
		elif o in ("-t", "--type"):
			type = a
		elif o in ("-x", "--id"):
			id = int(a)
	# options check
	if input and output:
		sys.stderr.write("--input and --output options cannot be both "
				"specified.\n")
		usage()
		sys.exit(1)
	elif not input:
		if not id:
			sys.stderr.write("ID must be specified.\n")
			usage()
			sys.exit(1)

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
	filemanager_obj = obj._narrow(ccReg.FileManager)
	if (filemanager_obj is None):
		sys.stderr.write("Object reference is not a ccReg::FileManager\n")
		sys.exit(2)

	if not input and not output:
		getinfo(filemanager_obj, id)
	elif input:
		safefile(filemanager_obj, type, input)
	else:
		loadfile(filemanager_obj, id, output)


if __name__ == "__main__":
	main()
