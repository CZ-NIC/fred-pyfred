#!/usr/bin/python
import threading
import random
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.utils.cursors import DatabaseCursor, TransactionLevelRead
from pyfred.registry.utils import get_exception


def furnish_database_cursor_m(interface_function):
    """
    Decorator furnishes the interface object by the open database cursor.
    Closes cursor and db connections even if the exception occurs.
    """

    def wrapper(self, *args, **kwargs):
        "Decorate an interface class method."
        retval = None
        with DatabaseCursor(self.database, self.logger, self.INTERNAL_SERVER_ERROR) as source:
            self.browser.threading_local.source = source
            retval = interface_function(self, *args, **kwargs)
            self.browser.threading_local.source = None
        return retval

    return wrapper


#def verify_contact_m(interface_function):
#    "Verify if contact ID and 'handle' exists."
#    def wrapper(self, *args, **kwargs):
#        self._verify_user_contact(args[0])
#        return interface_function(self, *args, **kwargs)
#    return wrapper


def transaction_isolation_level_read_m(interface_function):
    """
    Call function inside transaction.
    """
    def wrapper(self, *args, **kwargs):
        "Decorate an interface class method."
        retval = None
        with TransactionLevelRead(self.browser.threading_local.source, self.logger) as transaction:
            retval = interface_function(self, *args, **kwargs)
        return retval

    return wrapper


EXCEPTION_NAMES = ("INTERNAL_SERVER_ERROR", "USER_NOT_EXISTS", "OBJECT_NOT_EXISTS",
                   "INCORRECT_USAGE", "ACCESS_DENIED", "OBJECT_BLOCKED")


def log_not_corba_user_exceptions(interface_function):
    """
    Catch all exceptions and raise INTERNAL_SERVER_ERROR
    """
    def wrapper(self, *args, **kwargs):
        "Decorate an interface class method."
        self.threading_local = threading.local()
        ident = threading.current_thread().ident
        if ident is None:
            # remove "0x" from hex value
            code = "r%s" % ("%#014x" % random.randint(0, 0x7fffffffffff))[2:]
        else:
            code = "t%s" % ("%#014x" % ident)[2:] # remove "0x" from hex value
        self.threading_local.thread_ident = code
        self.logger.thread_ident = code # runtime_support.Logger() starts to write thread ident into log
        try:
            return interface_function(self, *args, **kwargs)
        except Exception, msg:
            if msg.__class__.__name__ in EXCEPTION_NAMES:
                raise msg

            self.logger.log(self.logger.CRIT, get_exception())
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

    return wrapper
