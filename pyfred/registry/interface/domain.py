#!/usr/bin/python
from datetime import datetime, timedelta
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.utils.cursors import DatabaseCursor
from pyfred.registry.utils.constants import DOMAIN_ROLE
from pyfred.registry.interface.base import ListMetaInterface
from pyfred.registry.utils.decorators import furnish_database_cursor_m, \
            normalize_contact_handle_m, normalize_handles_m, normalize_domain_m



class DomainInterface(ListMetaInterface):
    """
    This class implements DomainBrowser Domain interface.
    """

    def getDomainListMeta(self):
        "Return the Domain list column names."
        return self._getObjectListMeta((
                            ("domain_name",      "TEXT"),
                            ("domain_state",     "TEXT"),
                            ("next_state",       "TEXT"),
                            ("next_state_date",  "DATE"),
                            ("dnssec_available", "BOOL"),
                            ("your_role",        "TEXT"),
                            ("registrar_handle", "TEXT"),
                            ("blocked_update",   "BOOL"),
                            ("blocked_transfer", "BOOL"),
                        ))


    def getDomainsForNssetMeta(self):
        "Dummy Domain for Nsset List Meta"
        return self.getDomainListMeta() # TODO: remove redundant

    def getDomainsForKeysetMeta(self):
        "Dummy Domain for Keyset List Meta"
        return self.getDomainListMeta() # TODO: remove redundant


    @normalize_contact_handle_m
    @furnish_database_cursor_m
    def getDomainList(self, handle):
        """
        RecordSet getDomainList(
                in RegistryObject handle,
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
        self.logger.log(self.logger.DEBUG, 'Call DomainInterface.getDomainList(handle="%s")' % handle)

        response_user = self.cursor.fetchall("SELECT object_registry.id, object_registry.name FROM object_registry "
                               "LEFT JOIN contact ON object_registry.id = contact.id "
                               "WHERE object_registry.name = %(handle)s",
                               dict(handle=handle))
        # data: [[ID, 'CONTACT_HANDLE']]
        if not len(response_user):
            raise Registry.DomainBrowser.USER_NOT_EXISTS

        contact_id = response_user[0][0]
        self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, handle))

        enum_parameters = dict(self.cursor.fetchall("SELECT name, val FROM enum_parameters"))
        #self.logger.log(self.logger.DEBUG, "enum_parameters = %s" % enum_parameters) # TEST

        domain_list = []
        REGID, DOMAIN_NAME, REG_HANDLE, EXDATE, REGISTRANT, DNSSEC, DOMAIN_STATES = range(7)

        self.cursor.execute("""
            CREATE TEMPORARY VIEW domain_states_view AS SELECT
                object_registry.id, array_agg(enum_object_states.name) AS states
            FROM object_registry
            LEFT JOIN object_state ON object_state.object_id = object_registry.id
                AND (object_state.valid_from < NOW()
                AND (object_state.valid_to IS NULL OR object_state.valid_to > NOW()))
            LEFT JOIN enum_object_states ON enum_object_states.id = object_state.state_id
            GROUP BY object_registry.id""")

        for domain_row in self.cursor.fetchall("""
                    SELECT
                        object_registry.id,
                        object_registry.name,
                        registrar.handle,
                        domain.exdate,
                        domain.registrant,
                        dnssec.digest IS NOT NULL,
                        domain_states_view.states
                    FROM object_registry
                    LEFT JOIN domain ON object_registry.id = domain.id
                    LEFT JOIN domain_contact_map ON domain_contact_map.domainid = domain.id
                              AND domain_contact_map.role = %(role_id)d
                    LEFT JOIN object_history ON object_history.historyid = object_registry.historyid
                    LEFT JOIN dnssec ON dnssec.domainid = domain.id
                    LEFT JOIN registrar ON registrar.id = object_history.clid
                    LEFT JOIN domain_states_view ON domain_states_view.id = object_registry.id
                    WHERE domain_contact_map.contactid = %(contact_id)d
                        OR domain.registrant = %(contact_id)d
                    ORDER BY domain.exdate DESC
                    LIMIT %(limit)d
                    """,
                    dict(contact_id=contact_id, role_id=DOMAIN_ROLE["admin"], limit=self.limits["list_domains"])):
            # row: [33, 'fred.cz', 'REG-FRED_A', '2015-10-12', 30, True]

            # Parse 'domain states' from "{outzone,nssetMissing}" or "{NULL}":
            domain_states = [name for name in domain_row[DOMAIN_STATES][1:-1].split(",") if name != "NULL"]

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
                " ".join(domain_states), # domain_state TEXT
                next_state,              # next_state TEXT
                str(next_state_date),    # next_state_date DATE
                "t" if domain_row[DNSSEC] else "f", # dnssec_available BOOL
                "owner" if domain_row[REGISTRANT] == contact_id else "admin", # your_role TEXT
                domain_row[REG_HANDLE],                                       # registrar_handle TEXT
                "t" if "serverUpdateProhibited" in domain_states else "f",    # blocked_update BOOL
                "t" if "serverTransferProhibited" in domain_states else "f",  # blocked_transfer BOOL
                ])

        return domain_list


    @normalize_handles_m(((0, "handle"), (1, "nsset")))
    @furnish_database_cursor_m
    def getDomainsForNsset(self, handle, nsset):
        "Domains for nsset"
        return []

    @normalize_handles_m(((0, "handle"), (1, "keyset")))
    @furnish_database_cursor_m
    def getDomainsForKeyset(self, handle, keyset):
        "Domains for nsset"
        return []

    @normalize_domain_m
    @normalize_contact_handle_m
    @furnish_database_cursor_m
    def getDomainDetail(self, handle, domain):
        """Get dummy Domain
        struct DomainDetail {
            TID id;
            string fqdn;
            string roid;
            string registrar;
            string create_date;
            string transfer_date;
            string update_date;
            string create_registrar;
            string update_registrar;
            string auth_info;
            string registrant;
            string expiration_date;
            string val_ex_date;
            boolean publish;
            string nsset;
            string keyset;
            ContactHandleSeq admins;
            ContactHandleSeq temps;
            ObjectStatusSeq status_list;
        };
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainInterface.getDomainDetail(domain="%s", handle="%s")' % (domain, handle))

        PUBLIC_DATA, PRIVATE_DATA = range(2)
        return (Registry.DomainBrowser.DomainDetail(
                    id=140,
                    fqdn=domain,
                    roid='C0000000003-CZ',
                    registrar='REG-DESIGNATED',
                    create_date='2012-03-14 11:16:28.516926',
                    transfer_date='',
                    update_date='',
                    create_registrar='REG-CREATED',
                    update_registrar='',
                    auth_info='password',
                    registrant="KONTAKT",
                    expiration_date='2013-03-14 11:16:28.516926',
                    val_ex_date='',
                    publish=True,
                    nsset='NSSET:102',
                    keyset='KEYSID:102',
                    admins=('ADMIN01', 'ADMIN02'),
                    temps=('TEMPS-01', 'TEMPS-02'),
                    status_list=('testLinked', 'testValidated')
                ),
                Registry.DomainBrowser.DataAccessLevel._item(PUBLIC_DATA))
