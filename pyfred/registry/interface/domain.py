#!/usr/bin/python
from datetime import datetime, timedelta
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.utils.constants import DOMAIN_ROLE, OBJECT_REGISTRY_TYPES, ENUM_OBJECT_STATES
from pyfred.registry.interface.base import ListMetaInterface
from pyfred.registry.utils.decorators import furnish_database_cursor_m
from pyfred.registry.utils import parse_array_agg_int



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

        enum_parameters = dict(self.source.fetchall("SELECT name, val FROM enum_parameters"))
        #self.logger.log(self.logger.DEBUG, "enum_parameters = %s" % enum_parameters) # TEST

        domain_list = []
        REGID, DOMAIN_NAME, REG_HANDLE, EXDATE, REGISTRANT, DNSSEC, DOMAIN_STATES = range(7)

        # domain_row: [33, 'fred.cz', 'REG-FRED_A', '2015-10-12', 30, True, '{NULL}']
        for domain_row in self.source.fetchall(sql_query, sql_params):
            # Parse 'domain states' from "{outzone,nssetMissing}" or "{NULL}":
            domain_states = parse_array_agg_int(domain_row[DOMAIN_STATES])

            # expiration_dns_protection_period, expiration_registration_protection_period
            exdate = datetime.strptime(domain_row[EXDATE], '%Y-%m-%d').date()
            outzone_date = exdate + timedelta(days=int(enum_parameters["expiration_dns_protection_period"])) # 30
            delete_date  = exdate + timedelta(days=int(enum_parameters["expiration_registration_protection_period"])) # 61
            #self.logger.log(self.logger.DEBUG, 'Contact %d "%s": exdate=%s; outzone_date=%s; delete_date=%s' % (contact_id, handle, exdate, outzone_date, delete_date))

            # resolve next domain state:
            #    today   exdate         protected period
            #      |       |<- - - - - - - - - - - - - - - - - - ->|
            # |------------|-------------------|-------------------|------------>
            #             0|                +30|                +61|
            #          expiration           outzone              delete
            next_state, next_state_date = "N/A", ""
            today = datetime.today().date()
            if today < exdate:
                # domain still has not been expired, so next state will be 'expired'
                next_state, next_state_date = "expired", exdate
            else:
                # domain is over an expiration date...
                if today < delete_date or today < outzone_date:
                    # ...but still inside of "Protected period":
                    if outzone_date < delete_date:
                        # outzone date is always less than delete date
                        if today < outzone_date:
                            next_state, next_state_date = "outzone", outzone_date
                        else:
                            next_state, next_state_date = "deleteCandidate", delete_date
                    else:
                        # this situation should not never occur
                        if today < delete_date:
                            next_state, next_state_date = "deleteCandidate", delete_date
                        else:
                            next_state, next_state_date = "outzone", outzone_date

            domain_list.append([
                domain_row[DOMAIN_NAME], # domain_name TEXT
                " ".join(self._map_object_states(domain_states)),
                next_state,              # next_state TEXT
                str(next_state_date),    # next_state_date DATE
                "t" if domain_row[DNSSEC] else "f", # dnssec_available BOOL
                "owner" if domain_row[REGISTRANT] == contact_id else "admin", # your_role TEXT
                domain_row[REG_HANDLE],                                       # registrar_handle TEXT
                "t" if ENUM_OBJECT_STATES["serverUpdateProhibited"] in domain_states else "f",    # blocked_update BOOL
                "t" if ENUM_OBJECT_STATES["serverTransferProhibited"] in domain_states else "f",  # blocked_transfer BOOL
                ])

        return domain_list


    @furnish_database_cursor_m
    def getDomainList(self, contact_handle):
        "Return list of domains."
        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.INFO, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))

        sql_query = """
            SELECT
                object_registry.id,
                object_registry.name,
                registrar.handle,
                domain.exdate,
                domain.registrant,
                domain.keyset IS NOT NULL,
                domain_states.states
            FROM object_registry
            LEFT JOIN domain ON object_registry.id = domain.id
            LEFT JOIN domain_contact_map ON domain_contact_map.domainid = domain.id
                      AND domain_contact_map.role = %(role_id)d
                      AND domain_contact_map.contactid = %(contact_id)d
            LEFT JOIN object_history ON object_history.historyid = object_registry.historyid
            LEFT JOIN registrar ON registrar.id = object_history.clid
            LEFT JOIN domain_states ON domain_states.object_id = object_registry.id
            WHERE domain_contact_map.contactid = %(contact_id)d
                OR domain.registrant = %(contact_id)d
            ORDER BY domain.exdate DESC
            LIMIT %(limit)d"""
        sql_params = dict(contact_id=contact_id, role_id=DOMAIN_ROLE["admin"], limit=self.list_limit)

        return self.__provideDomainList(contact_id, sql_query, sql_params)


    @furnish_database_cursor_m
    def getDomainsForNsset(self, contact_handle, nsset):
        "Domains for nsset"
        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.INFO, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))

        nsset_id = self._get_handle_id(nsset, "nsset")
        self.logger.log(self.logger.INFO, "Found NSSET ID %d of the handle '%s'." % (nsset_id, nsset))

        sql_query = """
            SELECT
                object_registry.id,
                object_registry.name,
                registrar.handle,
                domain.exdate,
                domain.registrant,
                domain.keyset IS NOT NULL,
                domain_states.states
            FROM object_registry
            LEFT JOIN domain ON domain.id = object_registry.id
            LEFT JOIN object_history ON object_history.historyid = object_registry.historyid
            LEFT JOIN registrar ON registrar.id = object_history.clid
            LEFT JOIN domain_states ON domain_states.object_id = object_registry.id
            WHERE object_registry.type = %(objtype)d
                AND domain.nsset = %(nsset_id)d
            ORDER BY domain.exdate DESC
            LIMIT %(limit)d"""
        sql_params = dict(nsset_id=nsset_id, objtype=OBJECT_REGISTRY_TYPES['domain'],
                          limit=self.list_limit)

        return self.__provideDomainList(contact_id, sql_query, sql_params)


    @furnish_database_cursor_m
    def getDomainsForKeyset(self, contact_handle, keyset):
        "Domains for keyset"
        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.INFO, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))

        keyset_id = self._get_handle_id(keyset, "keyset")
        self.logger.log(self.logger.INFO, "Found KEYSET ID %d of the handle '%s'." % (keyset_id, keyset))

        sql_query = """
            SELECT
                object_registry.id,
                object_registry.name,
                registrar.handle,
                domain.exdate,
                domain.registrant,
                domain.keyset IS NOT NULL,
                domain_states.states
            FROM object_registry
            LEFT JOIN domain ON domain.id = object_registry.id
            LEFT JOIN object_history ON object_history.historyid = object_registry.historyid
            LEFT JOIN registrar ON registrar.id = object_history.clid
            LEFT JOIN domain_states ON domain_states.object_id = object_registry.id
            WHERE object_registry.type = %(objtype)d
                AND domain.keyset = %(keyset_id)d
            ORDER BY domain.exdate DESC
            LIMIT %(limit)d"""
        sql_params = dict(keyset_id=keyset_id, objtype=OBJECT_REGISTRY_TYPES['domain'],
                          limit=self.list_limit)

        return self.__provideDomainList(contact_id, sql_query, sql_params)


    @furnish_database_cursor_m
    def getDomainDetail(self, contact_handle, domain):
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
        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.INFO, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))

        results = self.source.fetchall("""
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
                zone.enum_zone,

                regnsset.name AS nsset,
                regkeyset.name AS keyset

            FROM object_registry oreg
                LEFT JOIN object obj ON obj.id = oreg.id

                LEFT JOIN domain ON oreg.id = domain.id
                LEFT JOIN zone ON domain.zone = zone.id
                LEFT JOIN object_registry registrant ON registrant.id = domain.registrant

                LEFT JOIN registrar creator ON creator.id = oreg.crid
                LEFT JOIN registrar current ON current.id = obj.clid
                LEFT JOIN registrar updator ON updator.id = obj.upid

                LEFT JOIN object_registry regnsset ON regnsset.id = domain.nsset
                LEFT JOIN object_registry regkeyset ON regkeyset.id = domain.keyset

                LEFT JOIN enumval enum ON enum.domainid = oreg.id

            WHERE oreg.type = %(type_id)d AND oreg.name = %(domain)s
        """, dict(domain=domain, type_id=OBJECT_REGISTRY_TYPES["domain"]))

        if len(results) == 0:
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Domain detail of '%s' does not have one record: %s" % (domain, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        status_list = self._get_status_list(domain, "domain")
        self.logger.log(self.logger.INFO, "Domain '%s' has states: %s." % (domain, status_list))

        TID, PASSWORD, REGISTRANT, PUBLISH = 0, 9, 10, 13

        domain_detail = results[0]

        if domain_detail[PUBLISH] is None:
            domain_detail[PUBLISH] = False

        if domain_detail[REGISTRANT] == contact_handle:
            # owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PRIVATE_DATA)
        else:
            # not owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PUBLIC_DATA)
            domain_detail[PASSWORD] = self.PASSWORD_SUBSTITUTION

        admins = self.source.fetch_array("""
            SELECT object_registry.name
            FROM domain_contact_map
            LEFT JOIN object_registry ON object_registry.id = domain_contact_map.contactid
            WHERE domain_contact_map.role = %(role_id)d
                AND domainid = %(obj_id)d
            """, dict(role_id=DOMAIN_ROLE["admin"], obj_id=domain_detail[TID]))

        # OBSOLETE
        temps = self.source.fetch_array("""
            SELECT object_registry.name
            FROM domain_contact_map
            LEFT JOIN object_registry ON object_registry.id = domain_contact_map.contactid
            WHERE domain_contact_map.role = %(role_id)d
                AND domainid = %(obj_id)d
            """, dict(role_id=DOMAIN_ROLE["temp"], obj_id=domain_detail[TID]))

        domain_detail.append(admins)
        domain_detail.append(temps) # OBSOLETE
        domain_detail.append(status_list)

        # replace None by empty string
        domain_detail = ['' if value is None else value for value in domain_detail]

        columns = ("id", "roid", "fqdn", "registrar", "create_date", "transfer_date",
                   "update_date", "create_registrar", "update_registrar", "auth_info",
                   "registrant", "expiration_date", "val_ex_date", "publish", "is_enum",
                   "nsset", "keyset", "admins", "temps", "status_list")
        data = dict(zip(columns, domain_detail))

        return (Registry.DomainBrowser.DomainDetail(**data), data_type)


    def setObjectBlockStatus(self, contact_handle, objtype, selections, action):
        "Set object block status."
        return self._setObjectBlockStatus(contact_handle, objtype, selections, action,
            """
            SELECT
                objreg.name,
                objreg.id
            FROM object_registry objreg
            LEFT JOIN domain_contact_map map ON map.domainid = objreg.id
            LEFT JOIN domain ON objreg.id = domain.id
            WHERE type = %(objtype)d
                AND (map.contactid = %(contact_id)d OR domain.registrant = %(contact_id)d)
                AND name IN %(names)s
            """)


    def _object_belongs_to_contact(self, contact_id, contact_handle, object_id):
        "Check if object belongs to the contact."
        registrant_handle = self.source.getval("""
            SELECT
                registrant.name
            FROM object_registry oreg
                LEFT JOIN domain ON oreg.id = domain.id
                LEFT JOIN object_registry registrant ON registrant.id = domain.registrant
            WHERE oreg.id = %(object_id)d
        """, dict(object_id=object_id))

        if registrant_handle != contact_handle:
            self.logger.log(self.logger.INFO, "Domain ID %d does not belong to the handle '%s' with ID %d." % (object_id, contact_handle, contact_id))
            raise Registry.DomainBrowser.ACCESS_DENIED


    def _copy_into_history_query(self, objtype):
        "Prepare query for copy object into history."
        # The order of columns in tables 'domain_history' and 'domain' are different.
        # So we need list them in the query.
        return """
            INSERT INTO domain_history
                       (historyid, id, zone, registrant, nsset, exdate, keyset)
            SELECT %(history_id)d, id, zone, registrant, nsset, exdate, keyset
            FROM domain WHERE id = %(object_id)d"""
