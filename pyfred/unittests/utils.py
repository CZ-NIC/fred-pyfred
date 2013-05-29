#!/usr/bin/env python
import os
import hashlib
import pgdb
import _pg
import yaml
# pyfred
from pyfred.runtime_support import DB



class MockPgdbCursor(pgdb.pgdbCursor):
    "Mock Cursor Object."
    query_folder_name = "dbdata"

    track_traffic = False # True - store SQL query and response info files.
    overwrite_existing = False # True - overwrite existing files with query and response.

    def __init__(self, dbcnx):
        super(MockPgdbCursor, self).__init__(dbcnx)
        self._data_path = os.path.join(os.path.dirname(__file__), self.query_folder_name)
        self._query_code = None

    def _store_data(self, data, filename):
        "Store data into filename."
        if self.overwrite_existing or (not self.overwrite_existing and not os.path.exists(filename)):
            with open(filename, "w") as handle:
                yaml.dump(data, handle)

    def _load_data(self, filename):
        "Load data from file."
        data = None
        with open(filename) as handle:
            data = yaml.load(handle)
        return data

    def execute(self, operation, params=None):
        "Prepare and execute a database operation (query or command)."
        query = operation.strip()
        self._query_code = hashlib.md5(query).hexdigest()
        if self.track_traffic:
            filename = os.path.join(self._data_path, "%s.query.yaml" % self._query_code)
            self._store_data(dict(query=LiteralUnicode(query), params=params), filename)
        super(MockPgdbCursor, self).execute(operation, params)

    def fetchall(self):
        """Fetch all (remaining) rows of a query result."""
        filename = os.path.join(self._data_path, "%s.response.yaml" % self._query_code)
        if self.track_traffic:
            response = super(MockPgdbCursor, self).fetchall()
            self._store_data(response, filename)
        else:
            response = self._load_data(filename)
        return response



class MockPgdbCnx(pgdb.pgdbCnx):
    "Mock Connection Object."

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

    def getConn(self):
        "Obtain connection to database."
        return connect(host=self.host + ":" + self.port,
                database=self.dbname, user=self.user,
                password=self.password)


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
