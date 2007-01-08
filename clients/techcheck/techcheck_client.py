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
    -a, --all                     Do test of all domains generated in zone.
    -d, --domain NAME             Domain on which should be performed tech test.
    -h, --help                    Print this help message.
    -n, --nameservice HOST[:PORT] Set host where corba nameservice runs.

    Option --all is ment to be used for regular technical checks of all domains
    in register. It has priority over --domain option.
""")

def main():
	try:
		opts, args = getopt.getopt(sys.argv[1:],
			"ad:hn:", ["all", "domain", "help", "nameservice"])
	except getopt.GetoptError:
		usage()
		sys.exit(1)

	all = False
	domain = ""
	ns = "localhost"
	for o, a in opts:
		if o in ("-a", "--all"):
			all = True
		if o in ("-d", "--domain"):
			domain = a
		elif o in ("-h", "--help"):
			usage()
			sys.exit()
		elif o in ("-n", "--nameservice"):
			ns = a
	# Check consistency of used options
	if not domain and not all:
		sys.stderr.write("One of --domain and --all is mandatory.\n")
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
	tc_obj = obj._narrow(ccReg.TechCheck)
	if (tc_obj is None):
		sys.stderr.write("Object reference is not a ccReg::TechCheck\n")
		sys.exit(2)

	#
	# Call techcheck's function
	try:
		if all:
			tc_obj.checkAll()
			return # there nothing to be printed
		else:
			result = tc_obj.checkDomain(domain, ccReg.CHKR_MANUAL)
	except ccReg.TechCheck.InternalError, e:
		sys.stderr.write("Internal error on server: %s\n" % e.message)
		sys.exit(10)
	except ccReg.TechCheck.DomainNotFound, e:
		sys.stderr.write("Domain does not exist.\n")
		sys.exit(11)
	except ccReg.TechCheck.NoAssociatedNsset, e:
		sys.stderr.write("Domain has not associated nsset.\n")
		sys.exit(12)
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
	for test in result.results:
		if test.result: status = "Passed"
		else: status = "Failed"
		print "Test's name:     %s" % test.name
		print "    Level:       %d" % test.level
		print "    Status:      %s" % status
		print "    Note:        %s" % test.note
	print
	print "--- End of Status report -----------------------------"

if __name__ == "__main__":
	main()
