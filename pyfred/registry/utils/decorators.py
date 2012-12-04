#!/usr/bin/python
from pyfred.registry.utils.cursors import DatabaseCursor, TransactionLevelRead


def furnish_database_cursor_m(interface_function):
    """
    Decorator furnishes the interface object by the open database cursor.
    Closes cursor and db connections even if the exception occurs.
    """

    def wrapper(self, *args, **kwargs):
        "Decorate an interface class method."
        retval = None
        with DatabaseCursor(self.database, self.logger, self.INTERNAL_SERVER_ERROR) as source:
            self.source = source
            retval = interface_function(self, *args, **kwargs)
            self.source = None
        return retval

    return wrapper


def transaction_isolation_level_read_m(interface_function):
    """
    Call function inside transaction.
    """
    def wrapper(self, *args, **kwargs):
        "Decorate an interface class method."
        retval = None
        with TransactionLevelRead(self.source, self.logger) as transaction:
            retval = interface_function(self, *args, **kwargs)
        return retval

    return wrapper
