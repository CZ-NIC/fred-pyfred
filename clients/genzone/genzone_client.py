#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Script for generating zone file for given zone name.

The script connects through CORBA interface to the server which acts directly
on database. All data needed for zone generation are retrieved from server. The
only thing the client has to supply is a correct name of a zone. The zone name
is searched in database by server and if the zone is there the zone data are
returned.  From zone data is generated a zone file in given format. Currently
only one format (bind) is supported, which is the default format.
"""

import sys, getopt
from omniORB import CORBA
import CosNaming

# update import path
sys.path.insert(0, "idl")
sys.path.insert(0, "/usr/lib/pyfred/share")
import ccReg

class ZoneException(Exception):
	"""
ZoneException is used for all exceptions thrown by Zone object. To find
out what actualy happened stringify exception.
	"""
	def __init__(self, msg = ""):
		Exception.__init__(self, msg)

class Zone(object):
	"""
Object Zone is responsible for downloading zone data from server and
formating obtained data when dump() method is called.
	"""
	BIND = 0 # currently the only supported output format (constant)

	def __init__(self, zonename, ns = "", chunk = 1, verbose = False):
		"""
	Initializer sets verbose mode, location of corba nameservice, number of
	domains transfered in one turn, obtains corba object's reference, calls
	method transferRequest() on object ZoneGenerator and saves the result of
	call in member variables for later use by dump() funtion.
		"""
		self.zonename = zonename
		self.verbose = verbose
		self.chunk = chunk

		try:
			# Initialise the ORB
			orb = CORBA.ORB_init(["-ORBInitRef", "NameService=corbaname::" + ns],
					CORBA.ORB_ID)
			# Obtain a reference to the root naming context
			obj = orb.resolve_initial_references("NameService")
			rootContext = obj._narrow(CosNaming.NamingContext)
			if rootContext is None:
				raise ZoneException("Failed to narrow the root naming context")
			# Resolve the name "fred.context/ZoneGenerator.Object"
			name = [CosNaming.NameComponent("fred", "context"),
					CosNaming.NameComponent("ZoneGenerator", "Object")]
			obj = rootContext.resolve(name)
			# Narrow the object to an fred::ZoneGenerator
			self.zo = obj._narrow(ccReg.ZoneGenerator)
			if (self.zo is None):
				raise ZoneException("Object reference is not an ccReg::ZoneGenerator")
			(self.session, self.ttl, self.hostmaster, self.serial,
					self.refresh, self.update_retr, self.expiry,
					self.minimum, self.ns_fqdn, self.nameservers
					) = self.zo.transferRequest(self.zonename)
		except ccReg.ZoneGenerator.ZoneGeneratorError, e:
			raise ZoneException("Error message from server: %s" % e)
		except CosNaming.NamingContext.NotFound, ex:
			raise ZoneException("CORBA object named '%s' not found "
					"(check that the server is running)" % name)
		except CORBA.TRANSIENT, e:
			raise ZoneException("Is nameservice running? (%s)" % e)
		except CORBA.Exception, e:
			raise ZoneException("CORBA failure, original exception is: %s" % e)

	def dump(self, output, format, closeit = True):
		"""
	Dump zone content in given format in a file.
		"""
		#
		# Generate the output (in BIND format)
		#
		if format != self.BIND:
			raise ZoneException("Selected output format not supported")
		# For now make up a list where each item represents one line
		output.write("$TTL %d ;default TTL for all records in the zone\n"
				% self.ttl)
		# SOA record (spans multiple lines)
		output.write( "%s.\t\tIN\tSOA\t%s.\t%s. (" % (self.zonename,
			self.ns_fqdn, self.hostmaster.replace("@",".")) )
		output.write("%s " % self.serial)
		output.write("%d " % self.refresh)
		output.write("%d " % self.update_retr)
		output.write("%d " % self.expiry)
		output.write("%d)\n" % self.minimum)
		# list of nameservers for the zone
		for ns in self.nameservers:
			output.write("\t\tIN\tNS\t%s.\n" % ns.fqdn)
		# addresses of nameservers (only if there are any)
		for ns in self.nameservers:
			for addr in ns.inet:
				output.write("%s.\tIN\tA\t%s\n" % (ns.fqdn, addr))
		# domains, their nameservers and addresses
		output.write(";\n")
		output.write(";--- domain records ---\n")
		output.write(";\n")
		domains = True
		while domains:
			# Invoke the getZoneData operation
			try:
				domains = self.zo.getZoneData(self.session, self.chunk)
				if self.verbose: sys.stderr.write(".")
			except ccReg.ZoneGenerator.ZoneGeneratorError, e:
				raise ZoneException("Error message from server: %s" % e)
			except CORBA.TRANSIENT, e:
				raise ZoneException("Is corba server running? (%s)" % e)
			except CORBA.Exception, e:
				raise ZoneException("CORBA failure, original exception is: %s" % e)
			for domain in domains:
				for ns in domain.nameservers:
					output.write("%s.\tIN\tNS\t%s" % (domain.name, ns.fqdn))
					# if the nameserver's fqdn is already terminated by a dot
					# we don't add another one - ugly check which is necessary
					# becauseof error in CR (may be removed in future)
					if not ns.fqdn.endswith("."): output.write(".\n")
					else: output.write("\n")
					for addr in ns.inet:
						output.write("%s.\tIN\tA\t%s\n" % (domain.name, addr))
		if closeit: output.close()
		if self.verbose: sys.stderr.write(" done\n")

	def cleanup(self):
		"""
	Clean up resources allocated for transfer on server's side.
		"""
		try:
			self.zo.transferDelete(self.session)
		except ccReg.ZoneGenerator.ZoneGeneratorError, e:
			raise ZoneException("Error message from server: %s" % e)
		except CORBA.TRANSIENT, e:
			raise ZoneException("Is corba server running? (%s)" % e)
		except CORBA.Exception, e:
			raise ZoneException("CORBA failure, original exception is: %s" % e)


def usage():
	"""
Print usage information.
	"""
	sys.stdout.write(
"""%s [options] zone

Script for generating zone file for given zone name. For more information
see the script's pydoc documentation.

options:
	--chunk (-c)          Number of domains transfered in one CORBA call.
	--format (-f) bind    Output format - currently supported only format of
	                      bind. The default format is bind.
	--help (-h)           Print this information.
	--ns (-n) host:port   Corba nameservice location. Default is localhost.
	--output (-o) file    Generate output to file instead of standard output.
	--verbose (-v)        Print progress graf to stderr.
	--test (-t)           Test a server-side of zone generator. Tester sends a
                          request for zone transfer and then closes the
                          transfer without transfering any data (only SOA
                          record is transferred as result of openning
                          transaction).
""" % sys.argv[0])

#
# Main program just calls zonestr() function which returns the generated
# zone as a string
#
if __name__ == "__main__":
	# parse command line parameters
	try:
		opts, args = getopt.getopt(sys.argv[1:], "c:f:hn:o:vt",
				["chunk=", "format=", "help", "ns=", "output=", "verbose",
				"test"])
	except getopt.GetoptError:
		usage()
		sys.exit(2)
	# set default values
	format = Zone.BIND
	output = sys.stdout
	verbose = False
	test = False
	ns = "localhost"
	chunk = 1
	zonename = sys.argv[-1]
	# get parameters
	for o,a in opts:
		if o in ("-c", "--chunk"):
			try:
				chunk = int(a)
			except Exception, e:
				sys.stderr.write("Chunk size must be a number.\n")
				sys.exit(3)
		elif o in ("-f", "--format"):
			if a == "bind":
				format = Zone.BIND
			else:
				sys.stderr.write("Unknown output format\n")
				usage()
				sys.exit(2)
		elif o in ("-h", "--help"):
			usage()
			sys.exit()
		elif o in ("-n", "--ns"):
			ns = a
		elif o in ("-o", "--output"):
			try:
				output = open(a, 'w')
			except Exception, e:
				sys.stderr.write("Cannot open output file '%s' for writing.\n")
				sys.exit(3)
		elif o in ("-v", "--verbose"):
			verbose = True
		elif o in ("-t", "--test"):
			test = True

	try:
		# initialize zone generator
		zoneObj = Zone(zonename, ns, chunk, verbose)
	except ZoneException, e:
		if test:
			print "GENZONE CRITICAL - initialization of transfer failed: %s" % e
		else:
			sys.stderr.write("Zone Generator initialization failed (%s)\n" % e)
		sys.exit(1)
	ret = 0
	# run the transfer of data only if not in test mode
	if not test:
		try:
			# this will do the rest of the work
			zoneObj.dump(output, format, True)
		except ZoneException, e:
			sys.stderr.write("Transfer of zone data (%s)\n" % e)
			ret = 1
	try:
		# cleanup
		zoneObj.cleanup()
	except ZoneException, e:
		if test:
			print "GENZONE FAILED - finalization of transfer failed: %s" % e
		else:
			sys.stderr.write("Cleanup of transfer failed (%s)\n" % e)
		sys.exit(1)
	if test:
		print "GENZONE OK - transfer id = %d" % zoneObj.session
	sys.exit(ret)
