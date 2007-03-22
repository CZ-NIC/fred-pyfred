#!/usr/bin/env python
# vim: set ts=4 sw=4:

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
	sys.stderr.write("""techcheck_client [options] NSSET

    NSSET is handle of nsset which should be tested and must be given.

Options:
    -d, --dig                     Dig all domain fqdns which use nsset and
                                  test them too.
    -f, --fqdn NAME               FQDN of domain which should be tested with
                                  nsset. May be specified multipletimes.
    -h, --help                    Print this help message.
    -l, --level NUMBER            Explicit specification of test level (1-10).
    -n, --nameservice HOST[:PORT] Set host where corba nameservice runs.
    -r, --regid                   Set handle of registrator whom should be
                                  queued the message with results. This means
                                  that the test will be run asynchronously.
    -s, --save                    Save the result of tech check in database.
""")

def convStatus(status):
	if status == 0:
		return "Passed"
	elif status == 1:
		return "Failed"
	return "Unknown"

def main():
	try:
		opts, args = getopt.getopt(sys.argv[1:],
				"df:hl:n:r:s", ["dig", "fqdn", "help", "level",
					"nameservice", "regid", "save"]
				)
	except getopt.GetoptError:
		usage()
		sys.exit(1)

	dig = False
	fqdn = []
	level = 0
	ns = "localhost"
	regid = False
	save = False
	for o, a in opts:
		if o in ("-d", "--dig"):
			dig = True
		elif o in ("-f", "--fqdn"):
			fqdn.append(a)
		elif o in ("-h", "--help"):
			usage()
			sys.exit()
		elif o in ("-l", "--level"):
			level = int(a)
		elif o in ("-n", "--nameservice"):
			ns = a
		elif o in ("-r", "--regid"):
			regid = a
		elif o in ("-s", "--save"):
			save = True
	# last argument must be nsset
	if len(sys.argv) < 2:
		usage()
		sys.exit(2)
	nsset = sys.argv[-1]
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
		sys.exit(1)
	# Resolve the name "fred.context/TechCheck.Object"
	name = [CosNaming.NameComponent("fred", "context"),
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

	#
	# Call techcheck's function
	try:
		if regid:
			tc_obj.checkNssetAsynch(regid, nsset, level, dig, save,
					ccReg.CHKR_MANUAL, fqdn)
			print "Asynchronous technical check was successfuly submitted."
			return # there is nothing to be printed
		# synchronous technical test
		testlist = tc_obj.checkGetTests()
		results, checkid, status = tc_obj.checkNsset(nsset, level, dig, save,
					ccReg.CHKR_MANUAL, fqdn)
	except ccReg.TechCheck.InternalError, e:
		sys.stderr.write("Internal error on server: %s\n" % e.message)
		sys.exit(10)
	except ccReg.TechCheck.NssetNotFound, e:
		sys.stderr.write("Nsset does not exist.\n")
		sys.exit(11)
	except Exception, e:
		sys.stderr.write("Corba call failed: %s\n" % e)
		sys.exit(3)
	# Print result of synchronous tech check
	tests = {}
	for item in testlist:
		tests[item.id] = item
	print "--- Status report ------------------------------------"
	print
	print "Check id: %d" % checkid
	print "Overall status: %s" % convStatus(status)
	print "Results of individual tests:"
	for result in results:
		print "Test's name:        %s" % tests[result.testid].name
		print "    Test ID:        %d" % result.testid
		print "    Level:          %d" % tests[result.testid].level
		print "    Domain-centric: %s" % tests[result.testid].domain_centric
		print "    Status:         %s" % convStatus(result.status)
		print "    Note:           %s" % result.note
		print "    Data:           %s" % result.data
	print
	print "--- End of Status report -----------------------------"

if __name__ == "__main__":
	main()
