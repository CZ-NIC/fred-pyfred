#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of techcheck daemon.
"""

import sys, pgdb
import ccReg, ccReg__POA

class TechCheck_i (ccReg__POA.TechCheck):
	"""
This class implements TechCheck interface.
	"""
	# Test seriosity levels
	CHK_ERROR = 0
	CHK_WARNING = 1
	CHK_NOTICE = 2

	def __init__(self, logger, db, conf):
		"""
	Initializer saves db (which is later used for opening database
	connection) and logger (used for logging).
		"""
		# ccReg__POA.TechCheck doesn't have constructor
		self.db = db # db connection string
		self.l = logger # syslog functionality

		# init list of checks
		self.checklist = []
		# default configuration
		check_authoritative = True
		check_autonomous = True
		check_existance = True
		check_heterogenous = True
		check_recursive = True
		check_recursive4all = True
		# Parse TechCheck-specific configuration
		if conf.has_section("TechCheck"):
			# Enable individual checks
			try:
				flag = conf.get("TechCheck", "check_authoritative")
				if flag.upper() in ("NO", "OFF", "0"):
					check_authoritative = False
			except ConfigParser.NoOptionError, e:
				pass

			try:
				flag = conf.get("TechCheck", "check_autonomous")
				if flag.upper() in ("NO", "OFF", "0"):
					check_autonomous = False
			except ConfigParser.NoOptionError, e:
				pass

			try:
				flag = conf.get("TechCheck", "check_existance")
				if flag.upper() in ("NO", "OFF", "0"):
					check_existance = False
			except ConfigParser.NoOptionError, e:
				pass

			try:
				flag = conf.get("TechCheck", "check_heterogenous")
				if flag.upper() in ("NO", "OFF", "0"):
					check_heterogenous = False
			except ConfigParser.NoOptionError, e:
				pass

			try:
				flag = conf.get("TechCheck", "check_recursive")
				if flag.upper() in ("NO", "OFF", "0"):
					check_recursive = False
			except ConfigParser.NoOptionError, e:
				pass

			try:
				flag = conf.get("TechCheck", "check_recursive4all")
				if flag.upper() in ("NO", "OFF", "0"):
					check_recursive4all = False
			except ConfigParser.NoOptionError, e:
				pass

		# The checks must be queued in order in which they depend on each other
		if check_autonomous:
			self.checklist.append( {
				"name":"autonomous",
				"callback":self.check_autonomous,
				"level":self.CHK_WARNING,
				"requires":[]
				} )
		if check_existance:
			self.checklist.append( {
				"name":"existance",
				"callback":self.check_existance,
				"level":self.CHK_ERROR,
				"requires":[]
				} )
		if check_authoritative:
			self.checklist.append( {
				"name":"authoritative",
				"callback":self.check_authoritative,
				"level":self.CHK_ERROR,
				"requires":["existance"]
				} )
		if check_heterogenous:
			self.checklist.append( {
				"name":"heterogenous",
				"callback":self.check_heterogenous,
				"level":self.CHK_NOTICE,
				"requires":["existance"]
				} )
		if check_recursive:
			self.checklist.append( {
				"name":"recursive",
				"callback":self.check_recursive,
				"level":self.CHK_WARNING,
				"requires":["existance"]
				} )
		if check_recursive4all:
			self.checklist.append( {
				"name":"recursive4all",
				"callback":self.check_recursive4all,
				"level":self.CHK_WARNING,
				"requires":["existance"]
				} )

		self.l.log(self.l.DEBUG, "Object initialized")
		for check in self.checklist:
			self.l.log(self.l.DEBUG, "Test '%s' enabled." % check["name"])

	def check_authoritative(self, domain, nslist):
		return [ True, "" ]

	def check_autonomous(self, domain, nslist):
		return [ True, "" ]

	def check_existance(self, domain, nslist):
		"""
	Method tests server's existance by issuing DNS query for the domain.
		"""
		return [ True, "" ]

	def check_heterogenous(self, domain, nslist):
		return [ True, "" ]

	def check_recursive(self, domain, nslist):
		return [ True, "" ]

	def check_recursive4all(self, domain, nslist):
		return [ True, "" ]

	def __dbArchiveCheck(self, conn, domain, nslist, level, results):
		return 1

	def __dbGetDomainData(self, conn, domain):
		"""
	Get all data about domain from database needed for technical checks.
		"""
		cur = conn.cursor()
		cur.execute("SELECT nsset.id, nsset.checklevel FROM domain, nsset "
				"WHERE domain.fqdn = %s AND nsset.id = domain.nsset" %
				pgdb._quote(domain))
		if cur.rowcount == 0:
			raise ccReg.TechCheck.NoAssociatedNsset()
		nssetid, dblevel = cur.fetchone()
		cur.execute("SELECT fqdn FROM host WHERE nssetid = %d" % nssetid)
		nameservers = [ item[0] for item in cur.fetchall() ]
		cur.close()
		# convert level
		if dblevel == 0:
			level = self.CHK_ERROR
		elif dblevel == 1:
			level = self.CHK_WARNING
		else:
			level = self.CHK_NOTICE
		return nameservers, level

	def __checkDomain(self, domain, nslist, level):
		"""
	Run all enabled tests in permitted levels.
		"""
		results = {}
		# perform all enabled tests
		for check in self.checklist:
			# check level
			if check["level"] > level:
				self.l.log(self.l.DEBUG, "Omitting test '%s' based on level" %
						check["name"])
				continue
			# check prerequisities
			req_ok = True
			for req in check["requires"]:
				if not results[req]["result"]:
					self.l.log(self.l.DEBUG, "Omitting test '%s' becauseof not "
							"fulfilled prerequisity '%s'" % (check["name"], req))
					req_ok = False
					break
			# run the test
			if req_ok:
				self.l.log(self.l.DEBUG, "Running test '%s'" % check["name"])
				stat, note = check["callback"](domain, nslist)
				results[check["name"]] = {
						"result": stat,
						"note": note,
						"level": check["level"]
						}
		return results

	def __transfmResult(self, id, results):
		"""
	Transform results to IDL result structure.
		"""
		idl_results = []
		atLeastOneFailed = False
		for name in results:
			result = results[name]
			# convert level to idl level
			if result["level"] == self.CHK_ERROR:
				level = ccReg.CHECK_ERROR
			elif result["level"] == self.CHK_WARNING:
				level = ccReg.CHECK_WARNING
			else:
				level = ccReg.CHECK_INFO
			idl_results.append( ccReg.OneCheckResult(name,
				result["result"], result["note"], level) )
			if not result["result"]:
				atLeastOneFailed = True
		return ccReg.CheckResult(id, not atLeastOneFailed, idl_results)

	def checkDomain(self, domain, reason):
		"""
	Method from IDL interface. Run all enabled tests for a domain.
		"""
		self.l.log(self.l.DEBUG, "Request for technical test for domain '%s' "
				"received" % domain)

		conn = None
		try:
			# connect to database
			conn = self.db.getConn()

			# get all data about the domain necessary to perform tech check
			nslist, level = self.__dbGetDomainData(conn, domain)

			results = self.__checkDomain(domain, nslist, level)

			# archive results of check
			id = self.__dbArchiveCheck(conn, domain, nslist, level, results)

			# commit changes in archive
			conn.commit()
			self.db.releaseConn(conn)

			return self.__transfmResult(id, results)

		except ccReg.TechCheck.NoAssociatedNsset, e:
			self.l.log(self.l.INFO, "Domain '%s' does not exist or has no "
					"associated nsset" % domain);
			if conn: self.db.releaseConn(conn)
			raise
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "Database error: %s" % e)
			if conn: self.db.releaseConn(conn)
			raise ccReg.TechCheck.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "Unexpected exception caught: %s:%s" %
					(sys.exc_info()[0], e))
			raise ccReg.TechCheck.InternalError("Unexpected error")


def init(logger, db, nsref, conf, joblist, rootpoa):
	"""
Function which creates, initializes and returns servant TechCheck.
	"""
	# Create an instance of TechCheck_i and an TechCheck object ref
	servant = TechCheck_i(logger, db, conf)
	return servant, "TechCheck"

