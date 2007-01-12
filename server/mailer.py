#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of mailer daemon.
"""

import os, sys, time, random, ConfigParser
import pgdb
from pyfred_util import isInfinite
# corba stuff
from omniORB import CORBA, PortableServer
import CosNaming
import ccReg, ccReg__POA
# template stuff
import neo_cgi # must be included before neo_cs and neo_util
import neo_cs, neo_util
# email stuff
import email.Charset
from email.MIMEMultipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email.Utils import formatdate, parseaddr
from email import quopriMIME
from email import Encoders


def qp_str(string):
	"""
Function checks if the string contains characters, which need to be "quoted
printable" and if there are any, it will encode the string. This function
is used for headers of email.
	"""
	need = False
	for c in string:
		if quopriMIME.header_quopri_check(c):
			need = True
	if need:
		string = quopriMIME.header_encode(string, charset="utf-8")
	return string

class Mailer_i (ccReg__POA.Mailer):
	"""
This class implements Mailer interface.
	"""
	def __init__(self, logger, db, nsref, conf, joblist, rootpoa):
		"""
	Initializer saves db_pars (which is later used for opening database
	connection) and logger (used for logging).
		"""
		# ccReg__POA.Mailer doesn't have constructor
		self.db = db # db object for accessing database
		self.l = logger # syslog functionality
		self.nsref = nsref # nameservice reference
		self.search_objects = [] # list of created search objects
		self.rootpoa = rootpoa # root poa for new servants

		# this avoids base64 encoding for utf-8 messages
		email.Charset.add_charset( 'utf-8', email.Charset.SHORTEST, None, None )

		# default configuration
		self.testmode = False
		self.tester = ""
		self.sendmail = "/usr/sbin/sendmail"
		self.fm_ns = "localhost"
		self.fm_object = "FileManager"
		self.idletreshold = 3600
		self.checkperiod = 60
		# Parse Mailer-specific configuration
		if conf.has_section("Mailer"):
			# testmode
			try:
				testmode = conf.get("Mailer", "testmode")
				if testmode:
					if testmode.upper() in ("YES", "ON", "1"):
						self.l.log(self.l.DEBUG, "Test mode is turned on.")
						self.testmode = True
			except ConfigParser.NoOptionError, e:
				pass
			# tester email address
			try:
				tester = conf.get("Mailer", "tester")
				if tester:
					self.l.log(self.l.DEBUG, "Tester's address is %s." % tester)
					self.tester = tester
			except ConfigParser.NoOptionError, e:
				pass
			# sendmail path
			try:
				sendmail = conf.get("Mailer", "sendmail")
				if sendmail:
					self.l.log(self.l.DEBUG, "Path to sendmail is %s."% sendmail)
					self.sendmail = sendmail
			except ConfigParser.NoOptionError, e:
				pass
			# filemanager object's name
			try:
				fm_object = conf.get("Mailer", "filemanager_object")
				if fm_object:
					self.l.log(self.l.DEBUG, "Name under which to look for "
							"filemanager is %s."% fm_object)
					self.fm_object = fm_object
			except ConfigParser.NoOptionError, e:
				pass
			# check period
			try:
				checkperiod = conf.get("Mailer", "checkperiod")
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
			# idle treshold
			try:
				idletreshold = conf.get("Mailer", "idletreshold")
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

		# check configuration consistency
		if (self.testmode and not self.tester) or (not self.testmode and self.tester):
			self.l.log(self.l.WARNING, "For proper operation testmode and "
					"tester must be set or both must be unset.")
		# schedule regular cleanup
		joblist.append( { "callback":self.__search_cleaner, "context":None,
			"period":self.checkperiod, "ticks":1 } )
		self.l.log(self.l.INFO, "Object initialized")

	def __search_cleaner(self, ctx):
		"""
	Method deletes closed or idle search objects.
		"""
		self.l.log(self.l.DEBUG, "Regular maintance procedure.")
		remove = []
		for item in self.search_objects:
			# test idleness of object
			if time.time() - item.lastuse > self.idletreshold:
				item.status = item.IDLE

			# schedule objects to be deleted
			if item.status == item.CLOSED:
				self.l.log(self.l.DEBUG, "Closed search-object with id %d "
						"destroyed." % item.id)
				remove.append(item)
			elif item.status == item.IDLE:
				self.l.log(self.l.DEBUG, "Idle search-object with id %d "
						"destroyed." % item.id)
				remove.append(item)
		# delete objects scheduled for deletion
		for item in remove:
			id = self.rootpoa.servant_to_id(item)
			self.rootpoa.deactivate_object(id)
			self.search_objects.remove(item)

	def __getFileManagerObject(self):
		"""
	Method retrieves FileManager object from nameservice.
		"""
		# Resolve the name "fred.context/FileManager.Object"
		name = [CosNaming.NameComponent("fred", "context"),
				CosNaming.NameComponent(self.fm_object, "Object")]
		obj = self.nsref.resolve(name)
		# Narrow the object to an ccReg::FileManager
		filemanager_obj = obj._narrow(ccReg.FileManager)
		return filemanager_obj

	def __dbGetMailTypeData(self, conn, mailtype):
		"""
	Method returns subject template, attachment templates and their content
	types.
		"""
		cur = conn.cursor()
		# get mail type data
		cur.execute("SELECT id, subject FROM mail_type WHERE name = %s " %
				pgdb._quote(mailtype))
		if cur.rowcount == 0:
			cur.close()
			self.l.log(self.l.ERR, "Mail type '%s' was not found in db." %
					mailtype)
			raise ccReg.Mailer.UnknownMailType(mailtype)

		id, subject = cur.fetchone()

		# get templates belonging to mail type
		cur.execute("SELECT contenttype, template FROM mail_type_template_map, "
				"mail_templates WHERE typeid = %d AND "
				"templateid = mail_templates.id" % id)
		if cur.rowcount == 0:
			self.l.log(self.l.WARNING, "Request for mail type ('%s') with no "
					"associated templates." % mailtype)
			templates = []
		else:
			templates = [ {"type":row[0], "template":row[1]} for row in cur.fetchall() ]
		cur.close()
		return id, subject, templates

	def __dbSetHeaders(self, conn, subject, header, msg, mailid):
		"""
	Method initializes headers of email object. Header struct is modified
	as well, which is important for actual value of envelope sender.
		"""
		# get default values from database
		cur = conn.cursor()
		cur.execute("SELECT h_from, h_replyto, h_errorsto, h_organization, "
				"h_contentencoding, h_messageidserver FROM mail_header_defaults")
		defaults = cur.fetchone()
		cur.close()
		# headers which don't have defaults
		msg["Subject"] = qp_str(subject)
		msg["To"] = header.h_to
		if header.h_cc: msg["Cc"] = header.h_cc
		if header.h_bcc: msg["Bcc"] = header.h_bcc
		msg["Date"] = formatdate(localtime=True)
		# modify header struct in place based on default values
		if not header.h_from:
			header.h_from = defaults[0]
		if not header.h_reply_to:
			header.h_reply_to = defaults[1]
		if not header.h_errors_to:
			header.h_errors_to = defaults[2]
		if not header.h_organization:
			header.h_organization = defaults[3]
		# headers which have default values
		msg["Message-ID"] = "<%d.%d@%s>" % (mailid, int(time.time()),defaults[5])
		msg["From"] = header.h_from
		msg["Reply-to"] = header.h_reply_to
		msg["Errors-to"] = header.h_errors_to
		msg["Organization"] = qp_str(header.h_organization)

	def __dbNewEmailId(self, conn):
		"""
	Get next available ID of email. This ID is used in message-id header and
	when archiving email.
		"""
		cur = conn.cursor()
		cur.execute("SELECT nextval('mail_archive_id_seq')")
		id = cur.fetchone()[0]
		cur.close()
		return int(id)

	def __dbArchiveEmail(self, conn, id, mailtypeid, mail, handles, attachs =[]):
		"""
	Method archives email in database.
		"""
		cur = conn.cursor()
		cur.execute("INSERT INTO mail_archive (id, mailtype, message) VALUES "
				"(%d, %d, %s)" % (id, mailtypeid, pgdb._quote(mail)) )
		for handle in handles:
			cur.execute("INSERT INTO mail_handles (mailid, associd) VALUES "
					"(%d, %s)" % (id, pgdb._quote(handle)))
		for attachid in attachs:
			cur.execute("INSERT INTO mail_attachments (mailid, attachid) VALUES "
					"(%d, %s)" % (id, attachid))
		cur.close()

	def __dbUpdateStatus(self, conn, mailid, status):
		"""
	Set status value in mail archive to specified number.
		"""
		cur = conn.cursor()
		cur.execute("UPDATE mail_archive SET status = %d WHERE id = %d" %
				(status, mailid))
		cur.close()

	def __dbGetDefaults(self, conn):
		"""
	Retrieve defaults from database.
		"""
		cur = conn.cursor()
		cur.execute("SELECT name, value FROM mail_defaults")
		pairs = [ (line[0], line[1]) for line in cur.fetchall() ]
		cur.close()
		return pairs

	def __dbGetMailTypes(self, conn):
		"""
	Get mapping between ids and names of mailtypes.
		"""
		cur = conn.cursor()
		cur.execute("SELECT id, name FROM mail_type")
		result = cur.fetchall()
		cur.close()
		return result

	def __constructEmail(self, conn, mailtype, header, data, handles, attachs):
		"""
	Method creates the whole email message, ready to be send by sendmail
	(or printed). This includes following steps:

		1) Create HDF dataset (base of templating)
		2) Template subject
		3) Create email headers
		4) Run templating for all wanted templates and attach them
		5) Archive email
		6) Attach non-templated attachments
		7) Dump email in string form
		"""
		# Create email object and init headers
		msg = MIMEMultipart()

		# Get new email id (derived from id in mailarchive table)
		mailid = self.__dbNewEmailId(conn)

		hdf = neo_util.HDF()
		# pour defaults in data set
		for pair in self.__dbGetDefaults(conn):
			hdf.setValue("defaults." + pair[0], pair[1])
		# pour user provided values in data set
		for pair in data:
			hdf.setValue(pair.key, pair.value)

		mtid, subject_tpl, templates = self.__dbGetMailTypeData(conn, mailtype)
		# render subject
		cs = neo_cs.CS(hdf)
		cs.parseStr(subject_tpl)
		subject = cs.render()
		# init email header (BEWARE that header struct is modified in this
		# call to function, so it is filled with defaults for not provided
		# headers, which is important for obtaining envelope sender).
		self.__dbSetHeaders(conn, subject, header, msg, mailid)
		# render text attachments
		for item in templates:
			cs = neo_cs.CS(hdf)
			cs.parseStr(item["template"])
			mimetext = MIMEText(cs.render(), item["type"])
			mimetext.set_charset("utf-8")
			Encoders.encode_7or8bit(mimetext)
			msg.attach(mimetext)

		# save text of email without non-templated attachments
		text_msg = msg.as_string()

		filemanager = None
		# attach not templated attachments (i.e. pdfs)
		for attachid in attachs:
			# initialize filemanager if it is first iteration
			if not filemanager:
				try:
					filemanager = self.__getFileManagerObject()
				except CosNaming.NamingContext.NotFound, e:
					self.l.log(self.l.ERR, "<%d> Could not get File Manager's "
							"reference: %s" % (mailid, e))
					raise ccReg.Mailer.InternalError("Attachment retrieval error")
				if filemanager == None:
					self.l.log(self.l.ERR, "<%d> FileManager reference is not "
							"filemanager." % mailid)
					raise ccReg.Mailer.InternalError("Attachment retrieval error")
			# get attachment from file manager
			self.l.log(self.l.DEBUG, "<%d> Sending request for attachement with "
					"id %d" % (mailid, attachid))
			try:
				# get MIME type of attachment
				attachinfo = filemanager.info(attachid)
				# get raw data of attachment
				rawattach = filemanager.load(attachid)
			except ccReg.FileManager.IdNotFound, e:
				self.l.log(self.l.ERR, "<%d> Non-existing id of attachment %d." %
						(mailid, attachid))
				raise ccReg.Mailer.AttachmentNotFound(attachid)
			except ccReg.FileManager.FileNotFound, e:
				self.l.log(self.l.ERR, "<%d> For attachment with id %d is "
						"missing file." % (mailid, attachid))
				raise ccReg.Mailer.InternalError("FileManager's inconsistency "
						"detected.")
			except ccReg.FileManager.InternalError, e:
				self.l.log(self.l.ERR, "<%d> Internal error on FileManager's "
						"side: %s" % (mailid, e.message))
				raise ccReg.Mailer.InternalError("Attachment '%s' caused unknown"
						" error." % attachment)

			maintype, subtype = attachinfo.mimetype.split("/")
			# create attachment
			part = MIMEBase(maintype, subtype)
			if attachinfo.name:
				part.add_header('content-disposition', 'attachment',
						filename=attachinfo.name)
			part.set_payload(rawattach)
			# encode attachment
			Encoders.encode_base64(part)
			msg.attach(part)

		# archive email (without non-templated attachments)
		self.__dbArchiveEmail(conn, mailid, mtid, text_msg, handles, attachs)
		# parseaddr returns sender's name and sender's address
		return mailid, msg.as_string(), parseaddr(header.h_from)[1]

	def mailNotify(self, mailtype, header, data, handles, attachs, preview):
		"""
	Method from IDL interface. It runs data through appropriate templates
	and generates an email. The text of the email and operation status must
	be archived in database.
		"""
		try:
			mailid = 0 # 0 means uninitialized (defined because of exceptions)
			self.l.log(self.l.INFO, "Email-Notification request received "
					"(preview = %s)" % preview)

			# connect to database
			conn = self.db.getConn()

			# construct email
			# envelope_from - must be specified directly to sendmail (it is not
			#     taken automatically from email text)
			mailid, mail, envelope_from = self.__constructEmail(conn, mailtype,
					header, data, handles, attachs)
			self.l.log(self.l.DEBUG, "<%d> Email was successfully generated "
					"(length = %d bytes)." % (mailid, len(mail)))

			if preview:
				# if it is a preview, we don't commit changes in archive table
				return mailid, mail

			# commit changes in mail archive, no matter if sendmail will fail
			conn.commit()

			# send email
			if self.testmode:
				p = os.popen("%s -f %s %s" % (self.sendmail, envelope_from,
					self.tester), "w")
			else:
				p = os.popen("%s -f %s -t" % (self.sendmail, envelope_from), "w")
			p.write(mail)
			status = p.close()
			if status is None: status = 0 # ok
			else: status = int(status) # sendmail failed

			# archive email and status
			self.__dbUpdateStatus(conn, mailid, status)
			conn.commit()
			self.db.releaseConn(conn)

			# check sendmail status
			if status == 0:
				self.l.log(self.l.DEBUG, "<%d> Email was successfully sent." %
					mailid)
			else:
				self.l.log(self.l.ERR, "<%d> Sendmail exited with failure "
					"(rc = %d)" % (mailid, status))
				raise ccReg.Mailer.SendMailError()
			return mailid, ""

		except ccReg.Mailer.SendMailError, e:
			raise
		except ccReg.Mailer.InternalError, e:
			raise
		except ccReg.Mailer.UnknownMailType, e:
			raise
		except ccReg.Mailer.AttachmentNotFound, e:
			raise
		except neo_util.ParseError, e:
			self.l.log(self.l.ERR, "<%d> Error when parsing template: %s" %
					(mailid, e))
			raise ccReg.Mailer.InternalError("Template error")
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (mailid, e))
			raise ccReg.Mailer.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
					(mailid, sys.exc_info()[0], e))
			raise ccReg.Mailer.InternalError("Unexpected error")

	def getMailTypes(self):
		"""
	Return mapping between ids of email types and their names.
		"""
		try:
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> get-mailtypes request received." % id)

			# connect to database
			conn = self.db.getConn()
			codelist = self.__dbGetMailTypes(conn)
			self.db.releaseConn(conn)
			return [ ccReg.MailTypeCode(item[0], item[1]) for item in codelist ]

		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "Database error: %s" % e)
			raise ccReg.Mailer.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "Unexpected exception: %s:%s" %
					(sys.exc_info()[0], e))
			raise ccReg.Mailer.InternalError("Unexpected error")

	def createSearchObject(self, filter):
		"""
	This is universal mail archive lookup function. It returns object reference
	which can be used to access data.
		"""
		try:
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> Search create request received." % id)

			# construct SQL query coresponding to filter constraints
			conditions = []
			if filter.mailid != -1:
				conditions.append("mail_archive.id = %d" % filter.mailid)
			if filter.mailtype != -1:
				conditions.append("mail_archive.mailtype = %d" % filter.mailtype)
			if filter.status != -1:
				conditions.append("mail_archive.status = %d" % filter.status)
			if filter.handle:
				conditions.append("mail_handles.associd = %s" %
						pgdb._quote(filter.handle))
			if filter.attachid != -1:
				conditions.append("mail_attachments.attachid = %d" %
						filter.attachid)
			fromdate = filter.crdate._from
			if not isInfinite(fromdate):
				conditions.append("mail_archive.crdate > '%d-%d-%d %d:%d:%d'" %
						(fromdate.date.year,
						fromdate.date.month,
						fromdate.date.day,
						fromdate.hour,
						fromdate.minute,
						fromdate.second))
			todate = filter.crdate.to
			if not isInfinite(todate):
				conditions.append("mail_archive.crdate < '%d-%d-%d %d:%d:%d'" %
						(todate.date.year,
						todate.date.month,
						todate.date.day,
						todate.hour,
						todate.minute,
						todate.second))
			if filter.fulltext:
				conditions.append("mail_archive.message LIKE '%%%s%%'" %
						pgdb._quote(filter.fulltext)[1:-1])
			if len(conditions) == 0:
				cond = ""
			else:
				cond = "WHERE (%s)" % conditions[0]
				for condition in conditions[1:]:
					cond += " AND (%s)" % condition

			# connect to database
			conn = self.db.getConn()
			cur = conn.cursor()

			self.l.log(self.l.DEBUG, "<%d> Search WHERE clause is: %s" %
					(id, cond))
			# execute MEGA GIGA query :(
			cur.execute("SELECT mail_archive.id, mail_archive.mailtype, "
					"mail_archive.crdate, mail_archive.moddate, "
					"mail_archive.status, mail_archive.message, "
					"mail_attachments.attachid, mail_handles.associd "
					"FROM mail_archive LEFT JOIN mail_handles ON "
					"(mail_archive.id = mail_handles.mailid) LEFT JOIN "
					"mail_attachments ON (mail_archive.id = "
					"mail_attachments.mailid) %s ORDER BY mail_archive.id" %
					cond)
			self.db.releaseConn(conn)
			self.l.log(self.l.DEBUG, "<%d> Number of records in cursor: %d" %
					(id, cur.rowcount))

			# Create an instance of MailSearch_i and an MailSearch object ref
			searchobj = MailSearch_i(id, cur, self.l)
			self.search_objects.append(searchobj)
			searchref = self.rootpoa.servant_to_reference(searchobj)
			return searchref

		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "Database error: %s" % e)
			raise ccReg.Mailer.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "Unexpected exception: %s:%s" %
					(sys.exc_info()[0], e))
			raise ccReg.Mailer.InternalError("Unexpected error")


class MailSearch_i (ccReg__POA.MailSearch):
	"""
Class encapsulating results of search.
	"""

	# statuses of search object
	ACTIVE = 1
	CLOSED = 2
	IDLE = 3

	def __init__(self, id, cursor, log):
		"""
	Initializes search object.
		"""
		self.l = log
		self.id = id
		self.cursor = cursor
		self.status = self.ACTIVE
		self.crdate = time.time()
		self.lastuse = self.crdate
		self.lastrow = cursor.fetchone()

	def __get_one_search_result(self):
		"""
	Fetch one mail from archive. The problem is that attachments and handles
	must be transformed from cursor rows to lists.
		"""
		if not self.lastrow:
			return None
		prev = self.lastrow
		curr = self.cursor.fetchone()
		id = prev[0]
		mtid = prev[1]
		crdate = prev[2]
		if prev[3]: # moddate may be NULL
			moddate = prev[3]
		else:
			moddate = ""
		if prev[4] == None: # status may be NULL
			status = -1
		else:
			status = prev[4]
		message = prev[5]
		if prev[6]: # attachment may be NULL
			attachs = [prev[6]]
		else:
			attachs = []
		if prev[7]: # handle may be NULL
			handles = [prev[7]]
		else:
			handles = []
		# process all rows with the same id
		while curr and id == curr[0]: # while the ids are same
			if curr[6]:
				if curr[6] not in attachs:
					attachs.append(curr[6])
			if curr[7]:
				if curr[7] not in handles:
					handles.append(curr[7])
			curr = self.cursor.fetchone() # move to next row
		# save leftover
		self.lastrow = curr
		return id, mtid, crdate, moddate, status, message, handles, attachs

	def getNext(self, count):
		"""
	Get result of search.
		"""
		try:
			self.l.log(self.l.INFO, "<%d> Get search results request received." %
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
				raise ccReg.MailSearch.NotActive()

			# update last use timestamp
			self.lastuse = time.time()

			# get 'count' results
			maillist = []
			for i in range(count):
				if not self.lastrow:
					break
				(id, mailtypeid, crdate, moddate, status, message, handles,
						attachs) = self.__get_one_search_result()
				# create email structure
				maillist.append( ccReg.Mail(id, mailtypeid, crdate, moddate,
					status, message, handles, attachs) )

			self.l.log(self.l.DEBUG, "<%d> Number of records returned: %d." %
					(self.id, len(maillist)))
			return maillist

		except MailSearch.NotActive, e:
			raise
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
					(self.id, sys.exc_info()[0], e))
			raise ccReg.MailSearch.InternalError("Unexpected error")

	def destroy(self):
		"""
	Mark object as ready to be destroyed.
		"""
		try:
			if self.status != self.ACTIVE:
				self.l.log(self.l.WARNING, "<%d> An attempt to close non-active "
						"search." % self.id)
				return

			self.status = self.CLOSED
			self.l.log(self.l.INFO, "<%d> Search closed." % self.id)
			# close db cursor
			self.cursor.close()
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
					(self.id, sys.exc_info()[0], e))
			raise ccReg.MailSearch.InternalError("Unexpected error")


def init(logger, db, nsref, conf, joblist, rootpoa):
	"""
Function which creates, initializes and returns servant Mailer.
	"""
	# Create an instance of Mailer_i and an Mailer object ref
	servant = Mailer_i(logger, db, nsref, conf, joblist, rootpoa)
	return servant, "Mailer"

