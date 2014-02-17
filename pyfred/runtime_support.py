#!/usr/bin/python
"""
Classes required by runtime sctript or tests.

# Example of usage:

from pyfred.runtime_support import Logger, DB, CorbaRefs, getConfiguration
from pyfred.modules.domainbrowser import DomainBrowserServerInterface

CONFIGS = (...) # set path by setup.py

conf = getConfiguration(CONFIGS)
log = Logger("domainbrowser")
db = DB(conf.get("General", "dbhost"),
        conf.get("General", "dbport"),
        conf.get("General", "dbname"),
        conf.get("General", "dbuser"),
        conf.get("General", "dbpassword"))
corba_refs = CorbaRefs()
joblist = []

inst = DomainBrowserServerInterface(log, db, conf, joblist, corba_refs)
response = inst.getObjectRegistryId("domain", "fred.cz")

>>> type(response), response
(<type 'int'>, 33)
"""
import sys
import logging
import logging.handlers
import pgdb
import ConfigParser



class Logger(object):
    """
    This class encapsulates logging module functionality. Logger name is set
    in object initialization. Logging module and root logger should be
    configured before use.
    NOTE: refactored to use standard python logging module (previously
    only syslog function) with minimum code changes.
    """
    LEVELS = {"emerg":    logging.CRITICAL,
              "alert":    logging.CRITICAL,
              "critical": logging.CRITICAL,
              "error":    logging.ERROR,
              "warning":  logging.WARNING,
              "notice":   logging.INFO,
              "info":     logging.INFO,
              "debug":    logging.DEBUG}

    EMERG = LEVELS["emerg"]
    ALERT = LEVELS["alert"]
    CRIT = LEVELS["critical"]
    CRITICAL = LEVELS["critical"]
    ERR = LEVELS["error"]
    ERROR = LEVELS["error"]
    WARNING = LEVELS["warning"]
    NOTICE = LEVELS["notice"]
    INFO = LEVELS["info"]
    DEBUG = LEVELS["debug"]


    def __init__(self, prefix):
        """
        Initialize the prefix which will be used for every message logged
        through this Logger.
        """
        self._log = logging.getLogger(prefix)

    def log(self, level, msg, ident=None):
        """
        Wrapper around logging.Logger.log method.
        """
        if ident is not None:
            msg = "IID:%s %s" % (ident, msg) # IID is Instance ID
        self._log.log(level, msg)


class DB(object):
    """
    This class provides methods usefull when working with database.
    """

    def __init__(self, dbhost, dbport, dbname, dbuser, dbpassword):
        """
        Method initializes data needed for database access.
        """
        self.host = dbhost
        self.port = dbport
        self.dbname = dbname
        self.user = dbuser
        self.password = dbpassword

    def getConn(self):
        """
        Obtain connection to database.
        """
        return pgdb.connect(host=self.host + ":" + self.port,
                database=self.dbname, user=self.user,
                password=self.password)

    def releaseConn(self, conn):
        """
        Release connection obtained in getConn() method.
        """
        if conn:
            conn.close()


class CorbaRefs(object):
    """
    This class was created for passing corba parameters to modules during
    initialization. It is very important that modification to instance of
    this class are visible to modules, which obtained reference to instance
    before the modifications took place.
    """
    nsref = None
    rootpoa = None


def getConfiguration(configs):
    """
    Get configuration from file. The configuration files are given as a list in
    parameter. The function automatically provides default values for directives
    not defined by configuration file. If none of the configuration files
    exists, all directives will contain default values.
    """
    # set defaults
    confparser = ConfigParser.SafeConfigParser({
            "dbhost":"localhost",
            "dbname":"fred",
            "dbport":"5432",
            "dbuser":"fred",
            "dbpassword":"",
            "modules":"mailer techcheck filemanager genzone",
            "nscontext":"fred",
            "nshost":"localhost",
            "nsport":"2809",
            "loghandler":"syslog",
            "loglevel":"info",
            "logfacility":"local1",
            "logfilename":"var/log/pyfred.log",
            "host":"",
            "port":"2225"})
    # read configuration file
    for cfile in configs:
        try:
            if len(confparser.read(cfile)) == 1:
                sys.stdout.write("File %s used as config file\n" % cfile)
                break
        except ConfigParser.MissingSectionHeaderError, e:
            sys.stderr.write("Error in configuration file '%s': %s\n" %
                    (cfile, e))
            return None
        except ConfigParser.ParsingError, e:
            sys.stderr.write("Error in configuration file '%s': %s\n" %
                    (cfile, e))
            return None
    # create basic section general if it does not exist
    if not confparser.has_section("General"):
        confparser.add_section("General")
    return confparser


def init_logger(loghandler, loglevel, logfacility, logfilename, logger_name='', detach=False):
    "Init Logger."
    # disable console log when we are going to daemonize server
    if loghandler == "console" and detach:
        sys.stderr.write("Warning: unable to have console logger when"
                " server is going to daemonize, switching to syslog."
                " (you can adjust this settings in configuration)\n")
        loghandler = "syslog"

    # test if syslog facility is valid
    if loghandler == "syslog":
        logfacility = logging.handlers.SysLogHandler.facility_names[logfacility]

    # try to set proper handler and formatting style
    handlers = {"console":
                    {"handler": [logging.StreamHandler, {}],
                     "formatter": logging.Formatter("%(asctime)s %(levelname)-8s %(name)s - %(message)s")},
                "file":
                    {"handler": [logging.FileHandler, {"filename": logfilename }],
                     "formatter": logging.Formatter("%(asctime)s %(levelname)-8s %(name)s - %(message)s")},
                "syslog":
                    {"handler": [logging.handlers.SysLogHandler,
                                 {"address": "/dev/log", "facility": logfacility}],
                     "formatter": logging.Formatter("%(name)s - %(message)s")}}

    log_conf = handlers[loghandler]
    handler = log_conf["handler"][0](**log_conf["handler"][1])
    handler.setFormatter(log_conf["formatter"])

    # if file log get its file descriptor
    if loghandler == "file":
        logfd = handler.stream.fileno()
    else:
        logfd = None

    logging.getLogger(logger_name).addHandler(handler)
    logging.getLogger(logger_name).setLevel(Logger.LEVELS[loglevel])
    return logfd