#!/usr/bin/python
import ConfigParser
from datetime import datetime, timedelta
# pyfred
from pyfred.idlstubs import Registry, Registry__POA
# objects
from pyfred.registry.interface import ContactInterface, DomainInterface, NssetInterface, KeysetInterface



class DomainBrowserServerInterface(Registry__POA.DomainBrowser.Server, ContactInterface, DomainInterface, NssetInterface, KeysetInterface):
    """
    This class implements DomainBrowser interface.
    """
    INTERNAL_SERVER_ERROR = Registry.DomainBrowser.INTERNAL_SERVER_ERROR

    def __init__(self, logger, database, conf, joblist, corba_refs):
        """
        Initializer saves db (which is later used for opening database
        connection) and logger (used for logging).
        """
        self.database = database # db connection string
        self.logger = logger # syslog functionality
        self.cursor = None # initialized by @furnish_database_cursor_m decorator
        self.corba_refs = corba_refs
        self.limits = dict(list_domains=100, list_nssets=100, list_keysets=100)

        # config
        section = "DomainBrowser"
        if conf.has_section(section):
            for key in (self.limits.keys()):
                try:
                    self.limits[key] = conf.getint(section, "%s_limit" % key)
                except ConfigParser.NoOptionError, msg:
                    pass # use default defined above when the limit is not in the config

        self.logger.log(self.logger.DEBUG, "Object initialized")



def init(logger, db, conf, joblist, corba_refs):
    """
    Function which creates, initializes and returns servant DomainBrowser.
    """
    servant = DomainBrowserServerInterface(logger, db, conf, joblist, corba_refs)
    return servant, "DomainBrowser"
