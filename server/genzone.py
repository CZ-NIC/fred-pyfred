#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of server-side of zone generator.
"""

import sys, time, random, ConfigParser
import pgdb
import ccReg, ccReg__POA
from pyfred_util import ipaddrs2list

def createNs(zonename, nsFqdn, addrs):
	"""
Create structure defined in idl for holding nameserver record. However it
is not so easy.  If nameserver's fqdn has suffix zonename preceeded be a
dot, then list of addresses should not be empty.  If zonename preceeded be
a dot is not a suffix of nameserver's fqdn, then the list of addresses
should be empty, if not, the structure is still created but with empty list
of addresses. If either of the two conditions is violated then message is
written to syslog.
	"""
	warning = None
	if nsFqdn.endswith("." + zonename):
		if not addrs:
			warning = "Missing GLUE for nameserver '%s' from zone '%s'." % \
					(nsFqdn, zonename)
		return ccReg.DNSHost_str(nsFqdn, addrs), warning
	else:
		# we don't emit warning for GLUE which is not needed, since nsset
		# can be shared across various zones.
		return ccReg.DNSHost_str(nsFqdn, []), warning

class ZoneGenerator_i (ccReg__POA.ZoneGenerator):
	"""
This class implements interface used for generation of a zone file.
	"""

	def __init__(self, logger, db, conf, joblist, rootpoa):
		"""
	Initializer saves db object (which is later used for opening database
	connection) and logger (used for logging). Transfer sequencer is
	initialized to 0 and dict of transfers is initialized to empty dict.
		"""
		# ccReg__POA.ZoneGenerator doesn't have constructor
		self.db = db  # db object
		self.l = logger # syslog functionality
		self.rootpoa = rootpoa # root poa for new servants
		self.zone_objects = [] # list of current transfers

		self.safeperiod = 31
		self.exhour = 14
		self.idletreshold = 3600
		self.checkperiod = 60
		# Parse genzone-specific configuration
		if conf.has_section("Genzone"):
			# safe period
			try:
				safeperiod = conf.get("Genzone", "safeperiod")
				if safeperiod:
					self.l.log(self.l.DEBUG, "safeperiod is set to '%s'." %
							safeperiod)
					try:
						self.safeperiod = int(safeperiod)
					except ValueError, e:
						self.l.log(self.l.ERR, "Number required for safeperiod"
								" configuration directive.")
						raise
			except ConfigParser.NoOptionError, e:
				pass
			# expiration hour
			try:
				exhour = conf.get("Genzone", "expiration_hour")
				if exhour:
					self.l.log(self.l.DEBUG, "expiration_hour is set to '%s'." %
							exhour)
					try:
						self.exhour = int(exhour)
					except ValueError, e:
						self.l.log(self.l.ERR, "Number required for exhour"
								" configuration directive.")
						raise
			except ConfigParser.NoOptionError, e:
				pass
			# idle treshold
			try:
				idletreshold = conf.get("Genzone", "idletreshold")
				if idletreshold:
					self.l.log(self.l.DEBUG, "idletreshold is set to '%s'." %
							idletreshold)
					try:
						self.idletreshold = int(idletreshold)
					except ValueError, e:
						self.l.log(self.l.ERR, "Number required for idletreshold"
								" configuration directive.")
						raise
			except ConfigParser.NoOptionError, e:
				pass
			# check period
			try:
				checkperiod = conf.get("Genzone", "checkperiod")
				if checkperiod:
					self.l.log(self.l.DEBUG, "checkperiod is set to '%s'." %
							checkperiod)
					try:
						self.checkperiod = int(checkperiod)
					except ValueError, e:
						self.l.log(self.l.ERR, "Number required for checkperiod "
								"configuration directive.")
						raise
			except ConfigParser.NoOptionError, e:
				pass
		# correction of exhour, we have to use UTC time (time of database)
		self.exhour += time.gmtime()[3] - time.localtime()[3]
		self.l.log(self.l.DEBUG, "expiration_hour after timezone correction is "
				"%d." % self.exhour)

		# schedule regular cleanup
		joblist.append( { "callback":self.__genzone_cleaner, "context":None,
			"period":self.checkperiod, "ticks":1 } )
		self.l.log(self.l.INFO, "Object initialized")

	def __genzone_cleaner(self, ctx):
		"""
	Method deletes closed or idle zonedata objects.
		"""
		self.l.log(self.l.DEBUG, "Regular maintance procedure.")
		remove = []
		for item in self.zone_objects:
			# test idleness of object
			if time.time() - item.lastuse > self.idletreshold:
				item.status = item.IDLE

			# schedule objects to be deleted
			if item.status == item.CLOSED:
				self.l.log(self.l.DEBUG, "Closed zone-object with id %d "
						"destroyed." % item.id)
				remove.append(item)
			elif item.status == item.IDLE:
				self.l.log(self.l.DEBUG, "Idle zone-object with id %d "
						"destroyed." % item.id)
				remove.append(item)
		# delete objects scheduled for deletion
		for item in remove:
			id = self.rootpoa.servant_to_id(item)
			self.rootpoa.deactivate_object(id)
			self.zone_objects.remove(item)

	def __dbGetStaticData(self, conn, zonename, id):
		"""
	Method returns so-called static data for a zone (don't change often).
		"""
		cur = conn.cursor()
		# following data are called static since they are not expected to
		# change very often. Though they are stored in database and must
		# be sent back together with dynamic data
		cur.execute("SELECT z.id, zs.ttl, zs.hostmaster, zs.serial, zs.refresh, "
				"zs.update_retr, zs.expiry, zs.minimum, zs.ns_fqdn "
				"FROM zone z, zone_soa zs WHERE zs.zone = z.id AND z.fqdn = %s" %
				pgdb._quote(zonename))
		if cur.rowcount == 0:
			cur.close()
			self.l.log(self.l.ERR, "<%d> Zone '%s' does not exist or does not "
					"have associated SOA record." % (id, zonename))
			raise ccReg.ZoneGenerator.UnknownZone()
		(zoneid, ttl, hostmaster, serial, refresh, update_retr, expiry, minimum,
				ns_fqdn) = cur.fetchone()
		# create a list of nameservers for the zone
		cur.execute("SELECT fqdn, addrs FROM zone_ns WHERE zone = %d" % zoneid)
		nameservers = []
		for i in range(cur.rowcount):
			row = cur.fetchone()
			nsFqdn = row[0]
			nsAddrs = ipaddrs2list(row[1])
			ns, wmsg = createNs(zonename, nsFqdn, nsAddrs)
			if wmsg:
				self.l.log(self.l.WARNING, "<%d> %s" % (id, wmsg))
			nameservers.append(ns)
		cur.close()

		# if the serial is not given we will construct it on the fly
		if not serial:
			# default is unix timestamp
			serial = int(time.time()).__str__()
		else:
			serial = serial.__str__()

		return (ttl, hostmaster, serial, refresh, update_retr, expiry, minimum,
				ns_fqdn, nameservers)

	def __dbGetDynamicData(self, conn, zonename):
		"""
	Method returns so-called dynamic data for a zone (are fluctuant).
		"""
		cur = conn.cursor()
		# get id of zone and its type
		cur.execute("SELECT id, enum_zone FROM zone WHERE fqdn = %s" %
				pgdb._quote(zonename))
		if cur.rowcount == 0:
			cur.close()
			raise ccReg.ZoneGenerator.UnknownZone()
		zoneid, isenum = cur.fetchone()

		# get all domains from the zone into temporary table
		#    domain must have nsset, must not be expired,
		#    and for enum domains, the validation must not be expired
		if isenum:
			# mark all active enum domains by status flag
			cur.execute("SELECT o.name, d.nsset, o.id, o.historyid, "
				"CASE "
					"WHEN d.nsset IS NULL then '3' "
					"WHEN date_trunc('day', d.exdate) + interval '%d days' + "
						"interval '%d hour' < now() then '4' "
					"WHEN date_trunc('day', e.exdate) + interval '%d hour' < "
						"now() then '5' "
					"ELSE '1' "
				"END AS new_status INTO TEMP TABLE domain_stat_tmp "
				"FROM object_registry o, domain d, enumval e "
				"WHERE o.id = d.id AND e.domainid = d.id AND d.zone = %d" %
				(self.safeperiod, self.exhour, self.exhour, zoneid))
		else:
			# mark all active classic domains by status flag
			cur.execute("SELECT o.name, d.nsset, o.id, o.historyid, "
				"CASE "
					"WHEN d.nsset IS NULL then '3' "
					"WHEN date_trunc('day', d.exdate) + interval '%d days' + "
						"interval '%d hour' < now() then '4' "
					"ELSE '1' "
				"END AS new_status INTO TEMP TABLE domain_stat_tmp "
				"FROM object_registry o, domain d "
				"WHERE o.id = d.id AND d.zone = %d" %
				(self.safeperiod, self.exhour, zoneid))

		# select all domains which changed the status or are new
		cur.execute("SELECT ds.id AS oid, ds.historyid AS ohid, "
			"CAST(ds.new_status AS INTEGER), zh.id AS zhid INTO TEMP TABLE "
			"domain_stat_chg_tmp FROM domain_stat_tmp ds LEFT JOIN "
			"genzone_domain_history zh ON (ds.id=zh.domain_id AND zh.last=true) "
			"WHERE ds.new_status!=zh.status OR zh.status IS NULL")

		# append all domains which don't exist anymore
		cur.execute("INSERT INTO domain_stat_chg_tmp SELECT zh.domain_id, "
			"zh.domain_hid, 2, zh.id FROM genzone_domain_history zh "
			"LEFT JOIN domain_stat_tmp ds ON (zh.domain_id=ds.id) "
			"WHERE zh.zone_id=%d AND "
				"zh.status!=2 AND zh.last=true AND ds.id IS NULL" % zoneid)

		# change last flag for domains which are in changeset
		cur.execute("UPDATE genzone_domain_history SET last=false "
			"WHERE id IN (SELECT zhid FROM domain_stat_chg_tmp)")

		# finally update zone history
		cur.execute("INSERT INTO genzone_domain_history (domain_id, "
			"domain_hid, zone_id, status, inzone) SELECT oid, ohid, %d, "
			"new_status, new_status=1 FROM domain_stat_chg_tmp" % zoneid)

		# put together domains and their nameservers
		cur.execute("SELECT ds.name, host.fqdn, a.ipaddr "
				"FROM domain_stat_tmp ds, host LEFT JOIN host_ipaddr_map a "
				"ON (host.id = a.hostid) "
				"WHERE ds.nsset = host.nssetid AND ds.new_status=1 "
				"ORDER BY ds.name, host.fqdn")
		# destroy temporary table
		#  this would be done automatically upon connection closure, but
		#  since we use proxy managing pool of connections, we cannot be
		#  sure. Therefore we will rather explicitly drop the temporary
		#  table.
		#                       III not done III
		# return cursor for later processing
		return cur

	def getSOA(self, zonename):
		"""
	Method sends back data needed for SOA record construction (ttl, hostmaster,
	serial, refresh, update_retr, expiry, minimum, primary nameserver,
	secondary nameservers).
		"""
		try:
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> get-SOA request of the zone '%s' "
					"received." % (id, zonename))
			# connect to database
			conn = self.db.getConn()

			(soa_ttl, soa_hostmaster, soa_serial, soa_refresh,
					soa_update_retr, soa_expiry, soa_minimum, soa_ns_fqdn,
					nameservers) = self.__dbGetStaticData(conn, zonename, id)

			self.db.releaseConn(conn)

			# well done
			return (zonename,
				soa_ttl,
				soa_hostmaster,
				soa_serial,
				soa_refresh,
				soa_update_retr,
				soa_expiry,
				soa_minimum,
				soa_ns_fqdn,# soa nameserver
				nameservers) # zone nameservers

		except ccReg.ZoneGenerator.InternalError, e:
			raise
		except ccReg.ZoneGenerator.UnknownZone, e:
			self.l.log(self.l.ERR, "<%d> Zone '%s' does not exist." %
					(id, zonename))
			raise
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e));
			raise ccReg.ZoneGenerator.InternalError("Database error");
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception caught: %s:%s" %
					(id, sys.exc_info()[0], e))
			raise ccReg.ZoneGenerator.InternalError("Unexpected error")

	def generateZone(self, zonename):
		"""
	Method sends back static data (ttl, hostmaster, serial, refresh,
	update_retr, expiry, minimum, primary nameserver, secondary nameservers).
	Dynamic data (domains and their nameservers) are left to be processed later
	by smaller peaces.
		"""
		try:
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> Generation of the zone '%s' requested."
					% (id, zonename))
			# connect to database
			conn = self.db.getConn()

			# now comes the hard part, getting dynamic data (lot of data ;)
			cursor = self.__dbGetDynamicData(conn, zonename)
			conn.commit()
			self.l.log(self.l.DEBUG, "<%d> Number of records in cursor: %d." %
					(id, cursor.rowcount))
			self.db.releaseConn(conn)

			# Create an instance of ZoneData_i and an ZoneData object ref
			zone_obj = ZoneData_i(id, zonename, cursor, self.l)
			self.zone_objects.append(zone_obj)
			zone_ref = self.rootpoa.servant_to_reference(zone_obj)

			# well done
			return zone_ref # Reference to ZoneData object

		except ccReg.ZoneGenerator.InternalError, e:
			raise
		except ccReg.ZoneGenerator.UnknownZone, e:
			self.l.log(self.l.ERR, "<%d> Zone '%s' does not exist." %
					(id, zonename))
			raise
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e));
			raise ccReg.ZoneGenerator.InternalError("Database error");
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception caught: %s:%s" %
					(id, sys.exc_info()[0], e))
			raise ccReg.ZoneGenerator.InternalError("Unexpected error")


class ZoneData_i (ccReg__POA.ZoneData):
	"""
Class encapsulating zone data.
	"""

	# statuses of zone object
	ACTIVE = 1
	CLOSED = 2
	IDLE = 3

	def __init__(self, id, zonename, cursor, log):
		"""
	Initializes zonedata object.
		"""
		self.l = log
		self.id = id
		self.zonename = zonename
		self.cursor = cursor
		self.status = self.ACTIVE
		self.crdate = time.time()
		self.lastuse = self.crdate
		self.lastrow = cursor.fetchone()

	def __get_one_domain(self):
		"""
	This function gets on input rows with columns (domain, host name, host
	address) sorted in this order. The task is to return one domain, list
	of its nameservers and list of ip addresses of its nameservers of
	the domain.
		"""
		if not self.lastrow:
			return None, None, None
		prev = self.lastrow
		curr = self.cursor.fetchone()
		domain = prev[0]
		nameservers = [ prev[1] ]
		ipaddrs = {}
		if prev[2]:
			ipaddrs[prev[1]] = [ prev[2] ]
		else:
			ipaddrs[prev[1]] = []

		# process all rows with the same domain name
		while curr and domain == curr[0]: # while the domain names are same
			if curr[1] not in nameservers:
				nameservers.append(curr[1])
				if curr[2]:
					ipaddrs[ curr[1] ] = [ curr[2] ]
				else:
					ipaddrs[ curr[1] ] = []
			else:
				if curr[2] and curr[2] not in ipaddrs[ curr[1] ]:
					ipaddrs[ curr[1] ].append(curr[2])
			curr = self.cursor.fetchone() # move to next row

		# save leftover
		self.lastrow = curr
		return domain, nameservers, ipaddrs

	def getNext(self, count):
		"""
	Method sends back dynamic data associated with particular zone transfer.
	Dynamic data are a list of domain names and their nameservers. Number of
	domains which will be sent is given by count parameter. If end of data is
	encountered, empty list is returned.
		"""
		try:
			self.l.log(self.l.INFO, "<%d> Get zone data request received." %
					self.id)

			# check count
			if count < 1:
				self.l.log(self.l.WARNING, "Invalid count of domains requested "
						"(%d). Default value (1) is used." % count)
				count = 1

			# check status
			if self.status != self.ACTIVE:
				self.l.log(self.l.WARNING, "<%d> Search object is not active "
						"anymore." % self.id)
				raise ccReg.ZoneData.NotActive()

			# update last use timestamp
			self.lastuse = time.time()

			# transform data from db cursor into a structure which will be sent
			# back to client. These data are called dynamic since they keep
			# changing
			dyndata = []
			for i in range(count):
				domain, nameservers, ipaddrs = self.__get_one_domain()
				if not domain: # test end of data
					break

				# transform result in corba structures
				corba_nameservers = []
				for ns in nameservers:
					corba_ns, wmsg = createNs(self.zonename, ns, ipaddrs[ns])
					if wmsg:
						self.l.log(self.l.WARNING, "<%d> %s" % (self.id, wmsg))
					corba_nameservers.append(corba_ns)
				dyndata.append( ccReg.ZoneItem(domain, corba_nameservers) )

			self.l.log(self.l.DEBUG, "<%d> Number of records returned: %d." %
					(self.id, len(dyndata)) )
			return dyndata

		except ccReg.ZoneData.NotActive, e:
			raise
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception caught: %s:%s" %
					(self.id, sys.exc_info()[0], e))
			raise ccReg.ZoneData.InternalError("Unexpected error")

	def destroy(self):
		"""
	Mark zonedata object as ready to be destroyed.
		"""
		try:
			if self.status != self.ACTIVE:
				self.l.log(self.l.WARNING, "<%d> An attempt to close non-active "
						"zonedata object." % self.id)
				return

			self.status = self.CLOSED
			self.cursor.close()
			self.l.log(self.l.INFO, "<%d> Zone transfer closed." % self.id)
			# close db cursor
			self.cursor.close()
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
					(self.id, sys.exc_info()[0], e))
			raise ccReg.MailSearch.InternalError("Unexpected error")


def init(logger, db, nsref, conf, joblist, rootpoa):
	"""
Function which creates, initializes and returns object ZoneGenerator.
	"""
	# Create an instance of ZoneGenerator_i and an ZoneGenerator object ref
	servant = ZoneGenerator_i(logger, db, conf, joblist, rootpoa)
	return servant, "ZoneGenerator"
