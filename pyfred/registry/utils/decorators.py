#!/usr/bin/python
from pyfred.registry.utils.cursors import DatabaseCursor
from pyfred.registry.utils import normalize_and_check_handle


def furnish_database_cursor_m(interface_function):
    """
    Decorator furnishes the interface object by the open database cursor.
    Closes cursor and db connections even if the exception occurs.
    """

    def wrapper(self, *args, **kwargs):
        "Decorate an interface class method."
        #self.logger.log(self.logger.DEBUG, '@furnish_database_cursor_m BEGIN') # DEBUG ONLY
        with DatabaseCursor(self.database, self.logger, self.INTERNAL_SERVER_ERROR) as cursor:
            self.cursor = cursor
            retval = interface_function(self, *args, **kwargs)
            self.cursor = None
        #self.logger.log(self.logger.DEBUG, '@furnish_database_cursor_m END') # DEBUG ONLY
        return retval

    return wrapper


def normalize_handle_m(interface_function):
    """
    Normalize handle and check the validity.
    Invalid handle raise Registry.DomainBrowser.INCORRECT_USAGE.
    """

    def wrapper(self, *args, **kwargs):
        "Decorate an interface class method."
        if len(args):
            attrs = list(args)
            attrs[0] = normalize_and_check_handle(self.logger, attrs[0]) # raise INCORRECT_USAGE
            args = tuple(attrs)
        elif "handle" in kwargs:
            kwargs["handle"] = normalize_and_check_handle(self.logger, kwargs["handle"]) # raise INCORRECT_USAGE

        return interface_function(self, *args, **kwargs)

    return wrapper
