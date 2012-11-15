#!/usr/bin/python
import ConfigParser
# pyfred
from pyfred.idlstubs import Registry, Registry__POA
from pyfred.utils import DatabaseCursor



class DomainBrowserServerInterface(Registry__POA.DomainBrowser.Server):
    """
    This class implements DomainBrowser interface.
    """

    def __init__(self, logger, database, conf, joblist, corba_refs):
        """
        Initializer saves db (which is later used for opening database
        connection) and logger (used for logging).
        """
        self.database = database # db connection string
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

        self.logger.log(self.logger.DEBUG, "Object initialized")


    def getDomainListMeta(self):
        """Return the Domain list column names.

        enum RecordType {
            TEXT,
            DATE,
            BOOL,
            INT
        };
        struct RecordSetMeta
        {
            sequence<string> column_names;
            sequence<RecordType> data_types; // for sorting in frontend
        };
        """
        self.logger.log(self.logger.DEBUG, "Call Server.getDomainListMeta()")

        # prepare record types into dictionnary:
        rtp = dict([(inst._n, inst) for inst in Registry.DomainBrowser.RecordType._items])

        column_names, data_types = [], []
        for name, value in (
                            ("domain_name",      "TEXT"),
                            ("domain_state",     "TEXT"),
                            ("next_state",       "TEXT"),
                            ("next_state_date",  "DATE"),
                            ("dnssec_available", "BOOL"),
                            ("your_role",        "TEXT"),
                            ("registrar_handle", "TEXT"),
                            ("blocked_update",   "BOOL"),
                            ("blocked_transfer", "BOOL"),
                        ):
            column_names.append(name)
            data_types.append(rtp[value])

        return Registry.DomainBrowser.RecordSetMeta(column_names, data_types)


    def getDomainList(self, user, sort_by):
        """
        RecordSet getDomainList(
                in RegistryObject user,
                in SortSpec sort_by
            ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);

        typedef string RegistryObject;
        struct SortSpec
        {
            string field;
            boolean desc;
            long limit;
            long offset;
        };
        """
        self.logger.log(self.logger.DEBUG, "Call Server.getDomainList(user=%s, sort_by=%s)" % (user, sort_by))

        # TODO: rethrow_translate_exceptions_handler - Registry.DomainBrowser.INCORRECT_USAGE

        with DatabaseCursor(self.database, self.logger, Registry) as cursor:
            response_user = cursor.fetchall("SELECT object_registry.id, object_registry.name FROM object_registry "
                                   "LEFT JOIN contact ON object_registry.id = contact.id "
                                   "WHERE object_registry.name = %s",
                                   user)
            # data: [['ID', 'CONTACT_HANDLE']]
            if not len(response_user):
                raise Registry.DomainBrowser.USER_NOT_EXISTS

        user_id = response_user[0][0]
        self.logger.log(self.logger.DEBUG, "User ID of handle '%s' is %s." % (user, user_id))

        # TODO: a list of domains...
        return []



def init(logger, db, conf, joblist, corba_refs):
    """
    Function which creates, initializes and returns servant DomainBrowser.
    """
    servant = DomainBrowserServerInterface(logger, db, conf, joblist, corba_refs)
    return servant, "DomainBrowser"
