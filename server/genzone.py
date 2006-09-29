#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of server-side of zone generator.
"""

import time
import ccReg, ccReg__POA
import pgdb
from ccreg_util import ipaddrs2list

class ZoneGenerator_i (ccReg__POA.ZoneGenerator):
	"""
This class implements interface used for generation of zone file.
	"""
	MAX_TRANSFERS = 10 # maximum number of concurrent transfers

	def __init__(self, db_pars, logger):
		"""
	Initializer saves db_pars (which is later used for opening database
	connection) and logger (used for logging). Transfer sequencer is
	initialized to 0 and dict of transfers is initialized to empty dict.
		"""
		# ccReg__POA.ZoneGenerator doesn't have constructor
		self.db_pars = db_pars # db connection string
		self.l = logger # syslog functionality
		self.l.log(self.l.DEBUG, "Object initialized")
		self.seq = 0 # transfer sequencer
		self.transfers = {} # dictionary of transfers

	def _createNs(self, zonename, nsFqdn, addrs):
		"""
	Create structure defined in idl for holding nameserver record. However it
	is not so easy.  If nameserver's fqdn has suffix zonename preceeded be a
	dot, then list of addresses should not be empty.  If zonename preceeded be
	a dot is not a suffix of nameserver's fqdn, then the list of addresses
	should be empty, if not, the structure is still created but with empty list
	of addresses. If either of the two conditions is violated then message is
	written to syslog.
		"""
		if nsFqdn.endswith("." + zonename):
			if not addrs:
				# high log level is set because it generates huge amount
				# of messages
				self.l.log(self.l.DEBUG, "Missing GLUE for nameserver '%s' "
						"from zone '%s'" % (nsFqdn, zonename))
			return ccReg.DNSHost_str(nsFqdn, addrs)
		else:
			if addrs:
				# high log level is set because it generates huge amount
				# of messages
				self.l.log(self.l.DEBUG, "Ignoring GLUE for nameserver '%s' "
						"from zone '%s'" % (nsFqdn, zonename))
			return ccReg.DNSHost_str(nsFqdn, [])

	def transferRequest(self, zonename):
		"""
	Method sends back static data (ttl, hostmaster, serial, refresh,
	update_retr, expiry, minimum, primary nameserver, secondary nameservers).
	Dynamic data (domains and their nameservers) are left to be processed later
	by smaller peaces.
		"""
		self.l.log(self.l.INFO, "Generation of a zone '%s' requested." %
				zonename)
		self.seq += 1
		cur_seq = self.seq
		# check maximum limit for transfer count
		if len(self.transfers) > self.MAX_TRANSFERS:
			self.l.log(self.l.ERR, "Maximum transfer limit exceeded (%d > %d). "
					"Restart the server to clear transfers." %
					(len(self.transfers), self.MAX_TRANSFERS) )
		conn = None
		cur = None
		try:
			# connect to database
			conn = pgdb.connect(
					host = self.db_pars["host"],
					database = self.db_pars["dbname"],
					user = self.db_pars["user"],
					password = self.db_pars["passwd"])
			cur = conn.cursor()
			# Select id and enum status of the zone
			cur.execute("SELECT id, enum_zone FROM zone WHERE fqdn = %s" %
					pgdb._quote(zonename))
			if cur.rowcount == 0:
				cur.close()
				conn.close()
				self.l.log(self.l.ERR, "Zone '%s' not found in db." % zonename)
				raise ccReg.ZoneGenerator.ZoneGeneratorError("Unknown zone "
						"name")
			row = cur.fetchone()
			zoneid = row[0]
			isenum = row[1]
			# following data are called static since they are not expected to
			# change very often. Though they are stored in database and must
			# be sent back together with dynamic data
			cur.execute("SELECT ttl, hostmaster, serial, refresh, update_retr, "
					"expiry, minimum, ns_fqdn FROM zone_soa "
					"WHERE zone = %d" % zoneid)
			if cur.rowcount == 0:
				cur.close()
				conn.close()
				self.l.log(self.l.CRIT, "Zone '%s' does not have SOA record "
						"in db" % zonename)
				raise ccReg.ZoneGenerator.ZoneGeneratorError("Zone does not "
						"have SOA record in database")
			(soa_ttl, soa_hostmaster, soa_serial, soa_refresh, soa_update_retr,
					soa_expiry, soa_minimum, soa_ns_fqdn) = cur.fetchone()
			# if the serial is not given we will construct it on the fly
			if soa_serial == None:
				# default is unix timestamp
				soa_serial = int(time.time()).__str__()
			else: soa_serial = soa_serial.__str__()
			# create a list of secondary nameservers
			cur.execute("SELECT fqdn, addrs FROM zone_ns WHERE zone = %d" %
					zoneid)
			secnss = []
			for i in range(cur.rowcount):
				row = cur.fetchone()
				nsFqdn = row[0]
				nsAddrs = ipaddrs2list(row[1])
				ns = self._createNs(zonename, nsFqdn, nsAddrs)
				if ns:
					secnss.append(ns)
			# now comes the hard part, getting dynamic data (lot of data ;)
			# get all domains from the zone into temporary table
			#    domain must not be expired
			#    and for enum domains, the validation must not be expired
			if isenum:
				cur.execute("SELECT fqdn, nsset INTO TEMP TABLE domain_temp "
					"FROM domain, enumval WHERE zone = %d and domainid = id "
					"and domain.exdate > now() and enumval.exdate > now()" %
					zoneid)
			else:
				cur.execute("SELECT fqdn, nsset INTO TEMP TABLE domain_temp "
					"FROM domain WHERE zone = %d and exdate > now()" % zoneid)
			# put together domains and their nameservers
			cur.execute("SELECT domain_temp.fqdn, host.fqdn, host.ipaddr FROM "
					"domain_temp, host WHERE domain_temp.nsset = host.nssetid")
			# safe dynamic data for later processing (do not close cursor)
			row = cur.fetchone() # prefetch first record
			self.transfers[cur_seq] = [cur, row]
			# destroy temporary table
			#  this would be done automatically upon connection closure, but
			#  since we use proxy managing pool of connections, we cannot be
			#  sure. Therefore we will rather explicitly drop the temporary
			#  table.
			cur = conn.cursor()
			cur.execute("DROP TABLE domain_temp")
			cur.close()
			# well done
			self.l.log(self.l.DEBUG, "Number of records to process: %d" %
					cur.rowcount)
			conn.close()
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "Database error: %s\n" % e);
			if conn: conn.close()
			if cur: cur.close()
			raise ccReg.ZoneGenerator.ZoneGeneratorError("Database error");
		return (cur_seq, # id of transfer
			soa_ttl,
			soa_hostmaster,
			soa_serial,
			soa_refresh,
			soa_update_retr,
			soa_expiry,
			soa_minimum,
			soa_ns_fqdn,# prim. nameserver
			secnss) # secondary nameservers

	def getZoneData(self, transferid, count):
		"""
	Method sends back dynamic data associated with particular zone transfer
	by transferid. Dynamic data are a list of domain names and their
	nameservers. Number of domains which will be sent is given by count.
	If end of data is encountered, eof (second return value) is set to true
	and transfer is deleted from list of transfers.
		"""
		# retreive db cursor
		try:
			cur = self.transfers[transferid][0]
		except IndexError, e:
			self.l.log(self.l.ERR, "Unknown transfer id (%d)\n" % transferid);
			raise ccReg.ZoneGenerator.ZoneGeneratorError("Unknown transaction id")
		# check count
		if count < 1:
			self.l.log(self.l.ERR, "Invalid count of domains requested (%d)" %
					count)
			raise ccReg.ZoneGenerator.ZoneGeneratorError("Invalid count")
		# transform data from db cursor into structure which will be sent
		# back to client. Theese data are called dynamic since they keep
		# changing
		dyndata = []
		# retrieve leftover from last call
		row = self.transfers[transferid][1]
		if row == None: # test end of data
			return []
		lastdomain = row[0]
		ns = self._createNs(lastdomain, row[1], ipaddrs2list(row[2]))
		if ns:
			nameservers = [ns]
		else:
			nameservers = []
		# main loop
		for i in range(count):
			# loop for processing nameservers of one domain
			while True:
				row = cur.fetchone()
				if row == None: # check end of data
					break
				newdomain = row[0]
				nsFqdn = row[1]
				nsAddrs = ipaddrs2list(row[2])
				if lastdomain != newdomain:
					break # proceed to next domain
				# add nameservers to current domain
				ns = self._createNs(lastdomain, nsFqdn, nsAddrs)
				if ns:
					nameservers.append(ns)
			# insert domain processed in previous 'while' in a list
			if nameservers:
				dyndata.append( ccReg.ZoneItem(lastdomain, nameservers) )
			else:
				self.l.log(self.l.ERR, "Domain '%s' has no valid nameservers "
						"(this should never happen!)" % lastdomain)
			if row == None: # check end of data
				break
			# initialize next run of 'while' cycle
			lastdomain = newdomain
			ns = self._createNs(lastdomain, nsFqdn, nsAddrs)
			if ns:
				nameservers = [ns]
			else:
				nameservers = []
		# save not processed leftover
		self.transfers[transferid][1] = row
		self.l.log(self.l.DEBUG, "Returned %d domains (session %d)" %
				(len(dyndata), transferid))
		return dyndata

	def transferDelete(self, transferid):
		"""
	Delete transfer record in dict of transfers.
		"""
		self.l.log(self.l.INFO, "Transfer %d closed" % transferid)
		try:
			cur = self.transfers[transferid][0]
		except IndexError, e:
			self.l.log(self.l.ERR, "Unknown transfer id (%d)\n" % transferid);
			raise ccReg.ZoneGenerator.ZoneGeneratorError("Unknown "
					"transaction id")
		# close db cursor
		cur.close()
		del(self.transfers[transferid])


def init(dbconf, logger):
	"""
Function which creates, initializes and returns object ZoneGenerator.
	"""
	# Create an instance of ZoneGenerator_i and an ZoneGenerator object ref
	servant = ZoneGenerator_i(dbconf, logger)
	return servant, "ZoneGenerator"
