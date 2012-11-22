#!/usr/bin/python
from datetime import datetime, timedelta
# pyfred
from pyfred.idlstubs import Registry
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


    def __provideDomainList(self, contact_id, sql_query, sql_params):
        """
        Provide domain list for interface functions.
        """

        enum_parameters = dict(self.cursor.fetchall("SELECT name, val FROM enum_parameters"))
        #self.logger.log(self.logger.DEBUG, "enum_parameters = %s" % enum_parameters) # TEST

        domain_list = []
        REGID, DOMAIN_NAME, REG_HANDLE, EXDATE, REGISTRANT, DNSSEC, DOMAIN_STATES = range(7)

        self.cursor.execute("""
            CREATE OR REPLACE TEMPORARY VIEW domain_states_view AS SELECT
                object_registry.id, array_agg(enum_object_states.name) AS states
            FROM object_registry
            LEFT JOIN object_state ON object_state.object_id = object_registry.id
                AND (object_state.valid_from < NOW()
                AND (object_state.valid_to IS NULL OR object_state.valid_to > NOW()))
            LEFT JOIN enum_object_states ON enum_object_states.id = object_state.state_id
            GROUP BY object_registry.id""")

        # domain_row: [33, 'fred.cz', 'REG-FRED_A', '2015-10-12', 30, True, '{NULL}']
        for domain_row in self.cursor.fetchall(sql_query, sql_params):
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


    def __getHandleId(self, handle, query, exception_not_exists=None):
        "Returns ID of handle."
        if exception_not_exists is None:
            exception_not_exists = Registry.DomainBrowser.OBJECT_NOT_EXISTS

        response = self.cursor.fetchall(query, dict(handle=handle))
        if not len(response):
            raise exception_not_exists

        return response[0][0]


    def __getContactHandleId(self, handle):
        "Returns ID of contact handle."
        return self.__getHandleId(handle, """
            SELECT
                object_registry.id, object_registry.name
            FROM object_registry
            LEFT JOIN contact ON object_registry.id = contact.id
            WHERE object_registry.name = %(handle)s""",
            Registry.DomainBrowser.USER_NOT_EXISTS)


    @normalize_contact_handle_m
    @furnish_database_cursor_m
    def getDomainList(self, handle):
        """
        RecordSet getDomainList(
                in RegistryObject handle,
            ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainInterface.getDomainList(handle="%s")' % handle)

        contact_id = self.__getContactHandleId(handle)
        self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, handle))

        sql_query = """
            SELECT
                object_registry.id,
                object_registry.name,
                registrar.handle,
                domain.exdate,
                domain.registrant,
                domain.keyset IS NOT NULL,
                domain_states_view.states
            FROM object_registry
            LEFT JOIN domain ON object_registry.id = domain.id
            LEFT JOIN domain_contact_map ON domain_contact_map.domainid = domain.id
                      AND domain_contact_map.role = %(role_id)d
            LEFT JOIN object_history ON object_history.historyid = object_registry.historyid
            LEFT JOIN registrar ON registrar.id = object_history.clid
            LEFT JOIN domain_states_view ON domain_states_view.id = object_registry.id
            WHERE domain_contact_map.contactid = %(contact_id)d
                OR domain.registrant = %(contact_id)d
            ORDER BY domain.exdate DESC
            LIMIT %(limit)d"""
        sql_params = dict(contact_id=contact_id, role_id=DOMAIN_ROLE["admin"], limit=self.limits["list_domains"])

        return self.__provideDomainList(contact_id, sql_query, sql_params)


    @normalize_handles_m(((0, "handle"), (1, "nsset")))
    @furnish_database_cursor_m
    def getDomainsForNsset(self, handle, nsset):
        "Domains for nsset"
        self.logger.log(self.logger.DEBUG, 'Call DomainInterface.getDomainsForNsset(handle="%s", nsset="%s")' % (handle, nsset))

        contact_id = self.__getContactHandleId(handle)
        self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, handle))

        nsset_id = self.__getHandleId(nsset, """
            SELECT object_registry.id, object_registry.name
            FROM object_registry
            LEFT JOIN nsset ON object_registry.id = nsset.id
            WHERE object_registry.name = %(handle)s""")
        self.logger.log(self.logger.DEBUG, "Found NSSET ID %d of the handle '%s'." % (nsset_id, nsset))

        sql_query = """
            SELECT
                object_registry.id,
                object_registry.name,
                registrar.handle,
                domain.exdate,
                domain.registrant,
                domain.keyset IS NOT NULL,
                domain_states_view.states
            FROM object_registry
            LEFT JOIN domain ON object_registry.id = domain.id
            LEFT JOIN domain_contact_map ON domain_contact_map.domainid = domain.id
                      AND domain_contact_map.role = %(role_id)d
            LEFT JOIN object_history ON object_history.historyid = object_registry.historyid
            LEFT JOIN registrar ON registrar.id = object_history.clid
            LEFT JOIN domain_states_view ON domain_states_view.id = object_registry.id
            WHERE domain.nsset = %(nsset_id)d
            ORDER BY domain.exdate DESC
            LIMIT %(limit)d"""
        sql_params = dict(nsset_id=nsset_id, role_id=DOMAIN_ROLE["admin"], limit=self.limits["list_domains"])

        return self.__provideDomainList(contact_id, sql_query, sql_params)



    @normalize_handles_m(((0, "handle"), (1, "keyset")))
    @furnish_database_cursor_m
    def getDomainsForKeyset(self, handle, keyset):
        "Domains for keyset"
        self.logger.log(self.logger.DEBUG, 'Call DomainInterface.getDomainsForKeyset(handle="%s", keyset="%s")' % (handle, keyset))

        contact_id = self.__getContactHandleId(handle)
        self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, handle))

        keyset_id = self.__getHandleId(keyset, """
            SELECT object_registry.id, object_registry.name
            FROM object_registry
            LEFT JOIN keyset ON object_registry.id = keyset.id
            WHERE object_registry.name = %(handle)s""")
        self.logger.log(self.logger.DEBUG, "Found KEYSET ID %d of the handle '%s'." % (keyset_id, keyset))

        sql_query = """
            SELECT
                object_registry.id,
                object_registry.name,
                registrar.handle,
                domain.exdate,
                domain.registrant,
                domain.keyset IS NOT NULL,
                domain_states_view.states
            FROM object_registry
            LEFT JOIN domain ON object_registry.id = domain.id
            LEFT JOIN domain_contact_map ON domain_contact_map.domainid = domain.id
                      AND domain_contact_map.role = %(role_id)d
            LEFT JOIN object_history ON object_history.historyid = object_registry.historyid
            LEFT JOIN registrar ON registrar.id = object_history.clid
            LEFT JOIN domain_states_view ON domain_states_view.id = object_registry.id
            WHERE domain.keyset = %(keyset_id)d
            ORDER BY domain.exdate DESC
            LIMIT %(limit)d"""
        sql_params = dict(keyset_id=keyset_id, role_id=DOMAIN_ROLE["admin"], limit=self.limits["list_domains"])

        return self.__provideDomainList(contact_id, sql_query, sql_params)


    @normalize_domain_m
    @normalize_contact_handle_m
    @furnish_database_cursor_m
    def getDomainDetail(self, handle, domain):
        """
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
        SELECT type, name FROM object_registry;
            1 - contact
            2 - nsset
            3 - domain
            4 - keyset
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainInterface.getDomainDetail(handle="%s", domain="%s")' % (handle, domain))

        contact_id = self.__getContactHandleId(handle)
        self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, handle))


        status_list = []
        for row_states in self.cursor.fetchall("""
                SELECT
                    enum_object_states.name
                FROM object_registry
                LEFT JOIN object_state ON object_state.object_id = object_registry.id
                    AND (object_state.valid_from < NOW()
                    AND (object_state.valid_to IS NULL OR object_state.valid_to > NOW()))
                LEFT JOIN enum_object_states ON enum_object_states.id = object_state.state_id
                WHERE object_registry.name = %(name)s""", dict(name=domain)):
            if row_states[0]:
                status_list.append(row_states[0])
        self.logger.log(self.logger.DEBUG, "Domain '%s' has states: %s." % (domain, status_list))

        results = self.cursor.fetchall("""
            SELECT
                oreg.id AS id,
                oreg.roid AS roid,
                oreg.name AS fqdn,

                current.handle AS registrar,

                oreg.crdate AS create_date,
                obj.trdate AS transfer_date,
                obj.update AS update_date,

                creator.handle AS create_registrar,
                updator.handle AS update_registrar,

                obj.authinfopw AS auth_info,

                registrant.name AS registrant,

                domain.exdate AS expiration_date,
                registrant.erdate AS val_ex_date,

                enum.publish AS publish,

                regnsset.name AS nsset,
                regkeyset.name AS keyset

            FROM object_registry oreg
                LEFT JOIN object obj ON obj.id = oreg.id

                LEFT JOIN domain ON oreg.id = domain.id
                LEFT JOIN object_registry registrant ON registrant.id = domain.registrant

                LEFT JOIN registrar creator ON creator.id = oreg.crid
                LEFT JOIN registrar current ON current.id = obj.clid
                LEFT JOIN registrar updator ON updator.id = obj.upid

                LEFT JOIN object_registry regnsset ON regnsset.id = domain.nsset
                LEFT JOIN object_registry regkeyset ON regkeyset.id = domain.keyset

                LEFT JOIN enumval enum ON enum.domainid = oreg.id

            WHERE oreg.name = %(domain)s
        """, dict(domain=domain))

        if len(results) == 0:
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Domain detail of '%s' does not have one record: %s" % (domain, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        TID, PASSWORD, REGISTRANT, PUBLISH = 0, 9, 10, 13

        domain_detail = results[0]

        if domain_detail[PUBLISH] is None:
            domain_detail[PUBLISH] = False

        if domain_detail[REGISTRANT] == handle:
            # owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PRIVATE_DATA)
        else:
            # not owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PUBLIC_DATA)
            domain_detail[PASSWORD] = self.PASSWORD_SUBSTITUTION

        admins = self.cursor.fetchall("""
            SELECT object_registry.name
            FROM domain_contact_map
            LEFT JOIN object_registry ON object_registry.id = domain_contact_map.contactid
            WHERE domain_contact_map.role = %(role_id)d
                AND domainid = %(obj_id)d
            """, dict(role_id=DOMAIN_ROLE["admin"], obj_id=domain_detail[TID]))

        # OBSOLETE
        temps = self.cursor.fetchall("""
            SELECT object_registry.name
            FROM domain_contact_map
            LEFT JOIN object_registry ON object_registry.id = domain_contact_map.contactid
            WHERE domain_contact_map.role = %(role_id)d
                AND domainid = %(obj_id)d
            """, dict(role_id=DOMAIN_ROLE["temp"], obj_id=domain_detail[TID]))

        domain_detail.append([row[0] for row in admins])
        domain_detail.append([row[0] for row in temps]) # OBSOLETE
        domain_detail.append(status_list)

        # replace None by empty string
        domain_detail = ['' if value is None else value for value in domain_detail]

        columns = ("id", "roid", "fqdn", "registrar", "create_date", "transfer_date",
                   "update_date", "create_registrar", "update_registrar", "auth_info",
                   "registrant", "expiration_date", "val_ex_date", "publish", "nsset", "keyset",
                   "admins", "temps", "status_list")

        data = dict(zip(columns, domain_detail))

        return (Registry.DomainBrowser.DomainDetail(**data), data_type)
