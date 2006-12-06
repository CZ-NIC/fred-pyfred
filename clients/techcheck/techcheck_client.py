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
	sys.stderr.write("""techcheck_client [options]

Options:
    -d, --domain NAME             Domain on which should be performed tech test.
    -h, --help                    Print this help message.
    -n, --nameservice HOST[:PORT] Set host where corba nameservice runs.

""")

def main():
	try:
		opts, args = getopt.getopt(sys.argv[1:],
				"d:hn:", ["domain", "help", "nameservice"])
	except getopt.GetoptError:
		usage()
		sys.exit(1)

	domain = ""
	ns = "localhost"
	for o, a in opts:
		if o in ("-d", "--domain"):
			domain = a
		elif o in ("-h", "--help"):
			usage()
			sys.exit()
		elif o in ("-n", "--nameservice"):
			ns = a
	# --domain is mandatory argument
	if not domain:
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
	# Resolve the name "fred.context/TechCheck.Object"
	name = [CosNaming.NameComponent("fred", "context"),
			CosNaming.NameComponent("TechCheck", "Object")]
	try:
		obj = rootContext.resolve(name)
	except CosNaming.NamingContext.NotFound, e:
		sys.stderr.write("Could not get object's reference. Is object "
				"registered? (%s)\n" % e)
		sys.exit(2)
	# Narrow the object to an ccReg::TechCheck
	techcheck_obj = obj._narrow(ccReg.TechCheck)
	if (techcheck_obj is None):
		sys.stderr.write("Object reference is not a ccReg::TechCheck\n")
		sys.exit(2)

	#
	# Call techcheck's function
	try:
		result = techcheck_obj.checkDomain(domain, ccReg.CHKR_MANUAL)
	except ccReg.TechCheck.InternalError, e:
		sys.stderr.write("Internal error on server: %s\n" % e.message)
		sys.exit(10)
	except ccReg.TechCheck.NoAssociatedNsset, e:
		sys.stderr.write("Domain has not associated nsset or does not "
				"exist\n")
		sys.exit(11)
	except Exception, e:
		sys.stderr.write("Corba call failed: %s\n" % e)
		sys.exit(3)
	# Print result of tech check
	if result.status: status = "Passed"
	else: status = "Failed"
	print "--- Status report ------------------------------------"
	print
	print "ID of the test: %d" % result.id
	print "Overall status: %s" % status
	print "Results of individual tests:"
	for check in result.results:
		if check.result: status = "Passed"
		else: status = "Failed"
		if check.level == ccReg.CHECK_ERROR:
			level = "ERROR"
		elif check.level == ccReg.CHECK_WARNING:
			level = "WARNING"
		elif check.level == ccReg.CHECK_INFO:
			level = "INFO"
		else:
			level = "unknown"
		print "Test's name:     %s" % check.name
		print "    Level:       %s" % level
		print "    Status:      %s" % status
		print "    Note:        %s" % check.note
	print
	print "--- End of Status report -----------------------------"

if __name__ == "__main__":
	main()
