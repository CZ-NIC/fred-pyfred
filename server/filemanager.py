#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
Code of file manager daemon.
"""

import os, sys, random, time, ConfigParser
import pgdb
# corba stuff
from omniORB import CORBA, PortableServer
import ccReg, ccReg__POA
from pyfred_util import isInfinite


class FileManager_i (ccReg__POA.FileManager):
	"""
This class implements FileManager interface.
	"""
	def __init__(self, logger, db, conf, joblist, rootpoa):
		"""
	Initializer saves db (which is later used for opening database
	connection) and logger (used for logging).
		"""
		# ccReg__POA.FileManager doesn't have constructor
		self.db = db # db object for accessing database
		self.l = logger # syslog functionality
		self.search_objects = [] # list of created search objects
		self.rootpoa = rootpoa # poa for creating new objects

		# default configuration
		self.rootdir = "/var/tmp/filemanager"
		self.idletreshold = 3600
		self.checkperiod = 60
		# Parse FileManager-specific configuration
		if conf.has_section("FileManager"):
			try:
				rootdir = conf.get("FileManager", "rootdir")
				if rootdir:
					if not os.path.isabs(rootdir):
						self.l.log(self.l.ERR, "rootdir must be absolute path")
						raise Exception()
					self.rootdir = rootdir
			except ConfigParser.NoOptionError, e:
				pass
			# check period
			try:
				checkperiod = conf.get("FileManager", "checkperiod")
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
				idletreshold = conf.get("FileManager", "idletreshold")
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

		# try to create rootdir if it does not exist
		if os.path.isdir(self.rootdir):
			if not os.access(self.rootdir, os.R_OK | os.W_OK):
				raise Exception("Directory '%s' is not r/w: " % self.rootdir)
		else:
			try:
				os.makedirs(self.rootdir, 0700)
			except Exception, e:
				raise Exception("Cannot create directory for file manager: %s"
						% e)

		# schedule regular cleanup
		joblist.append( { "callback":self.__search_cleaner, "context":None,
			"period":self.checkperiod, "ticks":1 } )
		self.l.log(self.l.DEBUG, "Object initialized")

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

	def createSearchObject(self, filter):
		"""
	Method creates object which makes accessible results of a search.
		"""
		try:
			# create request id
			id = random.randint(1, 9999)
			self.l.log(self.l.INFO, "<%d> Search request received." % id)

			# construct SQL query coresponding to filter constraints
			conditions = []
			if filter.id != -1:
				conditions.append("files.id = %d" % filter.id)
			if filter.name:
				conditions.append("files.name = %s" % pgdb._quote(filter.name))
			if filter.path:
				conditions.append("files.path = %s" % pgdb._quote(filter.path))
			if filter.mimetype:
				conditions.append("files.mimetype = %s" %
						pgdb._quote(filter.mimetype))
			fromdate = filter.crdate._from
			if not isInfinite(fromdate):
				conditions.append("files.crdate > '%d-%d-%d %d:%d:%d'" %
						(fromdate.date.year,
						fromdate.date.month,
						fromdate.date.day,
						fromdate.hour,
						fromdate.minute,
						fromdate.second))
			todate = filter.crdate.to
			if not isInfinite(todate):
				conditions.append("files.crdate < '%d-%d-%d %d:%d:%d'" %
						(todate.date.year,
						todate.date.month,
						todate.date.day,
						todate.hour,
						todate.minute,
						todate.second))
			if len(conditions) == 0:
				cond = ""
			else:
				cond = "WHERE (%s)" % conditions[0]
				for condition in conditions[1:]:
					cond += " AND (%s)" % condition
			self.l.log(self.l.DEBUG, "<%d> Search WHERE clause is: %s" %
					(id, cond))

			# connect to database
			conn = self.db.getConn()
			cur = conn.cursor()

			cur.execute("SELECT id, name, path, mimetype, crdate, filesize FROM "
					"files %s" % cond)
			# get meta-info from database
			self.db.releaseConn(conn)

			self.l.log(self.l.DEBUG, "<%d> Number of records in cursor: %d" %
					(id, cur.rowcount))

			# Create an instance of FileSearch_i and an FileSearch object ref
			searchobj = FileSearch_i(id, cur, self.l)
			self.search_objects.append(searchobj)
			searchref = self.rootpoa.servant_to_reference(searchobj)
			return searchref

		except ccReg.FileManager.InternalError, e:
			raise
		except pgdb.DatabaseError, e:
			self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
			raise ccReg.FileManager.InternalError("Database error")
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception caugth: %s:%s" %
					(id, sys.exc_info()[0], e))
			raise ccReg.FileManager.InternalError("Unexpected error")


class FileSearch_i (ccReg__POA.FileSearch):
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

	def getNext(self, count):
		"""
	Get result of search.
		"""
		try:
			self.l.log(self.l.INFO, "<%d> Get search result request received." %
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
				raise ccReg.FileSearch.NotActive()

			# update last use timestamp
			self.lastuse = time.time()

			# get 'count' results
			filelist = []
			for i in range(count):
				if not self.lastrow:
					break
				(id, name, path, mimetype, crdate, filesize) = self.lastrow
				self.lastrow = self.cursor.fetchone()
				filelist.append( ccReg.FileInfo(id, name, path, mimetype,
					crdate, filesize) )

			self.l.log(self.l.DEBUG, "<%d> Number of records returned: %d." %
					(self.id, len(filelist)))
			return filelist

		except ccReg.FileSearch.NotActive, e:
			raise
		except Exception, e:
			self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
					(self.id, sys.exc_info()[0], e))
			raise ccReg.FileSearch.InternalError("Unexpected error")

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
			raise ccReg.FileSearch.InternalError("Unexpected error")


def init(logger, db, nsref, conf, joblist, rootpoa):
	"""
Function which creates, initializes and returns servant FileManager.
	"""
	# Create an instance of FileManager_i and an FileManager object ref
	servant = FileManager_i(logger, db, conf, joblist, rootpoa)
	return servant, "FileManager"

