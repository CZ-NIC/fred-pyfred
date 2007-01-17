#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of techcheck daemon.
"""

import sys, pgdb, time, random, ConfigParser, commands, os, popen2
from exceptions import SystemExit
import ccReg, ccReg__POA

def convArray(list):
	"""
Converts python list to pg array.
	"""
	array = '{'
	for item in list:
		array += pgdb._quote(item) + ','
	# trim ending ','
	if len(array) > 1:
		array = array[0:-1]
	array += '}'
	return pgdb._quote(array)

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
		self.exMsg = 7
		self.testmode = False
		# Parse TechCheck-specific configuration
		if conf.has_section("TechCheck"):
			try:
				scriptdir = conf.get("TechCheck", "scriptdir")
				if scriptdir:
					self.scriptdir = scriptdir.strip()
			except ConfigParser.NoOptionError, e:
				pass
			try:
				exMsg = conf.get("TechCheck", "msgLifetime")
				if exMsg:
					self.exMsg = int(exMsg)
			except ConfigParser.NoOptionError, e:
				pass
			try:
				testmode = conf.get("TechCheck", "testmode")
				if testmode:
					if testmode.upper() in ("YES", "ON", "1"):
						self.l.log(self.l.DEBUG, "Test mode is turned on.")
						self.testmode = True
			except ConfigParser.NoOptionError, e:
				pass
		if not self.scriptdir:
			raise Exception("Option 'scriptdir' for techcheck daemon is "
					"mandatory.")
		if not os.path.isdir(self.scriptdir):
			raise Exception("Scriptdir '%s' does not exist." % self.scriptdir)
		if not os.access(self.scriptdir, os.R_OK):
			raise Exception("Scriptdir '%s' is not readable" % self.scriptdir)
		# add trailing '/' to scriptdir if not given
		if self.scriptdir[-1] != '/':
			self.scriptdir += '/'
		self.l.log(self.l.INFO, "Object initialized")

	def __dbBuildTestSuite(self, conn):
		"""
	This routine pulls information about tests from database and puts together
	a test suite.
		"""
		# init list of checks
		testsuite = {}
		# Get all enabled tests
		cur = conn.cursor()
		cur.execute("SELECT id, name, severity, script, need_domain "
				"FROM check_test WHERE disabled = False")
		tests = cur.fetchall()
		# Get dependencies of tests
		for test in tests:
			cur.execute("SELECT testid FROM check_dependance WHERE addictid = %d"
					% test[0])
			testsuite[ test[0] ] = {
				"id" : test[0],
				"name" : test[1],
				"level" : test[2],
				"script" : test[3],
				"need_domain" : test[4],
				"requires" : [ item[0] for item in cur.fetchall() ]
				}
		cur.close()
		return testsuite

	def __dbGetAssocDomains(self, conn, objid):
		"""
	Dig all associated domains with nsset from database.
		"""
		cur = conn.cursor()
		cur.execute("SELECT oreg.name FROM domain d, object_registry oreg "
				"WHERE oreg.type = 3 AND d.id = oreg.id AND d.nsset = %d" %
				objid)
		fqdns = [ item[0] for item in cur.fetchall() ]
		cur.close()
		return fqdns

	def __dbGetNssets(self, cur, handle = ''):
		"""
	Get all active nssets. If handle is not empty string, then get just one
	nsset with given handle.
		"""
		sql = "SELECT oreg.id, oreg.historyid, oreg.name, ns.checklevel " \
				"FROM object_registry oreg, nsset ns " \
				"WHERE oreg.id = ns.id AND oreg.type = 2"
		if handle:
			sql += " AND upper(oreg.name) = upper(%s)" % pgdb._quote(handle)
		cur.execute(sql)

	def __dbGetHosts(self, conn, id):
		"""
	Get hosts, their ip addresses and domain names associated with nsset.
		"""
		cur = conn.cursor()
		cur.execute("SELECT h.fqdn, ip.ipaddr FROM host h LEFT JOIN "
				"host_ipaddr_map ip ON (h.id = ip.hostid) WHERE h.nssetid = %d "
				"ORDER BY h.fqdn" % id)
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
		return nameservers

	def __dbGetNssetData(self, conn, nsset):
		"""
	Get all data about nsset from database needed for technical checks.
		"""
		cur = conn.cursor()
		# get nsset data (id, history id and checklevel)
		self.__dbGetNssets(cur, handle = nsset)
		if cur.rowcount == 0:
			raise ccReg.TechCheck.NssetNotFound()
		objid, histid, handle, level = cur.fetchone()
		cur.close()
		# get nameservers (fqdns and ip addresses) of hosts belonging to nsset
		nameservers = self.__dbGetHosts(conn, objid)
		return objid, histid, nameservers, level

	def __dbArchiveCheck(self, conn, histid, fqdns, status, results, reason):
		"""
	Archive result of technical test on domain in database.
		"""
		# convert IDL code of check-reason to database code
		if reason == ccReg.CHKR_EPP:
			reason_enum	= 1
		elif reason == ccReg.CHKR_MANUAL:
			reason_enum	= 2
		elif reason == ccReg.CHKR_REGULAR:
			reason_enum	= 3
		else:
			reason_enum	= 0 # code of unknown reason
		cur = conn.cursor()

		# get next ID of archive record from database
		cur.execute("SELECT nextval('check_nsset_id_seq')")
		archid = cur.fetchone()[0]
		# insert main archive record
		cur.execute("INSERT INTO check_nsset (id, nsset_hid, reason, "
					"overallstatus, extra_fqdns) "
				"VALUES (%d, %d, %d, %d, %s)" %
				(archid, histid, reason_enum, status, convArray(fqdns)))
				# in SQL command above we benefit from equal string
				# representation of python's list and postgresql's array
		# archive results of individual tests
		for resid in results:
			result = results[resid]
			# escape note and data strings if there are any
			if result["note"]:
				raw_note = pgdb._quote(result["note"])
			else:
				raw_note = "NULL"
			if result["data"]:
				raw_data = pgdb._quote(result["data"])
			else:
				raw_data = "NULL"
			cur.execute("INSERT INTO check_result (checkid, testid, status, "
						"note, data) "
					"VALUES (%d, %d, %d, %s, %s)" %
					(archid, resid, result["result"], raw_note, raw_data))
		cur.close()

	def __dbGetRegistrar(self, conn, reghandle):
		"""
	Get numeric ID of registrar.
		"""
		cur = conn.cursor()
		cur.execute("SELECT id FROM registrar WHERE handle = %s" %
				pgdb._quote(reghandle))
		if cur.rowcount == 0:
			raise ccReg.TechCheck.RegistrarNotFound()
		regid = cur.fetchone()[0]
		cur.close()
		return regid

	def __dbQueuePollMsg(self, conn, regid, xml_message):
		"""
	Insert poll message in database.
		"""
		cur = conn.cursor()
		cur.execute("INSERT INTO message (clid, exdate, message) "
				"VALUES (%d, now() + interval '%d days', %s)" %
				(regid, self.exMsg, pgdb._quote(xml_message)))
		cur.close()

	def __runTests(self, id, testsuite, fqdns, nslist, level):
		"""
	Run all enabled tests bellow given level.
		"""
		# fool the system if testmode is turned on
		if self.testmode:
			level = 0
		results = {}
		overallstatus = 0 # by default we assume that all tests were passed
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
				# (unknown status is considered as if the test failed)
				if results[req]["result"] != 0:
					self.l.log(self.l.DEBUG, "<%d> Omitting test '%s' becauseof "
							"not fulfilled prerequisity." % (id, test["name"]))
					req_ok = False
					break
			if not req_ok:
				# prerequisities were not satisfied
				continue
			#
			# command scheduled for execution has following format:
			#    /scriptdir/script nsFqdn,ipaddr1,ipaddr2,...
			# last part is repeated as many times as many there are nameservers.
			# If test requires a domain name(s) they are supplied on stdin.
			#
			cmd = "%s%s" % (self.scriptdir, test["script"])
			for ns in nslist:
				addrs = nslist[ns]
				cmd += " %s" % ns
				for addr in addrs:
					cmd += ",%s" % addr
			# run the command
			child = popen2.Popen3(cmd)
			# log some debug info
			self.l.log(self.l.DEBUG, "<%d> Running test %s, command '%s', "
					"pid %d." % (id, test["name"], cmd, child.pid))
			# decide if list of domains is needed
			if test["need_domain"]:
				# send space separated list of domain fqdns to stdin
				for fqdn in fqdns:
					child.tochild.write(fqdn + ' ')
				child.tochild.close()
			# before reading the output wait for child to terminate
			stat = os.WEXITSTATUS(child.wait())
			# read both standard outputs (stdout, stderr)
			# the length of strings is limited by available space in database
			if child.fromchild:
				data = child.fromchild.read(300)
			else:
				data = ''
			if child.childerr:
				note = child.childerr.read(300)
			else:
				note = ''
			# Status values:
			#     0 ... test OK
			#     1 ... test failed
			#     2 ... unknown result
			if stat == 1 and overallstatus != 1:
				overallstatus = 1
			elif stat == 2 and overallstatus == 0:
				overallstatus = 2
			# save the result
			results[testid] = { "result" : stat, "note" : note, "data" : data }
		return overallstatus, results

	def __createPollMsg(self, nsset, fqdn, testsuite, results):
		"""
	Save results of technical check in poll message.
		"""
		xml_message = """<nsset:testData xmlns:nsset="http://www.nic.cz/xml/epp/nsset-1.1" xsi:schemaLocation="http://www.nic.cz/xml/epp/nsset-1.1 nsset-1.1.xsd"><nsset:id>%s</nsset:id><nsset:name>%s</nsset:name>""" % (nsset, fqdn)
		for testid in results:
			test = testsuite[testid]
			result = results[testid]
			xml_message += ("""<nsset:result><nsset:name>%s</nsset:name><nsset:status>%s</nsset:status></nsset:result>""" %
					(test["name"], result["result"] == 0))
		xml_message += ("</nsset:testData>")
		return xml_message

	def __transfmResult(self, testsuite, status, results):
		"""
	Transform results to IDL result structure.
		"""
		idl_results = []
		for testid in results:
			test = testsuite[testid]
			result = results[testid]
			idl_results.append(ccReg.OneCheckResult(test["name"],
				result["result"], result["note"], result["data"], test["level"]))
		return ccReg.CheckResult(status, idl_results)

	def __checkNsset(self, nsset, level, dig, archive, reason, fqdns, asynch,
			reghandle):
		"""
	Run tests for a nsset. Flag asynch decides whether the mode of operation
	is asynchronous or synchronous.
		"""
		try:
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> Request for technical test of nsset "
					"'%s' received (asynchronous=%s)." % (id, nsset, asynch))
			# connect to database
			conn = self.db.getConn()

			# get all nsset data (including nameservers)
			objid, histid, nslist, dblevel = self.__dbGetNssetData(conn, nsset)
			# override level if it is not zero
			if level == 0: level = dblevel
			# dig associated domain fqdns if told to do so
			if dig:
				# get all fqdns of domains associated with nsset and join
				# them with provided fqdns
				all_fqdns = fqdns + self.__dbGetAssocDomains(conn, objid)
			else:
				all_fqdns = fqdns
			self.l.log(self.l.DEBUG, "<%d> List of first 5 domain fqdns "
					"from total %d: %s" % (id, len(all_fqdns), all_fqdns[0:5]))
			# build test suite based on values in database
			testsuite = self.__dbBuildTestSuite(conn)
			# perform tests on the nsset
			if asynch:
				regid = self.__dbGetRegistrar(conn, reghandle)
				# tests will be done in a new process
				pid = os.fork()
				if pid != 0:
					self.db.releaseConn(conn)
					return
				# we have to reopen db connection in child
				conn = self.db.getConn()
				status, results = self.__runTests(id, testsuite, all_fqdns,
						nslist, level)
				# XXX temporary hack until EPP interface will be changed
				if not all_fqdns: fqdn = ''
				else: fqdn = all_fqdns[0]
				pollmsg = self.__createPollMsg(nsset, fqdn, testsuite,
						results)
				self.__dbQueuePollMsg(conn, regid, pollmsg)
				# archive results of check if told to do so
				if archive:
					self.__dbArchiveCheck(conn, histid, fqdns, status,
							results, reason)
				# commit changes in archive and message queue
				conn.commit()
				self.db.releaseConn(conn)
				sys.exit()

			# if we are here it means that we do synchronous test
			status, results = self.__runTests(id, testsuite, all_fqdns,
					nslist, level)
			# archive results of check if told to do so
			if archive:
				self.__dbArchiveCheck(conn, histid, fqdns, status, results,
						reason)
				# commit changes in archive
				conn.commit()

			self.db.releaseConn(conn)
			return self.__transfmResult(testsuite, status, results)

		except ccReg.TechCheck.NssetNotFound, e:
			self.l.log(self.l.ERR, "<%d> Nsset '%s' does not exist." %
					(id, nsset))
			raise
		except ccReg.TechCheck.RegistrarNotFound, e:
			self.l.log(self.l.ERR, "<%d> Registrar '%s' does not exist." %
					(id, reghandle))
			raise
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
			raise ccReg.TechCheck.InternalError("Database error")
		except SystemExit, e:
			self.l.log(self.l.DEBUG, "<%d> TechCheck child exited." % id)
			return
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception caught: %s:%s" %
					(id, sys.exc_info()[0], e))
			raise ccReg.TechCheck.InternalError("Unexpected error")

	def checkNsset(self, nsset, level, dig, archive, reason, fqdns):
		"""
	Method from IDL interface. Run synchronously tests for a nsset.
		"""
		return self.__checkNsset(nsset, level, dig, archive, reason, fqdns,
				False, None)

	def checkNssetAsynch(self, regid, nsset, level, dig, archive, reason, fqdns):
		"""
	Method from IDL interface. Run asynchronously tests for a nsset.
		"""
		self.__checkNsset(nsset, level, dig, archive, reason, fqdns, True, regid)

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
			# get all registered nssets (just basic info)
			cursor = conn.cursor()
			self.__dbGetNssets(cursor)
			self.l.log(self.l.DEBUG, "<%d> Number of nssets to be checked: %d." %
					(id, cursor.rowcount))
			# iterate through all selected nssets and test one-by-one
			row = cursor.fetchone()
			while row:
				(objid, hid, handle, level) = row
				# XXX here is a bug - there might not be any nameservers
				# because the nsset might be deleted in meanwhile
				nameservers = self.__dbGetHosts(conn, objid)
				fqdns = self.__dbGetAssocDomains(conn, objid)
				status, results = self.__runTests(id, testsuite, fqdns,
						nameservers, level)
				# archive results of tests
				self.__dbArchiveCheck(conn, hid, [], status, results,
						ccReg.CHKR_REGULAR)
				row = cursor.fetchone()
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

