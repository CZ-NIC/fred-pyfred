#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of file manager daemon.
"""

import os, sys, random, time
import pgdb
# corba stuff
from omniORB import CORBA, PortableServer
import ccReg, ccReg__POA


class FileManager_i (ccReg__POA.FileManager):
	"""
This class implements FileManager interface.
	"""
	def __init__(self, logger, db, conf):
		"""
	Initializer saves db (which is later used for opening database
	connection) and logger (used for logging).
		"""
		# ccReg__POA.FileManager doesn't have constructor
		self.db = db # db object for accessing database
		self.l = logger # syslog functionality

		# default configuration
		self.rootdir = "/var/tmp/filemanager"
		# Parse FileManager-specific configuration
		if conf.has_section("FileManager"):
			# tester email address
			try:
				rootdir = conf.get("FileManager", "rootdir")
				if rootdir:
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

	def __dbGetId(self, conn):
		"""
	Retrieves Id of save request from database - it is a value of primary
	key.
		"""
		cur = conn.cursor()
		cur.execute("SELECT nextval('files_id_seq')")
		id = cur.fetchone()[0]
		cur.close()
		return int(id)

	def __dbSaveMetadata(self, conn, id, name, path, mimetype, size):
		"""
	Inserts record about saved file in database.
		"""
		if not mimetype:
			mimetype = "NULL"# use default value from database if type is not set
		cur = conn.cursor()
		# insert new record
		cur.execute("INSERT INTO files (id, name, path, mimetype, filesize) "
				"VALUES (%d, %s, %s, %s, %d) " %
				(id, pgdb._quote(name), pgdb._quote(path), pgdb._quote(mimetype),
					size))
		cur.close()

	def __dbGetMetadata(self, conn, id):
		"""
	Retrieve record describing a file from database.
		"""
		cur = conn.cursor()
		# check that there is not such a name in database already
		cur.execute("SELECT name, path, mimetype, crdate, filesize FROM files "
				"WHERE id = %d" % id)
		if cur.rowcount == 0:
			raise ccReg.FileManager.IdNotFound()
		name, path, mimetype, crdate, filesize = cur.fetchone()
		cur.close()
		return name, path, mimetype, crdate, filesize

	def save(self, name, mimetype, data):
		"""
	Method from IDL interface. It saves data to a file and metadata to database.
		"""
		try:
			id = 0 # 0 means uninitialized (defined because of exceptions)
			fsize = len(data)
			self.l.log(self.l.INFO, "Save request received (name = %s, "
					"type = %s, data size = %d)" % (name, mimetype, fsize))
			# connect to database
			conn = self.db.getConn()
			# get unique ID of request from database
			id = self.__dbGetId(conn)

			# generate path to file
			curtime = time.gmtime()
			relpath = "%d/%d/%d/%d" % (curtime[0], curtime[1], curtime[2], id)
			abspath = os.path.join(self.rootdir, relpath)
			# write meta-data to database
			self.__dbSaveMetadata(conn, id, name, relpath, mimetype, fsize)
			# check accessibility of path
			dir = os.path.dirname(abspath)
			if os.path.isdir(dir):
				if not os.access(dir, os.R_OK | os.W_OK):
					self.l.log(self.l.ERR, "<%d> Directory '%s' is not r/w." %
							(id, dir))
					raise ccReg.FileManager.InternalError("Storage error")
			else:
				try:
					os.makedirs(dir, 0700)
				except Exception, e:
					self.l.log(self.l.ERR, "<%d> Cannot create directory '%s': "
							"%s" % (id, dir, e))
					raise ccReg.FileManager.InternalError("Storage error")
			# save data to file
			f = open(abspath, "wb")
			f.write(data)
			f.close()
			# commit changes in database
			conn.commit()
			self.db.releaseConn(conn)
			return id

		except ccReg.FileManager.InternalError, e:
			raise
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
			raise ccReg.FileManager.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception caugth: %s:%s" %
					(id, sys.exc_info()[0], e))
			raise ccReg.FileManager.InternalError("Unexpected error")

	def load(self, fileid):
		"""
	Method from IDL interface. It loads data from a file.
		"""
		try:
			# create request id
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> Load request received (file id = %d)."%
					(id, fileid))
			# connect to database
			conn = self.db.getConn()
			# get meta-info from database
			name, relpath, mimetype, crdate, size = self.__dbGetMetadata(conn,
					fileid)
			self.db.releaseConn(conn)

			abspath = os.path.join(self.rootdir, relpath)
			if not os.path.exists(abspath):
				self.l.log(self.l.ERR, "<%d> File '%s' does not exist" %
						(id, abspath))
				raise ccReg.FileManager.FileNotFound()
			if not os.access(abspath, os.R_OK):
				self.l.log(self.l.ERR, "<%d> File '%s' is not accessible" %
						(id, abspath))
				# we will return 'file not exist' in this case
				raise ccReg.FileManager.FileNotFound()
			# read file
			f = open(abspath, "rb")
			octets = f.read()
			f.close()
			return octets

		except ccReg.FileManager.FileNotFound, e:
			raise
		except ccReg.FileManager.IdNotFound, e:
			self.l.log(self.l.ERR, "<%d> ID '%d' does not exist in database." %
					(id, fileid))
			raise
		except ccReg.FileManager.InternalError, e:
			raise
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
			raise ccReg.FileManager.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception caugth: %s:%s" %
					(id, sys.exc_info()[0], e))
			raise ccReg.FileManager.InternalError("Unexpected error")

	def info(self, fileid):
		"""
	Method from IDL interface. It gets meta info about file.
		"""
		try:
			# create request id
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> Info request received (file id = %d)."%
					(id, fileid))
			# connect to database
			conn = self.db.getConn()
			# get meta-info from database
			name, relpath, mimetype, crdate, size = self.__dbGetMetadata(conn,
					fileid)
			self.db.releaseConn(conn)

			return ccReg.FileInfo(fileid, name, relpath, mimetype, crdate, size)

		except ccReg.FileManager.IdNotFound, e:
			self.l.log(self.l.ERR, "<%d> Id %d does not have record in database."
					% (id, fileid))
			raise
		except ccReg.FileManager.InternalError, e:
			raise
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
			raise ccReg.FileManager.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception caugth: %s:%s" %
					(id, sys.exc_info()[0], e))
			raise ccReg.FileManager.InternalError("Unexpected error")


def init(logger, db, nsref, conf, joblist, rootpoa):
	"""
Function which creates, initializes and returns servant FileManager.
	"""
	# Create an instance of Mailer_i and an Mailer object ref
	servant = FileManager_i(logger, db, conf)
	return servant, "FileManager"

