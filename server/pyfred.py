#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
This module is a framework in which can be easily embedded various corba
object implementations through extending modules defined in modules.conf.
Those objects are registered in corba name service and the rest is up to
a caller (corba client).
"""

import sys, time, syslog, ConfigParser
from omniORB import CORBA, PortableServer
import CosNaming
import pgdb

def job_noop():
	"""
This function is used as placeholder in job queue if the queue is empty.
	"""
	pass

class Logger(object):
	"""
This class encapsulates standard syslog function. The only difference is
that each message when called through Logger is prepended by name of module,
which is set during Logger's initialization.
	"""
	EMERG = syslog.LOG_EMERG
	ALERT = syslog.LOG_ALERT
	CRIT = syslog.LOG_CRIT
	ERR = syslog.LOG_ERR
	WARNING = syslog.LOG_WARNING
	NOTICE = syslog.LOG_NOTICE
	INFO = syslog.LOG_INFO
	DEBUG = syslog.LOG_DEBUG

	def __init__(self, prefix):
		"""
	Initialize the prefix which will be used for every message logged
	trhough this Logger.
		"""
		self.prefix = prefix

	def log(self, level, msg):
		"""
	Wrapper around syslog.syslog() function which adds prefix to every
	logged message.
		"""
		syslog.syslog(level, "%s module - %s" % (self.prefix, msg))

class DB(object):
	"""
This class provides methods usefull when working with database.
	"""

	def __init__(self, dbhost, dbport, dbname, dbuser, dbpassword):
		"""
	Method initializes data needed for database access.
		"""
		self.host = dbhost
		self.port = dbport
		self.dbname = dbname
		self.user = dbuser
		self.password = dbpassword

	def getConn(self):
		"""
	Obtain connection to database.
		"""
		return pgdb.connect(host = self.host +":"+ self.port,
				database = self.dbname, user = self.user,
				password = self.password)

	def releaseConn(self, conn):
		"""
	Release connection obtained in getConn() method.
		"""
		conn.close()

def getConfiguration(configs):
	"""
Get configuration from file. The configuration files are given as a list in
parameter. The function automatically provides default values for directives
not defined by configuration file. If none of the configuration files exists,
all directives will contain default values.
	"""
	# set defaults
	confparser = ConfigParser.SafeConfigParser({
			"dbhost":"",
			"dbname":"ccreg",
			"dbport":"5432",
			"dbuser":"postgres",
			"dbpassword":"",
			"nshost":"localhost",
			"nsport":"2809",
			"loglevel":"LOG_INFO",
			"logfacility":"LOG_LOCAL1",
			"port":"2225"})
	# read configuration file
	for cfile in configs:
		try:
			if len(confparser.read(cfile)) == 1:
				print "File %s used as config file" % cfile
				break
		except ConfigParser.MissingSectionHeaderError, e:
			sys.stderr.write("Error in configuration file '%s': %s\n" %
					(cfile, e))
			return None
		except ConfigParser.ParsingError, e:
			sys.stderr.write("Error in configuration file '%s': %s\n" %
					(cfile, e))
			return None
	# create basic section general if it does not exist
	if not confparser.has_section("General"):
		confparser.add_section("General")
	return confparser

#
# main
#
def main(argv):
	# if server should detach from terminal after startup
	detach = 1
	# default places where to look for configs
	configs = ["/etc/pyfred.conf", "/usr/local/etc/pyfred.conf",
	           "pyfred.conf"]
	for arg in argv[1:]:
		if arg == "-d":
			detach = 0
		else:
			# append explicit config location if present on command line
			configs.insert(0, arg)
	# get configuration
	conf = getConfiguration(configs)
	if not conf:
		sys.exit(1)

	# open syslog (syslog function will be later passed to modules)
	try:
		logfacility = syslog.__dict__[ conf.get("General", "logfacility").upper() ]
	except KeyError, e:
		sys.stderr.write("syslog facility is invalid: %s\n" %
				conf.get("General", "logfacility"))
		sys.exit(1)
	syslog.openlog("pyfred", (syslog.LOG_PID | syslog.LOG_CONS), logfacility)
	try:
		loglevel = syslog.__dict__[ conf.get("General", "loglevel").upper() ]
	except KeyError, e:
		sys.stderr.write("log level is invalid: %s\n" %
				conf.get("General", "loglevel"))
		sys.exit(1)
	syslog.setlogmask(syslog.LOG_UPTO(loglevel))

	# create database object to be used in modules
	db = DB(conf.get("General", "dbhost"),
			conf.get("General", "dbport"),
			conf.get("General", "dbname"),
			conf.get("General", "dbuser"),
			conf.get("General", "dbpassword"))
	# get a list of modules to import
	modulenames = conf.get("General", "modules").split(" ")
	# update import path
	sys.path.insert(0, "idl")
	sys.path.insert(0, "/usr/lib/pyfred/share")
	sys.path.insert(0, "/usr/lib/pyfred/server")
	# load all modules
	modules = []
	for mname in modulenames:
		try:
			print "Importing module %s" % mname,
			modules.append(__import__(mname))
			print " ... ok"
		except Exception, e:
			print " ... failed"
			sys.stderr.write("Could not import module '%s'.\n" % mname)
			sys.stderr.write("Python exception: %s\n" % e)
			sys.exit(1)

	try:
		# Initialise the ORB and find the root POA
		nsname = "NameService=corbaname::" + conf.get("General", "nshost") + \
				":" + conf.get("General", "nsport")
		orb = CORBA.ORB_init(["-ORBnativeCharCodeSet", "UTF-8", "-ORBInitRef",
				nsname, "-ORBendPoint", ":::" + conf.get("General", "port")],
				CORBA.ORB_ID)
		rootpoa = orb.resolve_initial_references("RootPOA")
		# create persistent poa
		ps = [rootpoa.create_lifespan_policy(PortableServer.PERSISTENT),
			  rootpoa.create_id_assignment_policy(PortableServer.USER_ID),
		      rootpoa.create_implicit_activation_policy(PortableServer.NO_IMPLICIT_ACTIVATION)]
		poa = rootpoa.create_POA("pyfredPOA", rootpoa._get_the_POAManager(), ps)

		# Obtain a reference to the root naming context
		obj	= orb.resolve_initial_references("NameService")
		rootContext = obj._narrow(CosNaming.NamingContext)
		if rootContext is None:
			sys.stderr.write("Failed to narrow the root naming context")
			sys.exit(1)
	except CORBA.TRANSIENT, e:
		sys.stderr.write("Is nameservice running?\n(%s)" % e)
		sys.exit(1)
	except CORBA.Exception, e:
		sys.stderr.write("CORBA failure, original exception is:\n%s" % e)
		sys.exit(1)

	# Bind a context named "fred.context" to the root context
	# This context is a container for all registered objects
	name = [CosNaming.NameComponent("fred", "context")]
	try:
		fredContext = rootContext.bind_new_context(name)
		print "New fred context bound"
	except CosNaming.NamingContext.AlreadyBound, ex:
		print "fred context already exists"
		obj = rootContext.resolve(name)
		fredContext = obj._narrow(CosNaming.NamingContext)
		if fredContext is None:
			print "fred.context exists but is not a NamingContext"
			sys.exit(1)

	# Run init methods in all registered modules and bind their objects
	# to fred context
	joblist = []
	for module in modules:
		try:
			servant, name = module.init(Logger(module.__name__), db, rootContext,
					conf, joblist, rootpoa)
		except Exception, e:
			sys.stderr.write("Error when initializing module '%s': %s:%s\n" %
					(module.__name__, sys.exc_info()[0], e))
			sys.exit(1)
		poa.activate_object_with_id(name, servant)
		ref = poa.id_to_reference(name)
		cosname = [CosNaming.NameComponent(name, "Object")]
		try:
			fredContext.bind(cosname, ref)
			print "New '%s' object bound" % name
		except CosNaming.NamingContext.AlreadyBound:
			fredContext.rebind(cosname, ref)
			print "Existing '%s' object rebound" % name

	# Activate objects
	# Activate the POA
	poaManager = poa._get_the_POAManager()
	poaManager.activate()

	# redirect stdin, stdout, stderr to /dev/null. Since now we will use 
	# only syslog
	if detach:
		print "Detaching from terminal"
		sys.stdin.close()
		sys.stdout.close()
		sys.stderr.close()
		sys.stdin  = open("/dev/null", "r")
		sys.stdout = open("/dev/null", "w")
		sys.stderr = open("/dev/null", "w")
	print "Logging to syslog since now"
	syslog.syslog(syslog.LOG_NOTICE, "Python fred Server started.")
	syslog.syslog(syslog.LOG_INFO, "Loaded modules: %s" % modulenames)
	# Run cron jobs forever
	if len(joblist) == 0:
		joblist = [ { "callback":job_noop, "context":None, "period":3600 } ]
	delay = 5 # initial delay
	while True:
		time.sleep(delay)
		# look what is scheduled for execution
		job = joblist.pop(0)
		# execute first job in a qeueu
		try:
			job["callback"](job["context"])
		except Exception, e:
			syslog.syslog(syslog.LOG_ERR, "Unexpected error when "
					"executing job. %s:%s" % (sys.exc_info()[0], e))
		# schedule job for next execution
		job["ticks"] = job["period"]
		for i in range(len(joblist)):
			item = joblist[i]
			if job["ticks"] - item["ticks"] >= 0:
				job["ticks"] -= item["ticks"]
			else:
				joblist.insert(i, job)
				job = None
				break
		if job:
			# job should be run as last
			joblist.insert(len(joblist), job)
		# calculate the time to next awakening
		delay = joblist[0]["ticks"]


	# Block for ever (or until the ORB is shut down)
	#orb.run()

if __name__ == "__main__":
	main(sys.argv)
