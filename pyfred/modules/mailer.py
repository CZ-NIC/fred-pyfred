#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of mailer daemon.
"""

import os, sys, time, random, ConfigParser, popen2, Queue, tempfile
import pgdb
from pyfred.utils import isInfinite
# corba stuff
from omniORB import CORBA, PortableServer
import CosNaming
from pyfred.idlstubs import ccReg, ccReg__POA
# template stuff
import neo_cgi # must be included before neo_cs and neo_util
import neo_cs, neo_util
# email stuff
import email
import email.Charset
from email import Encoders
from email.MIMEMultipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email.Utils import formatdate, parseaddr

def contentfilter(mail):
	"""
This routine slightly modifies email in order to prevent unexpected results
of email signing.
	"""
	# tabs might not be preserved during mail transfer
	mail = mail.replace('\t', '        ')
	# add newline at the end to make outlook - shitty client - happy
	return mail + '\n'

def qp_str(string):
	"""
Function checks if the string contains characters, which need to be "quoted
printable" and if there are any, it will encode the string. This function
is used for headers of email.
	"""
	need = False
	for c in string:
		if email.quopriMIME.header_quopri_check(c):
			need = True
	if need:
		string = email.quopriMIME.header_encode(string, charset="utf-8",
				maxlinelen=None)
	return string

class Mailer_i (ccReg__POA.Mailer):
	"""
This class implements Mailer interface.
	"""

	class MailerException(Exception):
		"""
	Exception used for error signalization in periodic sendmail routine.
		"""
		def __init__(self, msg):
			Exception.__init__(self, msg)

	def __init__(self, logger, db, conf, joblist, corba_refs):
		"""
	Initializer saves db_pars (which is later used for opening database
	connection) and logger (used for logging).
		"""
		# ccReg__POA.Mailer doesn't have constructor
		self.db = db # db object for accessing database
		self.l = logger # syslog functionality
		self.search_objects = Queue.Queue(-1) # list of created search objects
		self.corba_refs = corba_refs # root poa and nameservice reference

		# this avoids base64 encoding for utf-8 messages
		email.Charset.add_charset( 'utf-8', email.Charset.SHORTEST, None, None )

		# default configuration
		self.testmode     = False
		self.tester       = ""
		self.sendmail     = "/usr/sbin/sendmail"
		self.openssl      = "/usr/bin/openssl"
		self.fm_context   = "fred"
		self.fm_object    = "FileManager"
		self.idletreshold = 3600
		self.checkperiod  = 60
		self.signing      = False
		self.keyfile      = ""
		self.certfile     = ""
		self.vcard        = ""
		self.sendperiod   = 300
		self.archstatus   = 1
		self.maxattempts  = 3
		# Parse Mailer-specific configuration
		if conf.has_section("Mailer"):
			# testmode
			try:
				self.testmode = conf.getboolean("Mailer", "testmode")
				if self.testmode:
					self.l.log(self.l.DEBUG, "Test mode is turned on.")
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
					self.l.log(self.l.DEBUG, "Path to sendmail is %s." %
							sendmail)
					self.sendmail = sendmail
			except ConfigParser.NoOptionError, e:
				pass
			# openssl path
			try:
				openssl = conf.get("Mailer", "openssl")
				if openssl:
					self.l.log(self.l.DEBUG, "Path to openssl is %s." % openssl)
					self.openssl = openssl
			except ConfigParser.NoOptionError, e:
				pass
			# filemanager object's name
			try:
				fm_object = conf.get("Mailer", "filemanager_object")
				if fm_object:
					self.l.log(self.l.DEBUG, "Name under which to look for "
							"filemanager is %s." % fm_object)
					fm_object = fm_object.split(".")
					if len(fm_object) == 2:
						self.fm_context = fm_object[0]
						self.fm_object = fm_object[1]
					else:
						self.fm_object = fm_object[0]
			except ConfigParser.NoOptionError, e:
				pass
			# check period
			try:
				self.checkperiod = conf.getint("Mailer", "checkperiod")
				self.l.log(self.l.DEBUG, "checkperiod is set to %d." %
						self.checkperiod)
			except ConfigParser.NoOptionError, e:
				pass
			# idle treshold
			try:
				self.idletreshold = conf.getint("Mailer", "idletreshold")
				self.l.log(self.l.DEBUG, "idletreshold is set to %d." %
						self.idletreshold)
			except ConfigParser.NoOptionError, e:
				pass
			# signing
			try:
				self.signing = conf.getboolean("Mailer", "signing")
				if self.signing:
					self.l.log(self.l.DEBUG, "Signing of emails is turned on.")
			except ConfigParser.NoOptionError, e:
				pass
			# certificate path
			try:
				certfile = conf.get("Mailer", "certfile")
				if certfile:
					self.l.log(self.l.DEBUG, "Path to certfile is %s." %
							certfile)
					self.certfile = certfile
			except ConfigParser.NoOptionError, e:
				pass
			# key path
			try:
				keyfile = conf.get("Mailer", "keyfile")
				if keyfile:
					self.l.log(self.l.DEBUG, "Path to keyfile is %s." % keyfile)
					self.keyfile = keyfile
			except ConfigParser.NoOptionError, e:
				pass
			# vcard switch
			try:
				vcard = conf.getboolean("Mailer", "vcard")
				if vcard:
					self.l.log(self.l.DEBUG, "Vcard attachment enabled.")
					conn = self.db.getConn()
					self.vcard = self.__dbGetVcard(conn).strip() + '\n'
					self.db.releaseConn(conn)
			except ConfigParser.NoOptionError, e:
				pass
			# sendperiod
			try:
				self.sendperiod = conf.getint("Mailer", "sendperiod")
				self.l.log(self.l.DEBUG, "Sendperiod is %d seconds." %
							self.sendperiod)
			except ConfigParser.NoOptionError, e:
				pass
			# archstatus alias manualconfirm
			try:
				manconfirm = conf.getboolean("Mailer", "manconfirm")
				if manconfirm:
					self.l.log(self.l.DEBUG, "Manual confirmation of email "
								"submission is enabled.")
					self.archstatus = 2
			except ConfigParser.NoOptionError, e:
				pass
			# maxattempts
			try:
				self.maxattempts = conf.getint("Mailer", "maxattempts")
				self.l.log(self.l.DEBUG, "Maxattempts is set to %d." %
						self.maxattempts)
			except ConfigParser.NoOptionError, e:
				pass

		# check configuration consistency
		if self.tester and not self.testmode:
			self.l.log(self.l.WARNING, "Tester configuration directive will "
					"be ignored because testmode is not turned on.")
		if self.signing and not (self.certfile and self.keyfile):
			raise Exception("Certificate and key file must be set for mailer.")
		# do quick check that all files exist
		if not os.path.isfile(self.sendmail):
			raise Exception("sendmail binary (%s) does not exist." %
					self.sendmail)
		if self.signing:
			if not os.path.isfile(self.openssl):
				raise Exception("openssl binary (%s) does not exist." %
						self.openssl)
			if not os.path.isfile(self.certfile):
				raise Exception("Certificate (%s) does not exist." %
						self.certfile)
			if not os.path.isfile(self.keyfile):
				raise Exception("Key file (%s) does not exist." %
						self.keyfile)
		# schedule regular cleanup
		joblist.append( { "callback":self.__search_cleaner, "context":None,
			"period":self.checkperiod, "ticks":1 } )
		joblist.append( { "callback":self.__sendEmails, "context":None,
			"period":self.sendperiod, "ticks":1 } )
		self.l.log(self.l.INFO, "Object initialized")

	def __search_cleaner(self, ctx):
		"""
	Method deletes closed or idle search objects.
		"""
		self.l.log(self.l.DEBUG, "Regular maintance procedure.")
		remove = []
		# the queue may change and the number of items in the queue may grow
		# but we can be sure that there will be never less items than nitems
		# therefore we can use blocking call get() on queue
		nitems = self.search_objects.qsize()
		for i in range(nitems):
			item = self.search_objects.get()
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
			# if object is active - reinsert the object in queue
			else:
				self.search_objects.put(item)
		# delete objects scheduled for deletion
		rootpoa = self.corba_refs.rootpoa
		for item in remove:
			id = rootpoa.servant_to_id(item)
			rootpoa.deactivate_object(id)

	def __sendEmails(self, ctx):
		"""
	Method sends all emails stored in database and ready to be sent.
		"""
		self.l.log(self.l.DEBUG, "Regular send-emails procedure.")
		conn = self.db.getConn()
		# iterate over all emails from database ready to be sent
		for (mailid, mail_text, attachs) in self.__dbGetReadyEmails(conn):
			try:
				# run email through completion procedure
				(mail, efrom) = self.__completeEmail(mailid, mail_text, attachs)
				# sign email if signing is enabled
				if self.signing:
					mail = self.__sign_email(mail)
				# send email
				status = self.__sendEmail(mail, efrom)
				# check sendmail status
				if status == 0:
					self.l.log(self.l.DEBUG, "Email with id %d was successfully"
							" sent." % mailid)
					# archive email and status
					self.__dbUpdateStatus(conn, mailid, 0)
					conn.commit()
				else:
					self.l.log(self.l.ERR, "Sendmail exited with failure for "
						"email with id %d (rc = %d)" % (mailid, status))
					self.__dbSendFailed(conn, mailid)
			except Mailer_i.MailerException, me:
				self.l.log(self.l.ERR, "Error when sending email with "
						"mailid %d: %s" % (mailid, me))
				self.__dbSendFailed(conn, mailid)
		self.db.releaseConn(conn)

	def __getFileManagerObject(self):
		"""
	Method retrieves FileManager object from nameservice.
		"""
		# Resolve the name "fred.context/FileManager.Object"
		name = [CosNaming.NameComponent(self.fm_context, "context"),
				CosNaming.NameComponent(self.fm_object, "Object")]
		obj = self.corba_refs.nsref.resolve(name)
		# Narrow the object to an ccReg::FileManager
		filemanager_obj = obj._narrow(ccReg.FileManager)
		return filemanager_obj

	def __dbGetVcard(self, conn):
		"""
	Get vcard attachment from database.
		"""
		cur = conn.cursor()
		cur.execute("SELECT vcard FROM mail_vcard")
		vcard = cur.fetchone()[0]
		cur.close()
		return vcard

	def __dbGetMailTypeData(self, conn, mailtype):
		"""
	Method returns subject template, attachment templates and their content
	types.
		"""
		cur = conn.cursor()
		# get mail type data
		cur.execute("SELECT id, subject FROM mail_type WHERE name = %s" %
				(pgdb._quote(mailtype)))
		if cur.rowcount == 0:
			cur.close()
			self.l.log(self.l.ERR, "Mail type '%s' was not found in db." %
					mailtype)
			raise ccReg.Mailer.UnknownMailType(mailtype)

		id, subject = cur.fetchone()

		# get templates belonging to mail type
		cur.execute("SELECT mte.contenttype, mte.template, mf.footer "
				"FROM mail_type_template_map mt, mail_templates mte "
				"LEFT JOIN mail_footer mf ON (mte.footer = mf.id) "
				"WHERE mt.typeid = %d AND mt.templateid = mte.id" % id)
		templates = []
		if cur.rowcount == 0:
			self.l.log(self.l.WARNING, "Request for mail type ('%s') with no "
					"associated templates." % mailtype)
		else:
			for row in cur.fetchall():
				# append footer if there is any to template
				if row[2]:
					templates.append( {"type":row[0],
						"template":row[1] +'\n'+ row[2]} )
				else:
					templates.append( {"type":row[0], "template":row[1]} )
		cur.close()
		return id, subject, templates

	def __dbSetHeaders(self, conn, subject, header, msg):
		"""
	Method initializes headers of email object. Header struct is modified
	as well, which is important for actual value of envelope sender.
	Date header is added later and Message-ID is later revisited.
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
		msg["Message-ID"] = "%s" % defaults[5]
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

	def __dbArchiveEmail(self, conn, mailtype_id, mail, handles, attachs = []):
		"""
	Method archives email in database.
		"""
		cur = conn.cursor()
		# get ID of next email in archive
		cur.execute("SELECT nextval('mail_archive_id_seq')")
		mailid = cur.fetchone()[0]
		# save the generated email
		cur.execute("INSERT INTO mail_archive (id, mailtype, message, status) "
				"VALUES (%d, %d, %s, %d)" %
				(mailid, mailtype_id, pgdb._quote(mail), self.archstatus) )
		for handle in handles:
			cur.execute("INSERT INTO mail_handles (mailid, associd) VALUES "
					"(%d, %s)" % (mailid, pgdb._quote(handle)))
		for attachid in attachs:
			cur.execute("INSERT INTO mail_attachments (mailid, attachid) VALUES"
					" (%d, %s)" % (mailid, attachid))
		cur.close()
		return mailid

	def __dbGetReadyEmails(self, conn):
		"""
	Get all emails from database which are ready to be sent.
		"""
		cur = conn.cursor()
		cur.execute("SELECT mar.id, mar.message, mat.attachid "
				"FROM mail_archive mar LEFT JOIN mail_attachments mat "
				"ON (mar.id = mat.mailid) "
				"WHERE mar.status = 1 AND mar.attempt < %d" % self.maxattempts)
		rows = cur.fetchall()
		cur.close()
		# transform result attachids in list
		result = []
		for row in rows:
			if len(result) == 0 or result[-1][0] != row[0]:
				if row[2]:
					result.append( (row[0], row[1], [row[2]]) )
				else:
					result.append( (row[0], row[1], []) )
			else:
				result[-1][2].append(row[2])

		return result

	def __dbUpdateStatus(self, conn, mailid, status, reset_counter = False):
		"""
	Set status value in mail archive. Meaning of status values are:

	  0: Mail was successfully sent.
	  1: Mail is ready to be sent.
	  2: Mail waits for manual confirmation.

	If reset_counter is true, then counter of unsuccessfull sendmail attempts
	is set to 0.
		"""
		cur = conn.cursor()
		if reset_counter:
			cur.execute("UPDATE mail_archive "
					"SET status = %d, moddate = now(), attempt = 0 "
					"WHERE id = %d" % (status, mailid))
		else:
			cur.execute("UPDATE mail_archive "
					"SET status = %d, moddate = now() "
					"WHERE id = %d" % (status, mailid))
		if cur.rowcount != 1:
			raise ccReg.Mailer.UnknownMailid(mailid)
		cur.close()

	def __dbSendFailed(self, conn, mailid):
		"""
	Increment counter of failed attempts to send email.
		"""
		cur = conn.cursor()
		cur.execute("UPDATE mail_archive "
				"SET attempt = attempt + 1, moddate = now() "
				"WHERE id = %d" % mailid)
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

	def __completeEmail(self, mailid, mail_text, attachs):
		"""
	Method attaches base64 attachments, few email headers to email message.
		"""
		# Create email object and init headers
		msg = email.message_from_string(mail_text)

		filemanager = None
		# attach not templated attachments (i.e. pdfs)
		for attachid in attachs:
			# initialize filemanager if it is first iteration
			if not filemanager:
				try:
					filemanager = self.__getFileManagerObject()
				except CosNaming.NamingContext.NotFound, e:
					raise Mailer_i.MailerException("Could not get File "
							"Manager's reference: %s" % e)
				if filemanager == None:
					raise Mailer_i.MailerException("FileManager reference is "
							"not filemanager.")
			# get attachment from file manager
			self.l.log(self.l.DEBUG, "Sending request for attachment with "
					"id %d" % attachid)
			try:
				# get MIME type of attachment
				attachinfo = filemanager.info(attachid)
				# create attachment
				if not attachinfo.mimetype or attachinfo.mimetype.find("/") < 0:
					# provide some defaults
					maintype = "application"
					subtype = "octet-stream"
				else:
					maintype, subtype = attachinfo.mimetype.split("/")
				part = MIMEBase(maintype, subtype)
				if attachinfo.name:
					part.add_header('content-disposition', 'attachment',
							filename=attachinfo.name)
				# get raw data of attachment
				loadobj = filemanager.load(attachid)
				attachdata = ""
				chunk = loadobj.download(2**14) # download 16K chunk
				while chunk:
					attachdata += chunk
					chunk = loadobj.download(2**14) # download 16K chunk
				loadobj.finalize_download()
				# encode attachment
				part.set_payload(attachdata)
				Encoders.encode_base64(part)
				msg.attach(part)

			except ccReg.FileManager.IdNotFound, e:
				raise Mailer_i.MailerException("Non-existing id of attachment "
						"%d given." % attachid)
			except ccReg.FileManager.FileNotFound, e:
				raise Mailer_i.MailerException("For attachment with id %d is "
						"missing file." % attachid)
			except ccReg.FileDownload.InternalError, e:
				raise Mailer_i.MailerException("Internal error when "
						"downloading attachment with id %d: %s" %
						(attachid, e.message))
			except ccReg.FileDownload.NotActive, e:
				raise Mailer_i.MailerException("Download object for attachment "
						"with id %d is not active anymore: %s" %
						(attachid, e.message))

		envelope_from = msg["From"]
		msg["Date"] = formatdate(localtime=True)
		msg["Message-ID"] = "<%d.%d@%s>" % (mailid, int(time.time()),
				msg["Message-ID"])
		# parseaddr returns sender's name and sender's address
		return contentfilter(msg.as_string()), parseaddr(envelope_from)[1]

	def __sign_email(self, mail):
		"""
	Routine for signing of email.
		"""
		# before signing remove non-MIME headers
		headerend_index = mail.find("\n\n") # find empty line
		headers = mail[:headerend_index+1]
		mimeheaders = ""
		signedmail = ""
		# throw away otherwise duplicated headers
		for header in headers.splitlines():
			if header.startswith("MIME-Version:") or \
					header.startswith("Content-Type:") or \
					header.startswith("Content-Transfer-Encoding:"):
				mimeheaders += header + '\n'
			else:
				signedmail += header + '\n'
		mail = mimeheaders + mail[headerend_index+1:]
		# create temporary file for openssl which will be used as input
		tmpfile = tempfile.mkstemp(prefix="pyfred-smime")
		os.write(tmpfile[0], mail)
		os.close(tmpfile[0])
		# do the signing
		child = popen2.Popen3("%s smime -sign -signer %s -inkey %s -in %s" %
				(self.openssl, self.certfile, self.keyfile, tmpfile[1]), True)
		child.tochild.close()
		# read signed email until eof occurs
		buf = child.fromchild.read()
		while buf:
			signedmail += buf
			buf = child.fromchild.read()
		# wait for child to terminate
		stat = os.WEXITSTATUS(child.wait())
		os.remove(tmpfile[1])
		if stat:
			if child.childerr:
				err = child.childerr.read()
			else:
				err = ''
			self.l.log(self.l.ERR, "Openssl exited with failure (%d): %s" %
					(stat, err))
			raise ccReg.Mailer.InternalError("Signing of email failed.")
		return signedmail

	def __sendEmail(self, mail, envelope_from):
		"""
	This routine sends email.
		"""
		# this tranformation guaranties that each line is terminated by crlf
		mail = mail.replace('\r', '')
		mail = mail.replace('\n', '\r\n')

		# send email
		if self.testmode:
			# if tester is not set, do nothing
			if self.tester:
				p = os.popen("%s -f %s %s" %
						(self.sendmail, envelope_from, self.tester), "w")
				p.write(mail)
				status = p.close()
			else:
				status = 0
		else:
			p = os.popen("%s -f %s -t" % (self.sendmail, envelope_from), "w")
			p.write(mail)
			status = p.close()

		if status is None: status = 0 # ok
		else: status = int(status) # sendmail failed

		return status

	def __prepareEmail(self, conn, mailtype, header, data):
		"""
	Method creates text part of email, it means without base64 encoded
	attachments. This includes following steps:

		1) Create HDF dataset (base of templating)
		2) Template subject
		3) Create email headers
		4) Run templating for all wanted templates and attach them
		5) Archive email
		6) Dump email in string form
		"""
		# Create multipart email object and init headers
		msg = MIMEMultipart()

		hdf = neo_util.HDF()
		# pour defaults in data set
		for pair in self.__dbGetDefaults(conn):
			hdf.setValue("defaults." + pair[0], pair[1])
		# pour user provided values in data set
		for pair in data:
			hdf.setValue(pair.key, pair.value)

		mailtype_id, subject_tpl, templates = self.__dbGetMailTypeData(conn,
				mailtype)
		# render subject
		cs = neo_cs.CS(hdf)
		cs.parseStr(subject_tpl)
		subject = cs.render()
		# 'To:' is the only mandatory header
		if not header.h_to:
			raise ccReg.Mailer.InvalidHeader("To")
		# init email header (BEWARE that header struct is modified in this
		# call to function, so it is filled with defaults for not provided
		# headers, which is important for obtaining envelope sender).
		self.__dbSetHeaders(conn, subject, header, msg)
		# render text attachments
		for item in templates:
			cs = neo_cs.CS(hdf)
			cs.parseStr(item["template"])
			mimetext = MIMEText(cs.render().strip() + '\n', item["type"])
			mimetext.set_charset("utf-8")
			# Leave this commented out, otherwise it duplicates header
			#   Content-Transfer-Encoding
			#Encoders.encode_7or8bit(mimetext)
			msg.attach(mimetext)
		# Attach vcard attachment if configured so
		if self.vcard:
			mimetext = MIMEText(self.vcard, "x-vcard")
			mimetext.set_charset("utf-8")
			msg.attach(mimetext)

		return msg.as_string(), mailtype_id

	def mailNotify(self, mailtype, header, data, handles, attachs, preview):
		"""
	Method from IDL interface. It runs data through appropriate templates
	and generates an email. The text of the email and operation status must
	be archived in database.
		"""
		try:
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> Email-Notification request received "
					"(preview = %s)" % (id, preview))

			# connect to database
			conn = self.db.getConn()

			mail_text, mailtype_id = self.__prepareEmail(conn, mailtype,
					header, data)

			if preview:
				return (0, mail_text)

			# archive email (without non-templated attachments)
			mailid = self.__dbArchiveEmail(conn, mailtype_id, mail_text,
					handles, attachs)
			# commit changes in mail archive
			conn.commit()
			self.db.releaseConn(conn)

			return (mailid, "")

		except ccReg.Mailer.InternalError, e:
			raise
		except ccReg.Mailer.UnknownMailType, e:
			raise
		except ccReg.Mailer.InvalidHeader, e:
			self.l.log(self.l.ERR, "<%d> Header 'To' is empty." % id)
			raise
		except neo_util.ParseError, e:
			self.l.log(self.l.ERR, "<%d> Error when parsing template: %s" %
					(id, e))
			raise ccReg.Mailer.InternalError("Template error")
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
			raise ccReg.Mailer.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
					(id, sys.exc_info()[0], e))
			raise ccReg.Mailer.InternalError("Unexpected error")

	def resend(self, mailid):
		"""
	Resend email from mail archive with given id. This includes zeroing of
	counter of unsuccessfull sendmail attempts and setting status to 1.
		"""
		try:
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> resend request for email with id = "
					"%d received." % (id, mailid))

			conn = self.db.getConn()
			self.__dbUpdateStatus(conn, mailid, 1, True)
			conn.commit()
			self.db.releaseConn(conn)

		except ccReg.Mailer.UnknownMailid, e:
			self.l.log(self.l.ERR, "<%d> Unknown mailid %d." % (id, mailid))
			raise
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
			raise ccReg.Mailer.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
					(id, sys.exc_info()[0], e))
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
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
			raise ccReg.Mailer.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
					(id, sys.exc_info()[0], e))
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
				conditions.append("ma.id = %d" % filter.mailid)
			if filter.mailtype != -1:
				conditions.append("ma.mailtype = %d" % filter.mailtype)
			if filter.status != -1:
				conditions.append("ma.status = %d" % filter.status)
			if filter.handle:
				conditions.append("mh.associd = %s" % pgdb._quote(filter.handle))
			if filter.attachid != -1:
				conditions.append("mt.attachid = %d" % filter.attachid)
			fromdate = filter.crdate._from
			if not isInfinite(fromdate):
				conditions.append("ma.crdate > '%d-%d-%d %d:%d:%d'" %
						(fromdate.date.year,
						fromdate.date.month,
						fromdate.date.day,
						fromdate.hour,
						fromdate.minute,
						fromdate.second))
			todate = filter.crdate.to
			if not isInfinite(todate):
				conditions.append("ma.crdate < '%d-%d-%d %d:%d:%d'" %
						(todate.date.year,
						todate.date.month,
						todate.date.day,
						todate.hour,
						todate.minute,
						todate.second))
			if filter.fulltext:
				conditions.append("ma.message LIKE '%%%s%%'" %
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
			cur.execute("SELECT ma.id, ma.mailtype, ma.crdate, ma.moddate, "
						"ma.status, ma.message, mt.attachid, mh.associd "
					"FROM mail_archive ma "
					"LEFT JOIN mail_handles mh ON (ma.id = mh.mailid) "
					"LEFT JOIN mail_attachments mt ON (ma.id = mt.mailid) "
					"%s ORDER BY ma.id" % cond)
			self.db.releaseConn(conn)
			self.l.log(self.l.DEBUG, "<%d> Number of records in cursor: %d" %
					(id, cur.rowcount))

			# Create an instance of MailSearch_i and an MailSearch object ref
			searchobj = MailSearch_i(id, cur, self.l)
			self.search_objects.put(searchobj)
			searchref = self.corba_refs.rootpoa.servant_to_reference(searchobj)
			return searchref

		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
			raise ccReg.Mailer.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
					(id, sys.exc_info()[0], e))
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
					status, handles, message, attachs) )

			self.l.log(self.l.DEBUG, "<%d> Number of records returned: %d." %
					(self.id, len(maillist)))
			return maillist

		except ccReg.MailSearch.NotActive, e:
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


def init(logger, db, conf, joblist, corba_refs):
	"""
Function which creates, initializes and returns servant Mailer.
	"""
	# Create an instance of Mailer_i and an Mailer object ref
	servant = Mailer_i(logger, db, conf, joblist, corba_refs)
	return servant, "Mailer"
