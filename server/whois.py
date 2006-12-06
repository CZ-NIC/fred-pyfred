#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of whois server.
"""

import ccReg, ccReg__POA
import pgdb
from pyfred_util import strtime, isExpired, classify, domainClass

class Whois_i (ccReg__POA.Whois):
	"""
This class implements whois interface.
	"""
	def __init__(self, logger, db):
		"""
	Initializer saves db_pars (which is later used for opening database
	connection) and logger (used for logging).
		"""
		# ccReg__POA.Whois doesn't have constructor
		self.db = db # db connection string
		self.l = logger # syslog functionality
		self.l.log(self.l.DEBUG, "Object initialized")

	def getDomain(self, domain_name):
		"""
	Method returns information about domain used in whois response and
	a date the response was generated. Information about domain consists
	of status, creation & expiration date, registrar's name and URL,
	nameservers and technical contacts.
		"""
		self.l.log(self.l.DEBUG, "Whois request for domain '%s' recieved." %
				domain_name)
		# classify domain name
		cl = classify(domain_name)
		if cl == domainClass.INVALID:
			self.l.log(self.l.DEBUG, "Domain '%s' is INVALID." % domain_name)
			raise ccReg.Whois.DomainError(strtime(), ccReg.WE_INVALID)
		elif cl == domainClass.LONG:
			self.l.log(self.l.DEBUG, "Domain '%s' is LONG." % domain_name)
			raise ccReg.Whois.DomainError(strtime(), ccReg.WE_DOMAIN_LONG)
		elif cl == domainClass.BAD_ZONE:
			self.l.log(self.l.DEBUG, "Domain '%s' is BAD ZONE." % domain_name)
			raise ccReg.Whois.DomainError(strtime(), ccReg.WE_DOMAIN_BAD_ZONE)
		# domain is ENUM or CLASSIC
		conn = None
		cur = None
		try:
			# connect to database
			conn = self.db.getConn()
			cur = conn.cursor()
			if cl == domainClass.CLASSIC:
				# Get information about classic domain
				cur.execute("SELECT fqdn, nsset, clid, "
						"extract(epoch from crdate), "
						"extract(epoch from exdate) FROM domain "
						"WHERE fqdn = %s" % pgdb._quote(domain_name))
			else:
				# Get information about enum domain
				cur.execute("SELECT fqdn, nsset, clid, "
						"extract(epoch from crdate), "
						"extract(epoch from exdate) FROM domain WHERE "
						"(%s LIKE '%%'||fqdn) OR (fqdn LIKE '%%'||%s)" %
						(pgdb._quote(domain_name), pgdb._quote(domain_name)))
			if cur.rowcount == 0:
				cur.close()
				self.db.releaseConn(conn)
				self.l.log(self.l.DEBUG, "Domain '%s' is FREE." % domain_name)
				raise ccReg.Whois.DomainError(strtime(), ccReg.WE_NOTFOUND)
			# rename domain data
			(fqdn, nssetid, regid, crtimestamp, extimestamp) = cur.fetchone()
			# get nameservers and technical contacts
			nameservers  = []
			techcontacts = []
			if nssetid != None:
				# Get associated nameservers if there are any
				cur.execute("SELECT fqdn FROM host WHERE nssetid = %d" % nssetid)
				if cur.rowcount == 0:
					self.l.log(self.l.ERR, "Nsset with id '%d' for domain '%s' "
							"is empty! We will pretend there are no nameservers."
							% (nssetid, domain_name))
				else:
					# "detuplize" the list of nameservers
					nameservers = [ ns[0] for ns in cur.fetchall() ]
					# Get associated technical contacts if there are any
					cur.execute("SELECT contactid FROM nsset_contact_map WHERE "
							"nssetid = %d" % nssetid)
				for tech_tuple in cur.fetchall():
					cur.execute("SELECT handle FROM contact WHERE id = %d" %
							tech_tuple[0])
					if cur.rowcount == 0:
						self.l.log(self.l.ERR, "Technical contact with id %d "
								"for nsset with id %d does not exist!" %
								(tech_tuple[0], nssetid))
					else:
						techcontacts.append(cur.fetchone()[0])
			# get registrar name and URL
			cur.execute("SELECT name, url FROM registrar WHERE id = %d" %
					regid)
			if cur.rowcount == 0:
				cur.close()
				self.db.releaseConn(conn)
				self.l.log(self.l.ERR, "Registrar with id %d for domain "
						"'%s' does not exist!" % (regid, domain_name))
				raise ccReg.Whois.WhoisError("Registrar for domain not found")
			reg_name, reg_url = cur.fetchone()
			if reg_name == None: reg_name = "unknown"
			if reg_url == None: reg_url = "unknown"
			cur.close()
			self.db.releaseConn(conn)
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "Database error: %s\n" % e);
			if cur: cur.close()
			if conn: self.db.releaseConn(conn)
			raise ccReg.Whois.WhoisError("Database error");
		# transform creation date
		crdate = strtime(crtimestamp)
		# transform expiration date
		exdate = strtime(extimestamp)
		# check if domain has expired
		if isExpired(extimestamp):
			status = ccReg.WHOIS_EXPIRED
		else:
			status = ccReg.WHOIS_ACTIVE
		# return data
		return ccReg.DomainWhois(fqdn, (cl == domainClass.ENUM), status, crdate, exdate, reg_name, reg_url,
				nameservers, techcontacts), strtime()

def init(logger, db, nsref, conf, joblist, rootpoa):
	"""
Function which creates, initializes and returns servant Whois.
	"""
	# Create an instance of Whois_i and an Whois object ref
	servant = Whois_i(logger, db)
	return servant, "PyWhois"

