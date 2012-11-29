#!/usr/bin/python
import pgdb
from pyfred.idlstubs import Registry
from pyfred.registry.utils import normalize_spaces, make_params_private


class DatabaseCursor(object):
    "Create database cursor."
    INTERNAL_SERVER_ERROR = Exception

    def __init__(self, database, logger, internal_server_error):
        self.database = database
        self.logger = logger
        self.connection = None
        self.cursor = None
        self.INTERNAL_SERVER_ERROR = internal_server_error

    def __enter__(self):
        "Open database connection."
        try:
            self.connection = self.database.getConn()
            self.cursor = self.connection.cursor()
        except (pgdb.OperationalError, pgdb.DatabaseError, pgdb.InternalError), msg:
            self.logger.log(self.logger.ERROR, "Open connection and cursor. %s" % msg)
            raise self.INTERNAL_SERVER_ERROR
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        "End of database connection."
        self.cursor.close()
        self.database.releaseConn(self.connection)

    def execute(self, sql, params=None):
        "Execute SQL query."
        private_params = make_params_private(params)
        self.logger.log(self.logger.DEBUG, 'Execute "%s"; %s' % (normalize_spaces(sql), private_params))
        # InterfaceError (quote), OperationalError, DatabaseError (executemany)
        try:
            self.cursor.execute(sql, params)
        except (pgdb.OperationalError, pgdb.DatabaseError, pgdb.InternalError, pgdb.InterfaceError), msg:
            self.logger.log(self.logger.ERROR, 'cursor.excecute("%s", %s) %s' % (normalize_spaces(sql), private_params, msg))
            raise self.INTERNAL_SERVER_ERROR

    def fetchall(self, sql, params=None):
        "Return result of SQL query."
        self.execute(sql, params)
        try:
            return self.cursor.fetchall()
        except pgdb.DatabaseError, msg:
            self.logger.log(self.logger.ERROR, 'cursor.fetchall("%s", %s) %s' % (normalize_spaces(sql), make_params_private(params), msg))
            raise self.INTERNAL_SERVER_ERROR

    def fetchallstr(self, sql, params=None):
        "Return result of SQL query. All values are strings."
        record_set = []
        for row in self.fetchall(sql, params):
            record_set.append([str(column) for column in row])
        return record_set

    def getval(self, sql, params=None):
        "Return first column of first row."
        return self.fetchall(sql, params)[0][0] # [row][column]


class TransactionLevelRead(object):
    """
    Provide TRANSACTION ISOLATION LEVEL READ COMMITTED
    """
    def __init__(self, source, logger):
        self.source = source
        self.logger = logger

    def __enter__(self):
        "Start transaction"
        self.source.execute("START TRANSACTION ISOLATION LEVEL READ COMMITTED")
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        "End transaction."
        if exc_type is None:
            self.source.execute("COMMIT TRANSACTION")
        else:
            self.source.execute("ROLLBACK")
