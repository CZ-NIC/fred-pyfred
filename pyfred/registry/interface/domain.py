#!/usr/bin/python
"""
from datetime import datetime, timedelta

today = datetime.today().date()
print "N/A: < ", today - timedelta(days=61-1)
print "deleted: ", today - timedelta(days=61-1), "-", today - timedelta(days=30)
print "outzone: ", today - timedelta(days=30-1), "-", today
print "expired: ", today + timedelta(days=1), ">"
"""
from datetime import datetime, timedelta
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.utils.constants import DOMAIN_ROLE, OBJECT_REGISTRY_TYPES, ENUM_OBJECT_STATES
from pyfred.registry.interface.base import ListMetaInterface
from pyfred.registry.utils.decorators import furnish_database_cursor_m
from pyfred.registry.utils import parse_array_agg_int, none2str



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
        class Col(object):
            REGID, DOMAIN_NAME, REG_HANDLE, EXDATE, REGISTRANT, DNSSEC, DOMAIN_STATES = range(7)

        counter, limit_exceeded = 0, 0
        # domain_row: [33, 'fred.cz', 'REG-FRED_A', '2015-10-12', 30, True, '{NULL}']
        for domain_row in self.source.fetchall(sql_query, sql_params): #, self.source.DUMP

            counter += 1
            if counter > self.list_limit:
                limit_exceeded = self.list_limit
                break

            # Parse 'domain states' from "{outzone,nssetMissing}" or "{NULL}":
            domain_states = parse_array_agg_int(domain_row[Col.DOMAIN_STATES])

            # expiration_dns_protection_period, expiration_registration_protection_period
            exdate = datetime.strptime(domain_row[Col.EXDATE], '%Y-%m-%d').date()
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
            ## TEST
            #self.logger.log(self.logger.INFO, "regid=%s exdate=%s outzone_date=%s delete_date=%s; " \
            #        "next_state=%s next_state_date=%s" % (domain_row[Col.REGID], exdate, outzone_date, delete_date,
            #        next_state, next_state_date))

            domain_list.append([
                domain_row[Col.DOMAIN_NAME], # domain_name TEXT
                " ".join(self._map_object_states(domain_states)),
                next_state,              # next_state TEXT
                str(next_state_date),    # next_state_date DATE
                "t" if domain_row[Col.DNSSEC] else "f", # dnssec_available BOOL
                "holder" if domain_row[Col.REGISTRANT] == contact_id else "admin", # your_role TEXT
                domain_row[Col.REG_HANDLE],                                        # registrar_handle TEXT
                "t" if ENUM_OBJECT_STATES["serverUpdateProhibited"] in domain_states else "f",    # blocked_update BOOL
                "t" if ENUM_OBJECT_STATES["serverTransferProhibited"] in domain_states else "f",  # blocked_transfer BOOL
                ])

        return domain_list, limit_exceeded


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
            ORDER BY domain.exdate
            LIMIT %(limit)d"""
        sql_params = dict(contact_id=contact_id, role_id=DOMAIN_ROLE["admin"], limit=self.list_limit + 1)

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
            LEFT JOIN domain_contact_map ON domain_contact_map.domainid = domain.id
                      AND domain_contact_map.role = %(role_id)d
                      AND domain_contact_map.contactid = %(contact_id)d
            LEFT JOIN object_history ON object_history.historyid = object_registry.historyid
            LEFT JOIN registrar ON registrar.id = object_history.clid
            LEFT JOIN domain_states ON domain_states.object_id = object_registry.id
            WHERE object_registry.type = %(objtype)d
                AND domain.nsset = %(nsset_id)d
                AND (domain_contact_map.contactid = %(contact_id)d OR domain.registrant = %(contact_id)d)
            ORDER BY domain.exdate
            LIMIT %(limit)d"""
        sql_params = dict(contact_id=contact_id, nsset_id=nsset_id, objtype=OBJECT_REGISTRY_TYPES['domain'],
                          role_id=DOMAIN_ROLE["admin"], limit=self.list_limit + 1)

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
            LEFT JOIN domain_contact_map ON domain_contact_map.domainid = domain.id
                      AND domain_contact_map.role = %(role_id)d
                      AND domain_contact_map.contactid = %(contact_id)d
            LEFT JOIN object_history ON object_history.historyid = object_registry.historyid
            LEFT JOIN registrar ON registrar.id = object_history.clid
            LEFT JOIN domain_states ON domain_states.object_id = object_registry.id
            WHERE object_registry.type = %(objtype)d
                AND domain.keyset = %(keyset_id)d
                AND (domain_contact_map.contactid = %(contact_id)d OR domain.registrant = %(contact_id)d)
            ORDER BY domain.exdate
            LIMIT %(limit)d"""
        sql_params = dict(contact_id=contact_id, keyset_id=keyset_id, objtype=OBJECT_REGISTRY_TYPES['domain'],
                          role_id=DOMAIN_ROLE["admin"], limit=self.list_limit + 1)

        return self.__provideDomainList(contact_id, sql_query, sql_params)


    @furnish_database_cursor_m
    def getDomainDetail(self, contact_handle, domain):
        """
        struct DomainDetail {
            TID id;
            string fqdn;
            string roid;
            Couple registrar;
            string create_date;
            string update_date;
            string auth_info;
            Couple registrant;
            string expiration_date;
            string val_ex_date;
            boolean publish;
            boolean is_enum;
            string nsset;
            string keyset;
            CoupleSeq admins;
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

                oreg.crdate AS create_date,
                obj.update AS update_date,
                obj.authinfopw AS auth_info,

                domain.exdate AS expiration_date,

                enum.exdate AS val_ex_date,
                enum.publish AS publish,
                zone.enum_zone,

                regnsset.name AS nsset,
                regkeyset.name AS keyset,

                registrant.name AS registrant_handle,
                CASE WHEN contact.organization IS NOT NULL AND LENGTH(contact.organization) > 0 THEN
                    contact.organization ELSE contact.name
                END AS registrant_name,

                current.handle AS registrar_handle,
                current.name AS registrar_name

            FROM object_registry oreg
                LEFT JOIN object obj ON obj.id = oreg.id

                LEFT JOIN domain ON oreg.id = domain.id
                LEFT JOIN zone ON domain.zone = zone.id
                LEFT JOIN object_registry registrant ON registrant.id = domain.registrant
                LEFT JOIN contact ON contact.id = registrant.id

                LEFT JOIN registrar current ON current.id = obj.clid

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

        # -[ RECORD 1 ]-----+---------------------------
        # id                | 1191
        # roid              | D0000001191-CZ
        # fqdn              | nova-sada-jmen-990.cz
        # create_date       | 2013-01-22 08:56:22.089884
        # update_date       |
        # auth_info         | heslo
        # expiration_date   | 2016-01-22
        # val_ex_date       |
        # publish           |
        # enum_zone         | f
        # nsset             | NSSID03
        # keyset            | KEYID03
        # registrant_handle | BOB
        # registrant_name   | Bedrich Hrebicek
        # registrar_handle  | REG-FRED_A
        # registrar_name    | Company A l.t.d

        class Col(object):
            TID, PASSWORD, PUBLISH = 0, 5, 8

        columns = (
            "id",
            "roid",
            "fqdn",
            "create_date",
            "update_date",
            "auth_info",
            "expiration_date",
            "val_ex_date",
            "publish",
            "is_enum",
            "nsset",
            "keyset",
            # create from registrar_handle + registrar_name
            "registrant",
            "registrar",
            "admins",
            "status_list"
        )

        domain_detail = results[0]

        registrar_name = none2str(domain_detail.pop())
        registrar_handle = none2str(domain_detail.pop())

        registrant_name = none2str(domain_detail.pop())
        registrant_handle = none2str(domain_detail.pop())

        if domain_detail[Col.PUBLISH] is None:
            domain_detail[Col.PUBLISH] = False

        admins = [] # Registry.DomainBrowser.CoupleSeq
        admin_handles = []
        for row in self.source.fetchall("""
                SELECT object_registry.name,
                    CASE WHEN contact.organization IS NOT NULL AND LENGTH(contact.organization) > 0 THEN
                        contact.organization ELSE contact.name
                    END AS contact_name
                FROM domain_contact_map
                LEFT JOIN object_registry ON object_registry.id = domain_contact_map.contactid
                LEFT JOIN contact ON contact.id = object_registry.id
                WHERE domain_contact_map.role = %(role_id)d
                    AND domainid = %(obj_id)d
                """, dict(role_id=DOMAIN_ROLE["admin"], obj_id=domain_detail[Col.TID])):
            admins.append(Registry.DomainBrowser.Couple(none2str(row[0]), none2str(row[1])))
            admin_handles.append(row[0])

        if contact_handle == registrant_handle or contact_handle in admin_handles:
            # owner or contact in admins list
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PRIVATE_DATA)
        else:
            # not owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PUBLIC_DATA)
            domain_detail[Col.PASSWORD] = self.PASSWORD_SUBSTITUTION

        domain_detail.append(Registry.DomainBrowser.Couple(registrant_handle, registrant_name))
        domain_detail.append(Registry.DomainBrowser.Couple(registrar_handle, registrar_name))
        domain_detail.append(admins)
        domain_detail.append(status_list)

        # replace None by empty string
        domain_detail = ['' if value is None else value for value in domain_detail]

        data = dict(zip(columns, domain_detail))
        return (Registry.DomainBrowser.DomainDetail(**data), data_type)


    @furnish_database_cursor_m
    def getRegistrarDetail(self, contact_handle, handle):
        """
        struct RegistrarDetail {
            string handle;
            string name;
            string phone;
            string fax;
            string url;
            string address;
        };
        """
        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.INFO, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))

        columns = ("handle", "name", "phone", "fax", "url", "address")
        results = self.source.fetchall("""
            SELECT
                handle, name, telephone, fax, url,
                ARRAY_TO_STRING(ARRAY[street1, street2, street3, postalcode, city, stateorprovince] , ', ') AS address
            FROM registrar
            WHERE handle = %(handle)s""", dict(handle=handle))

        if len(results) == 0:
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Registrar detail of '%s' does not have one record: %s" % (handle, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        # replace None by empty string
        registry_detail = ['' if value is None else value for value in results[0]]
        return (Registry.DomainBrowser.RegistrarDetail(**dict(zip(columns, registry_detail))))


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
