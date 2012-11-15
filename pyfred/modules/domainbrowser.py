#!/usr/bin/python
import ConfigParser
# pyfred
from pyfred.idlstubs import Registry__POA



class DomainBrowserServerInterface(Registry__POA.DomainBrowser.Server):
    """
    This class implements DomainBrowser interface.
    """

    def __init__(self, logger, db, conf, joblist, corba_refs):
        """
        Initializer saves db (which is later used for opening database
        connection) and logger (used for logging).
        """
        self.db = db # db connection string
        self.logger = logger # syslog functionality
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

        self.logger.log(self.logger.DEBUG, "self.limits=%s" % self.limits)



def init(logger, db, conf, joblist, corba_refs):
    """
    Function which creates, initializes and returns servant DomainBrowser.
    """
    servant = DomainBrowserServerInterface(logger, db, conf, joblist, corba_refs)
    return servant, "DomainBrowser"
