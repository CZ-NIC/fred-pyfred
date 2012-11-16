#!/usr/bin/python
import ConfigParser
from datetime import datetime, timedelta
# pyfred
from pyfred.idlstubs import Registry, Registry__POA
from pyfred.utils.cursors import DatabaseCursor
from pyfred.utils.registry import check_handle_format
from pyfred.utils.fredconst import DOMAIN_ROLE



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


    def getDomainList(self, handle, sort_by):
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
        self.logger.log(self.logger.DEBUG, 'Call Server.getDomainList(handle="%s", sort_by=%s)' % (handle, sort_by))

        handle = handle.upper()
        check_handle_format(self.logger, handle) # Registry.DomainBrowser.INCORRECT_USAGE

        with DatabaseCursor(self.database, self.logger) as cursor:
            response_user = cursor.fetchall("SELECT object_registry.id, object_registry.name FROM object_registry "
                                   "LEFT JOIN contact ON object_registry.id = contact.id "
                                   "WHERE object_registry.name = %(handle)s",
                                   dict(handle=handle))
            # data: [[ID, 'CONTACT_HANDLE']]
            if not len(response_user):
                raise Registry.DomainBrowser.USER_NOT_EXISTS

            contact_id = response_user[0][0]
            self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, handle))

            enum_parameters = dict(cursor.fetchall("SELECT name, val FROM enum_parameters"))
            #self.logger.log(self.logger.DEBUG, "enum_parameters = %s" % enum_parameters) # TEST

            domain_list = []
            REGID, DOMAIN_NAME, REG_HANDLE, EXDATE, REGISTRANT, DNSSEC = range(6)

            for domain_row in cursor.fetchall("""
                        SELECT
                            object_registry.id,
                            object_registry.name,
                            registrar.handle,
                            domain.exdate,
                            domain.registrant,
                            dnssec.digest IS NULL
                        FROM object_registry
                        LEFT JOIN domain ON object_registry.id = domain.id
                        LEFT JOIN domain_contact_map ON domain_contact_map.domainid = domain.id
                                  AND domain_contact_map.role = %(role_id)d
                        LEFT JOIN object_history ON object_history.historyid = object_registry.historyid
                        LEFT JOIN dnssec ON dnssec.domainid = domain.id
                        LEFT JOIN registrar ON registrar.id = object_history.clid
                        WHERE domain_contact_map.contactid = %(contact_id)d
                            OR domain.registrant = %(contact_id)d
                        ORDER BY domain.exdate DESC
                        LIMIT %(limit)d
                        """,
                        dict(contact_id=contact_id, role_id=DOMAIN_ROLE["admin"], limit=self.limits["list_domains"])):
                # row: [33, 'fred.cz', 'REG-FRED_A', '2015-10-12', 30, True]
                domain_states = []
                for row_states in cursor.fetchall("""
                        SELECT
                            enum_object_states.name
                        FROM object_registry
                        LEFT JOIN object_state ON object_state.object_id = object_registry.id
                            AND (object_state.valid_from < NOW()
                            AND (object_state.valid_to IS NULL OR object_state.valid_to > NOW()))
                        LEFT JOIN enum_object_states ON enum_object_states.id = object_state.state_id
                        WHERE object_registry.id = %(regid)d""", dict(regid=domain_row[REGID])):
                    if row_states[0]:
                        domain_states.append(row_states[0])

                # expiration_dns_protection_period, expiration_registration_protection_period
                exdate = datetime.strptime(domain_row[EXDATE], '%Y-%m-%d').date()
                outzone_date = exdate + timedelta(days=int(enum_parameters["expiration_dns_protection_period"]))
                delete_date  = exdate + timedelta(days=int(enum_parameters["object_registration_protection_period"]))
                #self.logger.log(self.logger.DEBUG, 'Contact %d "%s": exdate=%s; outzone_date=%s; delete_date=%s' % (contact_id, handle, exdate, outzone_date, delete_date))

                # resolve doamin state
                next_state, next_state_date = "", ""
                today = datetime.today().date()
                if today < exdate:
                    next_state, next_state_date = "expired", exdate
                elif exdate <= today and today < outzone_date:
                    next_state, next_state_date = "outzone", outzone_date
                elif outzone_date <= today and today < delete_date:
                    next_state, next_state_date = "deleteCandidate", delete_date
                elif delete_date <= today:
                    next_state, next_state_date = "N/A", ""

                domain_list.append([
                    domain_row[DOMAIN_NAME], # domain_name TEXT
                    ",".join(domain_states), # domain_state TEXT
                    next_state,              # next_state TEXT
                    str(next_state_date),    # next_state_date DATE
                    "t" if domain_row[DNSSEC] else "f", # dnssec_available BOOL
                    "owner" if domain_row[REGISTRANT] == contact_id else "admin", # your_role TEXT
                    domain_row[REG_HANDLE],                                       # registrar_handle TEXT
                    "t" if "serverUpdateProhibited" in domain_states else "f",    # blocked_update BOOL
                    "t" if "serverTransferProhibited" in domain_states else "f",  # blocked_transfer BOOL
                    ])
        return domain_list



def init(logger, db, conf, joblist, corba_refs):
    """
    Function which creates, initializes and returns servant DomainBrowser.
    """
    servant = DomainBrowserServerInterface(logger, db, conf, joblist, corba_refs)
    return servant, "DomainBrowser"
