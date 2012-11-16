#!/usr/bin/python
import pgdb
from pyfred.idlstubs import Registry


class DatabaseCursor(object):
    "Create database cursor."

    def __init__(self, database, logger):
        self.database = database
        self.logger = logger
        self.connection = None
        self.cursor = None

    def __enter__(self):
        "Open database connection."
        try:
            self.connection = self.database.getConn()
            self.cursor = self.connection.cursor()
        except (pgdb.OperationalError, pgdb.DatabaseError, pgdb.InternalError), msg:
            self.logger.log(self.logger.ERROR, "Open connection and cursor. %s" % msg)
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        "End of database connection."
        self.cursor.close()
        self.database.releaseConn(self.connection)

    def execute(self, sql, *params):
        "Execute SQL query."
        self.logger.log(self.logger.DEBUG, 'Execute "%s" %s' % (sql, params))
        # InterfaceError (quote), OperationalError, DatabaseError (executemany)
        try:
            self.cursor.execute(sql, params)
        except (pgdb.OperationalError, pgdb.DatabaseError, pgdb.InternalError, pgdb.InterfaceError), msg:
            self.logger.log(self.logger.ERROR, 'cursor.excecute("%s", %s) %s' % (sql, params, msg))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

    def fetchall(self, sql, *params):
        "Return result of SQL query."
        self.execute(sql, params)
        try:
            return self.cursor.fetchall()
        except pgdb.DatabaseError, msg:
            self.logger.log(self.logger.ERROR, 'cursor.fetchall("%s", %s) %s' % (sql, params, msg))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

    def fetchallstr(self, sql, *params):
        "Return result of SQL query. All values are strings."
        record_set = []
        for row in self.fetchall(sql, params):
            record_set.append([str(column) for column in row])
        return record_set
