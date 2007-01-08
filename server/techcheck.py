#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of techcheck daemon.
"""

import sys, pgdb, time, random, ConfigParser
import ccReg, ccReg__POA

def getDomainData(cursor, lastrow):
	"""
Assemble data about domain from db rows to logical units.
	"""
	if not lastrow:
		return None
	# init values
	objid = lastrow[0]
	histid = lastrow[1]
	domain = lastrow[2]
	level = lastrow[3]
	nslist = {}
	if lastrow[5]:
		nslist[ lastrow[4] ] = [ lastrow[5] ]
	else:
		nslist[ lastrow[4] ] = []
	# agregate nameservers and their addrs
	currow = cursor.fetchone()
	while currow and objid == currow[0]:
		if currow[5]:
			nslist[ currow[4] ] = [ currow[5] ]
		else:
			nslist[ currow[4] ] = []
		currow = cursor.fetchone()
	return currow, objid, histid, domain, nslist, level


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

		# default configuration
		self.scriptdir = ""
		# Parse TechCheck-specific configuration
		if conf.has_section("TechCheck"):
			try:
				scriptdir = conf.get("TechCheck", "scriptdir")
				if scriptdir:
					self.scriptdir = scriptdir
			except ConfigParser.NoOptionError, e:
				pass
		if not self.scriptdir:
			raise Exception("Option 'scriptdir' for techcheck daemon is "
					"mandatory.")
		self.l.log(self.l.INFO, "Object initialized")

	def check_authoritative(self, domain, nslist, ctx):
		"""
	Check that nameservers are authoritative for a domain. The test is
	based on value of bit in DNS answer.
		"""
		badlist = ""
		for ns in ctx:
			# the sixth bit in flags in DNS answer is "Authoritative bit"
			if not ctx[ns].flags & (2 ** 5):
				badlist += ns + " "
		if badlist:
			return [ False, "Following nameservers are not authoritative for "
					"domain '%s': %s" % (domain, badlist) ]
		return [ True, "" ]

	def check_autonomous(self, domain, nslist, ctx):
		"""
	Check that nameserver is not subdomain of the domain.
		"""
		badlist = ""
		for ns in nslist:
			if ns.endswith(domain):
				badlist += ns + " "
		if badlist:
			return [ False, "Following nameservers for domain '%s' are not "
					"autonomous: %s" % (domain, badlist) ]
		return [ True, "" ]

	def check_existance(self, domain, nslist, ctx):
		"""
	Method tests DNS server's existance by issuing DNS query for the domain.
	This test is done for all nameservers of domain. The answer object is
	used in some of the subsequent tests. GLUEs are tested as well.
		"""
		query = dns.message.make_query(domain, "ANY")
		for ns in nslist:
			if ns.endswith(domain):
				if not nslist[ns]:
					return [ False, "Missing GLUE for nameserver '%s' for "
							"domain '%s'" % (ns, domain) ]
				for addr in nslist[ns]:
					answer = dns.query.udp(query, addr, self.timeout)
					#except dns.exception.Timeout, e:
					#	return [ False, "Timeout" ]
			else:
				response = dns.resolver.query(ns)
				for addr in response:
					answer = dns.query.udp(query, addr, self.timeout)
					break
			ctx[ns] = answer
		return [ True, "" ]

	def check_heterogenous(self, domain, nslist, ctx):
		return [ True, "" ]

	def check_recursive(self, domain, nslist, ctx):
		"""
	Method tests, based on a flag in answer, if server is recursive.
		"""
		badlist = ""
		for ns in ctx:
			# the 9th bit in flags in DNS answer is "Recursive bit"
			if not ctx[ns].flags & (2 ** 8):
				badlist += ns + " "
		if badlist:
			return [ False, "Following nameservers for domain '%s' claim to be "
					"recursive: %s" % (domain, badlist) ]
		return [ True, "" ]

	def check_recursive4all(self, domain, nslist, ctx):
		"""
	Method tests if server is recursive by test.
		"""
		if self.bait.endswith(domain):
			# exclude bait from test
			return [ True, "" ]
		badlist = ""
		query = dns.message.make_query(self.bait, "ANY")
		for ns in nslist:
			response = dns.resolver.query(ns)
			for addr in response:
				answer = dns.query.udp(query, addr, self.timeout)
				break
			if answer.answer:
				badlist += ns + " "
		if badlist:
			return [ False, "Following nameservers for domain '%s' are recursive"
					" for all: %s" % (domain, badlist) ]
		return [ True, "" ]

	def __dbNewCheckId(self, conn):
		"""
	Get next available ID of email. This ID is used in message-id header and
	when archiving email.
		"""
		cur = conn.cursor()
		cur.execute("SELECT nextval('check_domain_id_seq')")
		id = cur.fetchone()[0]
		cur.close()
		return id

	def __dbBuildTestSuite(self, conn):
		"""
	This routine pulls information about tests from database and puts together
	a test suite.
		"""
		# init list of checks
		testsuite = {}
		# Get all enabled tests
		cur = conn.cursor()
		cur.execute("SELECT id, name, severity, script FROM check_test WHERE "
				"disabled = False")
		tests = cur.fetchall()
		# Get dependencies of tests
		for test in tests:
			cur.execute("SELECT testid FROM check_dependance WHERE addictid = %d"
					% test[0])
			testsuite[ test[0] ] = {
				"id" : test[0],
				"name" : test[1],
				"level" : test[2],
				"callback" : test[3],
				"requires" : [ item[0] for item in cur.fetchall() ]
				}
		cur.close()
		return testsuite

	def __dbGetDomainData(self, conn, domain):
		"""
	Get all data about domain from database needed for technical checks.
		"""
		cur = conn.cursor()
		cur.execute("SELECT o.id, oreg.historyid, ns.id, ns.checklevel "
				"FROM object_registry oreg, object o, domain d LEFT JOIN "
				"nsset ns ON (d.nsset = ns.id) WHERE oreg.name = %s AND "
				"oreg.id = o.id AND oreg.id = d.id " % pgdb._quote(domain))
		if cur.rowcount == 0:
			raise ccReg.TechCheck.DomainNotFound()
		objid, histid, nssetid, level = cur.fetchone()
		if not nssetid:
			raise ccReg.TechCheck.NoAssociatedNsset()
		cur.execute("SELECT h.fqdn, ip.ipaddr FROM host h LEFT JOIN "
				"host_ipaddr_map ip ON (h.id = ip.hostid) WHERE h.nssetid = %d "
				"ORDER BY h.fqdn" % nssetid)
		row = cur.fetchone()
		nameservers = {}
		while row:
			fqdn, addr = row
			if (fqdn in nameservers) and addr:
				nameservers[fqdn].append(addr)
			elif addr:
				nameservers[fqdn] = [ addr ]
			else:
				nameservers[fqdn] = []
			row = cur.fetchone()
		cur.close()
		return objid, histid, nameservers, level

	def __dbGetAllDomains(self, conn):
		"""
	Get all active domains with associated nsset.
		"""
		cur = conn.cursor()
		cur.execute("SELECT oreg.id, oreg.historyid AS hid, oreg.name, "
					"ns.checklevel, h.fqdn, h.id AS hostid "
				"INTO TEMP TABLE check_temp "
				"FROM genzone_domain_history gh, object_registry oreg, domain d,"
					" nsset ns, host h "
				"WHERE gh.last = 'True' AND gh.inzone = 'True' AND "
					"gh.domain_id = oreg.id AND d.id = oreg.id AND "
					"d.nsset = ns.id AND d.nsset = h.nssetid "
				"ORDER BY oreg.id, h.fqdn")
		cur.execute("SELECT c.id, c.hid, c.name, c.checklevel, c.fqdn, a.ipaddr "
				"FROM check_temp c LEFT JOIN host_ipaddr_map a "
				"ON (c.hostid = a.hostid) ORDER BY c.id, c.fqdn")
		return cur

	def __dbArchiveCheck(self, conn, id, objid, histid, status, results, reason):
		"""
	Archive result of technical test on domain in database.
		"""
		if reason == ccReg.CHKR_EPP:
			reason_enum	= 0
		elif reason == ccReg.CHKR_MANUAL:
			reason_enum	= 1
		elif reason == ccReg.CHKR_REGULAR:
			reason_enum	= 2
		else:
			reason_enum	= 3
		cur = conn.cursor()
		cur.execute("INSERT INTO check_domain (id, domain_id, domain_hid, "
				"reason, overallstatus) VALUES (%d, %d, %d, %d, '%s')" %
				(id, objid, histid, reason_enum, status))
		# archive results of individual tests
		for resid in results:
			result = results[resid]
			if result["note"]:
				raw_note = pgdb._quote(result["note"])
			else:
				raw_note = "NULL"
			cur.execute("INSERT INTO check_result (checkid, testid, passed, "
					"note) VALUES (%d, %d, '%s', %s)" %
					(id, resid, result["result"], raw_note))
		cur.close()

	def __checkDomain(self, id, testsuite, domain, nslist, level):
		"""
	Run all enabled tests bellow given level.
		"""
		results = {}
		atLeastOneFailed = False
		# perform all enabled tests (the ids must be sorted!)
		testkeys = testsuite.keys()
		testkeys.sort()
		for testid in testkeys:
			test = testsuite[testid]
			# check level
			if test["level"] > level:
				self.l.log(self.l.DEBUG, "<%d> Omitting test '%s' becauseof its "
						"level." % (id, test["name"]))
				continue
			# check prerequisities
			req_ok = True
			for req in test["requires"]:
				# the test might not be done if it was disabled
				try:
					deptest = results[req]
				except KeyError, e:
					self.l.log(self.l.WARNING, "<%d> Test '%s' depends on a "
							"test which is disabled." % (id, test["name"]))
					continue
				# check the result of test on which we depend
				if not results[req]["result"]:
					self.l.log(self.l.DEBUG, "<%d> Omitting test '%s' becauseof "
							"not fulfilled prerequisity." %
							(id, test["name"]))
					req_ok = False
					break
			if not req_ok:
				continue
			# run the test
			self.l.log(self.l.DEBUG, "<%d> Running test '%s'." %
					(id, test["name"]))
			#stat, note = test["callback"](domain, nslist)
			stat = 0
			note = ""
			stat = (stat == 0)
			if not stat:
				atLeastOneFailed = True
			# save the result
			results[testid] = { "result" : stat, "note" : note }
		return not atLeastOneFailed, results

	def __transfmResult(self, id, testsuite, status, results):
		"""
	Transform results to IDL result structure.
		"""
		idl_results = []
		for testid in results:
			result = results[testid]
			test = testsuite[testid]
			idl_results.append( ccReg.OneCheckResult(test["name"],
				result["result"], result["note"], test["level"]) )
		return ccReg.CheckResult(id, status, idl_results)

	def checkDomain(self, domain, reason):
		"""
	Method from IDL interface. Run all enabled tests for a domain.
		"""
		try:
			id = 0
			# connect to database
			conn = self.db.getConn()
			# get unique ID
			id = self.__dbNewCheckId(conn)
			self.l.log(self.l.INFO, "<%d> Request for technical test of domain "
					"'%s' received." % (id, domain))

			# get all data about the domain necessary to perform tech check
			objid, histid, nslist, level = self.__dbGetDomainData(conn, domain)
			testsuite = self.__dbBuildTestSuite(conn)
			# perform tests on a domain
			status, results = self.__checkDomain(id, testsuite, domain, nslist,
					level)
			# archive results of check
			self.__dbArchiveCheck(conn, id, objid, histid, status, results,
					reason)
			# commit changes in archive
			conn.commit()

			self.db.releaseConn(conn)
			return self.__transfmResult(id, testsuite, status, results)

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

	def checkAll(self):
		"""
	Method goes through all active domains and checks their healthy.
		"""
		try:
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> Regular technical test of all domains "
					"is being run." % id)
			# connect to database
			conn = self.db.getConn()
			# build testsuite
			testsuite = self.__dbBuildTestSuite(conn)
			# get all active domains generated in zone which have nsset
			cursor = self.__dbGetAllDomains(conn)
			print cursor.rowcount
			# iterate through all selected domains and test one-by-one
			lastrow = cursor.fetchone()
			iter = 0
			while True:
				checkid = self.__dbNewCheckId(conn)
				# assamble data about one domain
				data = getDomainData(cursor, lastrow)
				if not data:
					break
				(lastrow, objid, histid, domain, nslist, level) = data
				status, results = self.__checkDomain(id, testsuite, domain,
					nslist, level)
				# archive results of tests
				self.__dbArchiveCheck(conn, checkid, objid, histid, status,
						results, ccReg.CHKR_REGULAR)
				# TODO send accumulated email notification
			# finalization
			cursor.close()
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

