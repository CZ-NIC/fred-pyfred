#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of techcheck daemon.
"""

import sys, pgdb, time, ConfigParser
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
		self.period = 24 # in hours
		self.firsttime = 12 # hour
		check_authoritative = True
		check_autonomous = True
		check_existance = True
		check_heterogenous = True
		check_recursive = True
		check_recursive4all = True
		# Parse TechCheck-specific configuration
		if conf.has_section("TechCheck"):
			# set period
			try:
				period = conf.get("TechCheck", "period")
				if period:
					self.l.log(self.l.DEBUG, "period is set to '%s'." % period)
					try:
						self.period = int(period)
					except ValueError, e:
						self.l.log(self.l.ERR, "Number required for period "
								"configuration directive.")
						raise
			except ConfigParser.NoOptionError, e:
				pass
			# set starting hour of regular check
			try:
				firsttime = conf.get("TechCheck", "firsttime")
				if firsttime:
					self.l.log(self.l.DEBUG, "firsttime is set to '%s'." %
							firsttime)
					try:
						self.firsttime = int(firsttime)
					except ValueError, e:
						self.l.log(self.l.ERR, "Number required for firsttime "
								"configuration directive.")
						raise
			except ConfigParser.NoOptionError, e:
				pass
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

		# compute offset from now to firsttime hour
		currtime = time.localtime()
		ticks = self.firsttime * 3600 - (currtime[3] * 3600 + currtime[4] * 60)
		if ticks < 0:
			ticks = 24*60*60 - ticks
		# schedule regular cleanup
		#joblist.append( { "callback":self.regular_check, "context":None,
		#	"period":self.period * 60 * 60, "ticks":ticks } )
		for check in self.checklist:
			self.l.log(self.l.DEBUG, "Test '%s' enabled." % check["name"])
		self.l.log(self.l.INFO, "Object initialized")

	def check_authoritative(self, domain, nslist):
		return [ True, "" ]

	def check_autonomous(self, domain, nslist):
		"""
	Check that nameserver is not subdomain of the domain.
		"""
		for ns in nslist:
			if ns.endswith(domain):
				return [ False, "Nsset '%s' is not autonomous." % ns ]
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
		cur.execute("SELECT or.historyID, ns.id, ns.checklevel FROM "
				"object_registry or, object o, domain d WHERE "
				"or.name = %s AND or.id = o.id AND or.id = d.id "
				"LEFT JOIN nsset ns ON (d.nsset = ns.id) " % pgdb._quote(domain))
		if cur.rowcount == 0:
			raise ccReg.TechCheck.DomainNotFound()
		histid, nssetid, dblevel = cur.fetchone()
		if not nssetid:
			raise ccReg.TechCheck.NoAssociatedNsset()
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
		return histid, nameservers, level

	def __dbGetAllDomains(self, conn):
		"""
	Get all active domains with associated nsset.
		"""
		cur = conn.cursor()
		cur.execute("SELECT or.historyid, o.name, ns.checklevel, h.fqdn "
				"FROM object_registry or, object o, domain d, nsset ns, host h "
				"WHERE or.id = o.id AND or.id = d.id AND d.nsset = ns.id AND "
				"d.nsset = h.nssetid ORDER BY o.name")
		return cur

	def __checkDomain(self, id, domain, nslist, level):
		"""
	Run all enabled tests in permitted levels.
		"""
		results = {}
		# perform all enabled tests
		for check in self.checklist:
			# check level
			if check["level"] > level:
				self.l.log(self.l.DEBUG, "<%d> Omitting test '%s' becauseof its "
						"level." % (id, check["name"]))
				continue
			# check prerequisities
			req_ok = True
			for req in check["requires"]:
				if not results[req]["result"]:
					self.l.log(self.l.DEBUG, "<%d> Omitting test '%s' becauseof "
							"not fulfilled prerequisity '%s'." %
							(id, check["name"], req))
					req_ok = False
					break
			# run the test
			if req_ok:
				self.l.log(self.l.DEBUG, "<%d> Running test '%s'." %
						(id, check["name"]))
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
		try:
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> Request for technical test for domain "
					"'%s' received" % domain)
			# connect to database
			conn = self.db.getConn()

			# get all data about the domain necessary to perform tech check
			histid, nslist, level = self.__dbGetDomainData(conn, domain)

			results = self.__checkDomain(id, domain, nslist, level)

			# archive results of check
			id = self.__dbArchiveCheck(conn, domain, nslist, level, results)

			# commit changes in archive
			conn.commit()
			self.db.releaseConn(conn)

			return self.__transfmResult(id, results)

		except ccReg.TechCheck.DomainNotFound, e:
			self.l.log(self.l.ERR, "<%d> Domain '%s' does not exist." %
					(id, domain))
			raise
		except ccReg.TechCheck.NoAssociatedNsset, e:
			self.l.log(self.l.ERR, "<%d> Domain '%s' does not have associated "
					"nsset" % (id, domain))
			raise
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
			raise ccReg.TechCheck.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception caught: %s:%s" %
					(id, sys.exc_info()[0], e))
			raise ccReg.TechCheck.InternalError("Unexpected error")

	def regularCheck(self):
		"""
	Method goes through all active domains and checks their healthy.
		"""
		try:
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "Regular technical check of domains is "
					"being run.")
			# connect to database
			conn = self.db.getConn()
			cur = conn.cursor()

			# get all active domains which have nsset
			cursor = self.__dbGetAllDomains(conn)
			row = cursor.fetchone()
			while row:
				results = self.__checkDomain(id, domain, nslist, level)
				# archive results of check
				id = self.__dbArchiveCheck(conn, domain, nslist, level, results)

			# commit changes in archive
			conn.commit()
			self.db.releaseConn(conn)

		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
			raise ccReg.TechCheck.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception caught: %s:%s" %
					(id, sys.exc_info()[0], e))
			raise ccReg.TechCheck.InternalError("Unexpected error")

def init(logger, db, nsref, conf, joblist, rootpoa):
	"""
Function which creates, initializes and returns servant TechCheck.
	"""
	# Create an instance of TechCheck_i and an TechCheck object ref
	servant = TechCheck_i(logger, db, conf)
	return servant, "TechCheck"

