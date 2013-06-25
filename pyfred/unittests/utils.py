#!/usr/bin/env python
import os
import re
import hashlib
import shutil
import pgdb
import _pg
import yaml
from copy import deepcopy
# pyfred
from pyfred.runtime_support import DB



def provide_data(name, data=None, subfolder='', track_traffic=False):
    "Load or save data and return result."
    path = os.path.join(os.path.dirname(__file__), subfolder, "%s.yaml" % name)

    if track_traffic:
        # set unformat for query values
        if isinstance(data, dict):
            for key, vals in data.items():
                if isinstance(vals, dict) and "query" in vals:
                    vals["query"] = LiteralUnicode(vals["query"])
        with open(path, "w") as handle:
            yaml.dump(data, handle)
        return data

    with open(path) as handle:
        data = yaml.load(handle)

    return data



def backup_subfolder(subfolder):
    "Backup data folder."
    fldname = lambda path, pos: "%s.bak%d" % (path, pos)
    path = os.path.join(os.path.dirname(__file__), subfolder)
    pos = 1
    # find free subfolder name
    while os.path.isdir(fldname(path, pos)):
        pos += 1
    shutil.move(path, fldname(path, pos))
    # create new subfolder
    os.mkdir(path)



class MockPgdbCursor(pgdb.pgdbCursor):
    "Mock Cursor Object."

    def __init__(self, dbcnx):
        super(MockPgdbCursor, self).__init__(dbcnx)
        self._data_path = os.path.join(os.path.dirname(__file__), self._dbcnx.data_folder_name)
        self._cache_query = None

    def execute(self, operation, params=None):
        "Prepare and execute a database operation (query or command)."
        self._cache_query = dict(query=operation, params=params)
        if self._dbcnx.use_db or self._dbcnx.track_traffic:
            # do real database access only in tracking mode; otherwise read from dbdata storage
            super(MockPgdbCursor, self).execute(operation, params)

    def fetchall(self):
        """Fetch all (remaining) rows of a query result."""
        query = self._cache_query["query"].strip()
        params = self._cache_query["params"]
        query_code = hashlib.md5(re.sub("\s+", " ", query).lower()).hexdigest()
        params_code = hashlib.md5(u"%s" % params).hexdigest()

        if self._dbcnx.use_db or self._dbcnx.track_traffic:
            response = super(MockPgdbCursor, self).fetchall()
            if self._dbcnx.track_traffic:
                # create data dict
                if query_code not in self._dbcnx.db_data:
                    self._dbcnx.db_data[query_code] = dict(query=query, values={})
                if params_code not in self._dbcnx.db_data[query_code]["values"]:
                    self._dbcnx.db_data[query_code]["values"][params_code] = dict(data=params, response=[])
                if self._dbcnx.stage_pos >= len(self._dbcnx.db_data[query_code]["values"][params_code]["response"]):
                    self._dbcnx.db_data[query_code]["values"][params_code]["response"].append([])

                self._dbcnx.db_data[query_code]["values"][params_code]["response"][self._dbcnx.stage_pos] = deepcopy(response)

                # Deliberately corrupt data for testing exceptions.

                # TestDomainBrowserContact.test_045 -  detail of contact BOB
                if query_code == "f88ac281b0e5a8afe2febb920b55add0" and params_code == "26bcda2e0343f3f2d86597156d1df6d8":
                    self._dbcnx.db_data[query_code]["values"][params_code]["response"][self._dbcnx.stage_pos] = [deepcopy(response), deepcopy(response)]

        else:
            response = self._dbcnx.db_data[query_code]["values"][params_code]["response"][self._dbcnx.stage_pos]

        return response



class MockPgdbCnx(pgdb.pgdbCnx):
    "Mock Connection Object."

    data_folder_name = "dbdata"
    refs_folder_name = "refdata"

    # True - store SQL query and response info files.
    track_traffic = False
    # True - overwrite existing files with query and response.
    overwrite_existing = False
    # Database stage position is a data snapshot between any updates.
    stage_pos = 0

    def cursor(self):
        "Return a new Cursor Object using the connection."
        if self._cnx:
            try:
                return MockPgdbCursor(self)
            except Exception:
                raise _pg.OperationalError("invalid connection")
        else:
            raise _pg.OperationalError("connection has been closed")


class MockDB(DB):
    "Mock database."
    refs_folder_name = "refdata"
    db_data = None
    use_db = False
    track_traffic = False
    overwrite_existing = False
    stage_pos = 0


    def getConn(self):
        "Obtain connection to database."
        if self.use_db or self.track_traffic:
            #print "CONNECTION: %s:%s -U %s %s (pass: %s)" % (self.host, self.port, self.user, self.dbname, self.password)
            contx = connect(host=self.host + ":" + self.port,
                            database=self.dbname, user=self.user,
                            password=self.password)
        else:
            contx = connect() # do not use db connection

        contx.db_data = self.db_data
        contx.use_db = self.use_db
        contx.track_traffic = self.track_traffic
        contx.overwrite_existing = self.overwrite_existing
        contx.stage_pos = self.stage_pos
        contx.refs_folder_name = self.refs_folder_name
        return contx


_connect_ = _pg.connect

def connect(dsn=None,
        user=None, password=None,
        host=None, database=None):
    """Connects to a database."""
    # first get params from DSN
    dbport = -1
    dbhost = ""
    dbbase = ""
    dbuser = ""
    dbpasswd = ""
    dbopt = ""
    dbtty = ""
    try:
        params = dsn.split(":")
        dbhost = params[0]
        dbbase = params[1]
        dbuser = params[2]
        dbpasswd = params[3]
        dbopt = params[4]
        dbtty = params[5]
    except (AttributeError, IndexError, TypeError):
        pass

    # override if necessary
    if user is not None:
        dbuser = user
    if password is not None:
        dbpasswd = password
    if database is not None:
        dbbase = database
    if host is not None:
        try:
            params = host.split(":")
            dbhost = params[0]
            dbport = int(params[1])
        except (AttributeError, IndexError, TypeError, ValueError):
            pass

    # empty host is localhost
    if dbhost == "":
        dbhost = None
    if dbuser == "":
        dbuser = None

    # open the connection
    cnx = _connect_(dbbase, dbhost, dbport, dbopt,
        dbtty, dbuser, dbpasswd)
    return MockPgdbCnx(cnx)



class LiteralUnicode(unicode):
    "Literal unicode class"

def literal_unicode_representer(dumper, data):
    return dumper.represent_scalar(u'tag:yaml.org,2002:str', data, style='|')

yaml.add_representer(LiteralUnicode, literal_unicode_representer)
