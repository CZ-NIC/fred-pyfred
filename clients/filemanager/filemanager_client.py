#!/usr/bin/env python
# vim:set ts=4 sw=4:

import sys, getopt, os
from omniORB import CORBA
import CosNaming

# update import path
sys.path.insert(0, os.path.split(sys.argv[0])[0]+"/idl")
sys.path.insert(0, "/usr/lib/pyfred/share")
sys.path.insert(0, "idl")
import ccReg

DEV_STDIN = '-'

def usage():
	"""
Print usage information.
	"""
	sys.stderr.write("""filemanager_client [options]

Options:
    -h, --help            Print this help message.
    -i, --input FILE      Send FILE to FileManager.
    -l, --label NAME      Overwrite name of the input file.
    -n, --nameservice HOST[:PORT] Set host where corba nameservice runs.
    -m, --mime MIMETYPE   MIME type of input file (use only with -i).
    -o, --output FILE     Write file retrieved from FileManager to FILE.
    -t, --type NUMBER     File type of input file (use only with -i).
    -x, --id              ID of file.
    -s, --silent          Output to stdout plain data without text

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
	print "  filetype: %d" % info.filetype
	print "  created:  %s" % info.crdate
	print "  size:     %d" % info.size
	print "  repository path: %s" % info.path

def savefile(fm, mimetype, filetype, input, overwrite_label='', silent=0):
	"""
	Save file to filemanager.
	"""
	if input == DEV_STDIN:
		fd = sys.stdin
		label = 'stdin'
	else:
		fd = open(input, "rb")
		label = os.path.basename(input)
	if overwrite_label:
		label = overwrite_label
	#
	# Call filemanager's functions
	try:
		saveobj = fm.save(label, mimetype, filetype)
		# we will upload file in 16K chunks
		chunk = fd.read(2**14)
		while chunk:
			saveobj.upload(chunk)
			chunk = fd.read(2**14)
		fd.close()
		id = saveobj.finalize_upload()
	except ccReg.FileManager.InternalError, e:
		sys.stderr.write("Internal error on server: %s.\n" % e.message)
		sys.exit(10)
	except Exception, e:
		sys.stderr.write("Corba call failed: %s.\n" % e)
		sys.exit(3)
	if silent:
		print id
	else:
		print "File was successfully saved and has id %d." % id

def loadfile(fm, id, output, silent):
	"""
Get file from filemanager.
	"""
	#
	# Call filemanager's functions
	try:
		loadobj = fm.load(id)
		f = open(output, "wb")
		data = loadobj.download(2**14)
		while data:
			f.write(data)
			data = loadobj.download(2**14)
		f.close()
		loadobj.finalize_download()

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
	if silent:
		print output
	else:
		print "File was successfully loaded and saved under name '%s'." % output


def main():
	try:
		opts, args = getopt.getopt(sys.argv[1:],
				"hi:l:n:m:o:t:x:s",
				["help", "input", "label", "nameservice",
				 "mimetype", "output", "type", "id", "silent"])
	except getopt.GetoptError:
		usage()
		sys.exit(1)

	input = ""
	ns = "localhost"
	mimetype = ""
	output = ""
	filetype = 0
	label = ""
	sid = '' # string ID
	silent = 0
	id = None
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
		elif o in ("-m", "--mimetype"):
			mimetype = a
		elif o in ("-o", "--output"):
			output = a
		elif o in ("-t", "--type"):
			filetype = int(a)
		elif o in ("-x", "--id"):
			sid = a # string ID
		elif o in ("-s", "--silent"):
			silent = 1
	# options check
	if input and output:
		sys.stderr.write("--input and --output options cannot be both "
				"specified.\n")
		usage()
		sys.exit(1)
	elif not (input or output or sys.stdin.isatty()):
		input = DEV_STDIN

	if output or not input:
		if not sid:
			sys.stderr.write("ID must be specified.\n")
			usage()
			sys.exit(1)

	if sid:
		try:
			id = int(sid)
		except ValueError, msg:
			sys.stderr.write("ValueError: %s\n"%msg)
			sys.stderr.write("ID must be number in range <1,n>.\n")
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
		savefile(filemanager_obj, mimetype, filetype, input, label, silent)
	else:
		loadfile(filemanager_obj, id, output, silent)


if __name__ == "__main__":
	main()
