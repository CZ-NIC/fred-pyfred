#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of file manager daemon.
"""

import os
# corba stuff
from omniORB import CORBA, PortableServer
import ccReg, ccReg__POA


class FileManager_i (ccReg__POA.FileManager):
	"""
This class implements FileManager interface.
	"""
	def __init__(self, logger, conf):
		"""
	Initializer saves db (which is later used for opening database
	connection) and logger (used for logging).
		"""
		# ccReg__POA.FileManager doesn't have constructor
		self.l = logger # syslog functionality

		# default configuration
		self.rootdir = "/var/tmp/filemanager"
		# Parse FileManager-specific configuration
		if conf.has_section("FileManager"):
			# tester email address
			try:
				rootdir = conf.get("FileManager", "rootdir")
				if not os.path.isabs(rootdir):
					self.l.log(self.l.ERR, "rootdir must be absolute path")
					raise Exception()
				self.rootdit = rootdir
			except ConfigParser.NoOptionError, e:
				pass

		# try to create rootdir if it does not exist
		if os.path.isdir(self.rootdir):
			if not os.access(self.rootdir, os.R_OK | os.W_OK):
				self.l.log(self.l.ERR, "Directory '%s' is not r/w: " %
						self.rootdir)
				raise Exception()
		else:
			try:
				os.makedirs(self.rootdir, 0700)
			except Exception, e:
				self.l.log(self.l.ERR, "Cannot create directory for file "
						"manager: %s" % e)
				raise
		self.l.log(self.l.DEBUG, "Object initialized")


	def save(self, name, data):
		"""
	Method from IDL interface. It saves data to a file.
		"""
		self.l.log(self.l.INFO, "File manager save-request received")
		if not name:
			raise ccReg.FileManager.InvalidName("")
		try:
			filename = os.path.join(self.rootdir, name)
			if os.path.commonprefix([self.rootdir, filename]) != self.rootdir:
				raise ccReg.FileManager.InvalidName(name)
			dir = os.path.dirname(filename)
			if os.path.isdir(dir):
				if not os.access(dir, os.R_OK | os.W_OK):
					self.l.log(self.l.ERR, "Directory '%s' is not r/w: " % dir)
					raise ccReg.FileManager.InternalError("Storage error")
			else:
				try:
					os.makedirs(dir, 0700)
				except Exception, e:
					self.l.log(self.l.ERR, "Cannot create directory for file "
							"manager: %s" % e)
					raise ccReg.FileManager.InternalError("Storage error")
			f = open(filename, "wb")
			f.write(data)
			f.close()

		except ccReg.FileManager.InvalidName, e:
			raise
		except ccReg.FileManager.InternalError, e:
			raise
		except Exception, e:
			self.l.log(self.l.ERR, "Unexpected exception caugth: %s:%s" %
					(sys.exc_info()[0], e))
			raise ccReg.FileManager.InternalError("Unexpected error")

	def load(self, name):
		"""
	Method from IDL interface. It loads data from a file.
		"""
		self.l.log(self.l.INFO, "File manager load-request received")
		if not name:
			raise ccReg.FileManager.InvalidName("")
		filename = os.path.join(self.rootdir, name)
		if not os.path.exists(filename):
			self.l.log(self.l.ERR, "File '%s' does not exist" % filename)
			raise ccReg.FileManager.FileNotFound(name)
		if not os.path.exists(filename):
			self.l.log(self.l.ERR, "File '%s' does not exist" % filename)
			raise ccReg.FileManager.FileNotFound(name)
		if not os.access(filename, os.R_OK):
			self.l.log(self.l.ERR, "File '%s' cannot be accessed" % filename)
			# we will return file not exist in this case
			raise ccReg.FileManager.FileNotFound(name)
		f = open(filename, "rb")
		octets = f.read()
		f.close()
		# temporary hack for mime type determination
		if filename.endswith(".pdf"):
			mimetype = "application/pdf"
		elif filename.endswith(".ps"):
			mimetype = "application/postscript"
		elif filename.endswith(".mp3"):
			mimetype = "audio/mp3"
		elif filename.endswith(".ogg"):
			mimetype = "audio/x-ogg"
		else:
			mimetype = "application/octet-stream"

		return octets, mimetype


def init(logger, db, nsref, conf, joblist, rootpoa):
	"""
Function which creates, initializes and returns servant FileManager.
	"""
	# Create an instance of Mailer_i and an Mailer object ref
	servant = FileManager_i(logger, conf)
	return servant, "FileManager"

