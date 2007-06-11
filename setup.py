#!/usr/bin/env python
# vim: set ts=4 sw=4:
#
import sys, os.path, string, commands
from distutils import core
from distutils import cmd
from distutils import log
from distutils import util
from distutils import errors
from distutils import version
from distutils.command import config
from distutils.command import build

core.DEBUG = False
modules = ["FileManager", "Mailer", "TechCheck", "ZoneGenerator"]

class Config (config.config):
	"""
	This is config class, which checks for pyfred specific prerequisities.
	"""

	description = "Check prerequisities of pyfred"

	def run(self):
		"""
		The equivalent of classic configure script. The list of things tested
		here:
			*) OS
			*) Python version
			*) presence of omniORB, pygresql, dnspython, clearsilver modules
		"""

		# List of tests which follow
		error = False

		# OS
		log.info(" * Operating system ... %s", sys.platform)
		if sys.platform[:5] != "linux":
			log.error("    The pyfred is not platform independent and requires "
					"linux OS to run.")

		# python version
		python_version = version.StrictVersion(sys.version.split(' ')[0])
		log.info(" * Python version ... %s", python_version)
		# check lower bound
		if python_version < "2.4":
			log.error("    At least version 2.4 is required.")
			error = True
		# check upper bound
		if python_version >= "2.6":
			log.warn("    Pyfred was tested with version 2.4 and 2.5. Running "
					"more recent version of \n    python might lead to a "
					"problems. You have been warned.")

		# check module (package) dependencies
		try:
			import omniORB
			log.info(" * Package omniORB found (version cannot be verified).")
		except ImportError, e:
			log.error(" * Package omniORB with python bindings is required and "
					"not installed!")
			log.info("    omniORB is ORB implementation in C++ "
					"(http://omniorb.sourceforge.net/)")
			error = True

		try:
			import pgdb
			pgdb_version = version.StrictVersion(pgdb.version)
			log.info(" * package pygresql version ... %s", pgdb.version)
			if pgdb_version < "3.6":
				log.error("    At least version 3.6 of pygresql is required!")
				error = True
			if pgdb_version >= "3.9":
				log.warn("    Versions newer than 3.8 of pygresql are not "
						"tested to work with pyfred.\n    Use at your own risk.")
		except ImportError, e:
			log.error(" * Package pygresql is required and not installed!")
			log.info("    pygresql is DB2 API compliant library for postgresql "
					"(http://www.pygresql.org/).")
			error = True

		try:
			import dns.version
			log.info(" * Package dnspython version ... %s", dns.version.version)
			dns_version = version.StrictVersion(dns.version.version)
			if dns_version < "1.3":
				log.error("    At least version 1.3 of dnspython is required!")
				error = True
			if dns_version > "1.5":
				log.warn("    Versions newer than 1.5 of dnspython are not "
						"tested to work with pyfred.\n    Use at your own risk.")
		except ImportError, e:
			log.error(" * Package dnspython with python bindings is required "
					"and not installed!")
			log.info("    dnspython is DNS library (http://www.dnspython.org/)")
			error = True

		try:
			import neo_cgi
			cs_CAPI_version = neo_cgi._C_API_NUM
			log.info(" * C API version of clearsilver ... %d", cs_CAPI_version)
			if cs_CAPI_version != 4:
				log.warn("    The only tested C API version of clearsilver is 4."
						"   Use at your own risk")
		except ImportError, e:
			log.error(" * Package clearsilver with python bindings is required "
					"and not installed!")
			log.info("    clearsilver is template system "
					"(http://www.clearsilver.net/).")
			error = True

		# bad test
		#error = True

		# print concluding status of test
		if error:
			log.error("One or more errors were detected. Please fix them and "
					"then run the \nsetup script again.")
			raise SystemExit(1)
		else:
			log.info("All tests were passed successfully")


def compile_idl(cmd, pars, files):
	"""
	Put together command line for python stubs generation.
	"""
	cmdline = cmd +' '+ string.join(pars) +' '+ string.join(files)
	log.info(cmdline)
	status, output = commands.getstatusoutput(cmdline)
	log.info(output)
	if status != 0:
		raise errors.DistutilsExecError("Return status of %s is %d" %
				(cmd, status))

def gen_idl_name(dir, name):
	"""
	Generate name of idl file from directory prefix and IDL module name.
	"""
	return os.path.join(dir, name + ".idl")

class Build_idl (cmd.Command):
	"""
	This class realizes a subcommand of build command and is used for building
	IDL stubs.
	"""

	description = "Generate python stubs from IDL files"

	user_options = [
			("omniidl=", "i", "omniidl program used to build stubs"),
			("idldir=",  "d", "directory where IDL files reside")
			]

	def initialize_options(self):
		self.idldir  = None
		self.omniidl = None
		self.omniidl_params = ["-bpython", "-Wbinline"]
		self.idlfiles = ["FileManager", "Mailer", "TechCheck", "ZoneGenerator"]

	def finalize_options(self):
		if not self.omniidl:
			self.omniidl = "omniidl"
		if not self.idldir:
			raise errors.DistutilsOptionError("idldir option to \"build\" "
					"command must be specified")

	def run(self):
		global modules

		self.omniidl_params.append("-Wbpackage=pyfred.idlstubs")
		util.execute(compile_idl,
			(self.omniidl, self.omniidl_params,
				[ gen_idl_name(self.idldir, module) for module in modules ]),
				"Generating python stubs from IDL files")


class Build (build.build):
	"""
	This is here just to override default sub_commands list of build class.
	We added 'build_idl' item.
	"""
	def has_pure_modules (self):
		return self.distribution.has_pure_modules()

	def has_c_libraries (self):
		return self.distribution.has_c_libraries()

	def has_ext_modules (self):
		return self.distribution.has_ext_modules()

	def has_scripts (self):
		return self.distribution.has_scripts()

	def has_idl_files (self):
		return True

	sub_commands = [('build_py',      has_pure_modules),
					('build_clib',    has_c_libraries),
					('build_ext',     has_ext_modules),
					('build_scripts', has_scripts),
					('build_idl',     has_idl_files)
				   ]


try:
	core.setup(name="pyfred", version="1.4.2",
			description="Component of FRED (Fast Registry for Enum and Domains)",
			author   = "Jan Kryl",
			author_email="jan.kryl@nic.cz",
			url      = "http://enum.nic.cz/",
			license  = "GNU GPL",
			cmdclass = { "config":Config, "build":Build, "build_idl":Build_idl },
			packages = ["pyfred", "pyfred.modules", "pyfred.idlstubs",
				"pyfred.idlstubs.ccReg", "pyfred.idlstubs.ccReg__POA"],
			scripts  = [
				"scripts/pyfred_server",
				"scripts/pyfredctl",
				"scripts/filemanager_admin_client",
				"scripts/filemanager_client",
				"scripts/genzone_client",
				"scripts/genzone_test",
				"scripts/mailer_admin_client",
				"scripts/mailer_client",
				"scripts/techcheck_admin_client",
				"scripts/techcheck_client",
				],
			data_files = [
				("libexec/pyfred",
					[
						"tc_scripts/authoritative.py",
						"tc_scripts/autonomous.py",
						"tc_scripts/existance.py",
						"tc_scripts/heterogenous.py",
						"tc_scripts/presence.py",
						"tc_scripts/recursive4all.py",
						"tc_scripts/recursive.py"
					]
				),
#				("/etc/fred", ["pyfred.conf-example"])
				]
			)

except Exception, e:
	log.error("Error: %s", e)

