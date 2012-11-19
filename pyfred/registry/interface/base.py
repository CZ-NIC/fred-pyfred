#!/usr/bin/python
from pyfred.idlstubs import Registry


class BaseInterface(object):
    "Base interface object."
    INTERNAL_SERVER_ERROR = Registry.DomainBrowser.INTERNAL_SERVER_ERROR
    cursor = None # initialized by @furnish_database_cursor_m decorator
