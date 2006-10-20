#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
This module is a framework in which can be easily embedded various corba
object implementations through extending modules defined in modules.conf.
Those objects are registered in corba name service and the rest is up to
a caller (corba client).
"""

import sys, time, syslog
from omniORB import CORBA, PortableServer
import CosNaming

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

def getConfiguration(configs):
	"""
Get configuration from file. The configuration files are given as a list in
parameter. The function automatically provides default values for directives
not defined by configuration file. If none of the configuration files exists,
all directives will contain default values.
	"""
	# set defaults
	conf = {"host":"", "dbname":"ccreg",
			"user":"ccreguser", "passwd":"ccregpw",
			"nameservice":"localhost", "log_local":1,
			"log_level":syslog.LOG_INFO}
	port = "5432"
	# read configuration file
	fcontent = ""
	for cfile in configs:
		try:
			cfd = open(cfile, "r")
			fcontent = cfd.read()
			cfd.close()
			print "File %s used as config file" % cfile
			break
		except Exception, e:
			pass #ignore failed opens
	# return default configuration if config was not found or is empty
	if fcontent == "": return conf
	# parse config
	for line in fcontent.split("\n"):
		broken = [ item.strip() for item in line.split("=") ]
		if len(broken) == 2:
			if broken[0] in ("dbname", "user", "password", "host", "port",
					"nameservice", "log_local", "log_level"):
				if broken[0] == "dbname":
					conf["dbname"] = broken[1]
				elif broken[0] == "user":
					conf["user"] = broken[1]
				elif broken[0] == "host":
					conf["host"] = broken[1]
				elif broken[0] == "port":
					port = broken[1]
				elif broken[0] == "password":
					conf["passwd"] = broken[1]
				elif broken[0] == "nameservice":
					conf["nameservice"] = broken[1]
				elif broken[0] == "log_local":
					try:
						conf["log_local"] = int(broken[1])
					except Exception:
						sys.stderr.write("Invalid syslog facility in "
								"configuration file\n")
				elif broken[0] == "log_level":
					loglevels = { "DEBUG":syslog.LOG_DEBUG,
					              "INFO":syslog.LOG_INFO,
					              "NOTICE":syslog.LOG_NOTICE,
					              "WARNING":syslog.LOG_WARNING,
					              "ERR":syslog.LOG_ERR,
					              "CRIT":syslog.LOG_CRIT,
					              "ALERT":syslog.LOG_ALERT,
					              "EMERG":syslog.LOG_EMERG }
					try:
						conf["log_level"] = loglevels[broken[1]]
					except KeyError:
						sys.stderr.write("Invalid log level in configuration "
								"file\n")
	# attach port to hostname if host is not local socket
	if conf["host"]:
		conf["host"] += ":" + port
	return conf

def getModuleNames(configlist):
	"""
Function extracts module names from first found configuration file given
in list parameter configlist. The comments are dropped and module names
returned to caller.
	"""
	modules = []
	for configname in configlist:
		try:
			fd = open(configname, "r")
			# read the content
			lines = [ line.strip() for line in fd.read().split('\n') ]
			fd.close()
			# drop comments and empty lines
			for line in lines:
				if (len(line) > 0) and (not line.startswith("#")): modules.append(line)
			print "File %s used as module config file" % configname
			break
		except Exception, e:
			pass #continue

	return modules

#
# main
#
if __name__ == "__main__":
	# if server should detach from terminal after startup
	detach = 1
	# default places where to look for configs
	configs = ["/etc/ccReg.conf", "/usr/local/etc/ccReg.conf"]
	for arg in sys.argv[1:]:
		if arg == "-d":
			detach = 0
		else:
			# append explicit config location if present on command line
			configs.insert(0, arg)
	# get configuration
	conf = getConfiguration(configs)

	# get a list of modules to import
	modulenames = getModuleNames(["/etc/pyccReg_modules.conf",
			"/usr/local/etc/pyccReg_modules.conf", "pyccReg_modules.conf"])
	# update import path
	sys.path.insert(0, "idl")
	sys.path.insert(0, "/usr/lib/pyccReg/share")
	sys.path.insert(0, "/usr/lib/pyccReg/server")
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
			raise

	try:
		# Initialise the ORB and find the root POA
		orb = CORBA.ORB_init(["-ORBInitRef",
				"NameService=corbaname::" + conf["nameservice"]], CORBA.ORB_ID)
		rootpoa = orb.resolve_initial_references("RootPOA")
		# create persistent poa
		ps = [rootpoa.create_lifespan_policy(PortableServer.PERSISTENT),
			  rootpoa.create_id_assignment_policy(PortableServer.USER_ID),
		      rootpoa.create_implicit_activation_policy(PortableServer.NO_IMPLICIT_ACTIVATION)]
		poa = rootpoa.create_POA("pyccRegPOA", rootpoa._get_the_POAManager(), ps)

		# Obtain a reference to the root naming context
		obj	= orb.resolve_initial_references("NameService")
		rootContext = obj._narrow(CosNaming.NamingContext)
		if rootContext is None:
			sys.stderr.write("Failed to narrow the root naming context")
			sys.exit(1)
	except CORBA.TRANSIENT, e:
		sys.stderr.write("Is nameservice running?\n(%s)" % e)
		raise
	except CORBA.Exception, e:
		sys.stderr.write("CORBA failure, original exception is:\n%s" % e)
		raise

	# Bind a context named "ccReg.context" to the root context
	# This context is a container for all registered objects
	name = [CosNaming.NameComponent("ccReg", "context")]
	try:
		ccRegContext = rootContext.bind_new_context(name)
		print "New ccReg context bound"
	except CosNaming.NamingContext.AlreadyBound, ex:
		print "ccReg context already exists"
		obj = rootContext.resolve(name)
		ccRegContext = obj._narrow(CosNaming.NamingContext)
		if ccRegContext is None:
			print "ccReg.context exists but is not a NamingContext"
			sys.exit(1)

	# open syslog (syslog function will be later passed to modules)
	syslog.openlog("pyccReg", (syslog.LOG_PID | syslog.LOG_CONS),
		(syslog.LOG_LOCAL0, syslog.LOG_LOCAL1, syslog.LOG_LOCAL2,
			syslog.LOG_LOCAL3, syslog.LOG_LOCAL4, syslog.LOG_LOCAL5,
			syslog.LOG_LOCAL6, syslog.LOG_LOCAL7)[conf["log_local"]])
	syslog.setlogmask(syslog.LOG_UPTO(conf["log_level"]))

	# we will give to modules only information they need (about database)
	dbconf = {}
	for citem in conf:
		if citem in ("passwd", "host", "dbname", "user"):
			dbconf[citem] = conf[citem]
	# Run init methods in all registered modules and bind their objects
	# to ccReg context
	for module in modules:
		servant, name = module.init(dbconf, Logger(module.__name__))
		poa.activate_object_with_id(name, servant)
		ref = poa.id_to_reference(name)
		cosname = [CosNaming.NameComponent(name, "Object")]
		try:
			ccRegContext.bind(cosname, ref)
			print "New '%s' object bound" % name
		except CosNaming.NamingContext.AlreadyBound:
			ccRegContext.rebind(cosname, ref)
			print "Existing '%s' object rebound" % name

	# Activate objects
	# Activate the POA
	poaManager = poa._get_the_POAManager()
	poaManager.activate()

	# redirect stdin, stdout, stderr to /dev/null. Since now we will use 
	# only syslog
	if detach:
		sys.stdin.close()
		sys.stdout.close()
		sys.stderr.close()
		sys.stdin  = open("/dev/null", "r")
		sys.stdout = open("/dev/null", "w")
		sys.stderr = open("/dev/null", "w")
	syslog.syslog(syslog.LOG_NOTICE, "Python ccReg Server started.")
	syslog.syslog(syslog.LOG_INFO, "Loaded modules: %s" % modulenames)
	# Block for ever (or until the ORB is shut down)
	orb.run()

