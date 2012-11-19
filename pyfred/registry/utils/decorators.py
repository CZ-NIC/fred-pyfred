#!/usr/bin/python
from pyfred.registry.utils.cursors import DatabaseCursor


def furnish_database_cursor_m(interface_function):
    """
    Decorator furnishes the interface object by the open database cursor.
    Closes cursor and db connections even if the exception occurs.
    """

    def wrapper(self, *args, **kwargs):
        "Decorate an interface class method."
        with DatabaseCursor(self.database, self.logger, self.INTERNAL_SERVER_ERROR) as cursor:
            self.cursor = cursor
            retval = interface_function(self, *args, **kwargs)
            self.cursor = None
        return retval

    return wrapper