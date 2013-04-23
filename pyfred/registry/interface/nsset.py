#!/usr/bin/python
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import BaseInterface
from pyfred.registry.utils import parse_array_agg, none2str
from pyfred.registry.utils.decorators import furnish_database_cursor_m
from pyfred.registry.utils.constants import DOMAIN_ROLE, OBJECT_REGISTRY_TYPES, ENUM_OBJECT_STATES



class NssetInterface(BaseInterface):
    "NSSET corba interface."

    @furnish_database_cursor_m
    def getNssetList(self, contact, lang, offset):
        "List of nssets"
        self._verify_user_contact(contact)

        NSSET_ID, NSSET_HANDLE, NUM_OF_DOMAINS = range(3)
        result, counter, limit_exceeded = [], 0, False
        for row in self.source.fetchall("""
                SELECT
                    object_registry.id,
                    object_registry.name,
                    domains.number,
                    registrar.handle,
                    registrar.name AS registrar_name,
                    get_state_descriptions(nsset_contact_map.nssetid, %(lang)s) AS states
                FROM object_registry
                    LEFT JOIN domains_by_nsset_view domains ON domains.nsset = object_registry.id
                    LEFT JOIN nsset_contact_map ON nsset_contact_map.nssetid = object_registry.id
                    LEFT JOIN object ON object.id = object_registry.id
                    LEFT JOIN registrar ON registrar.id = object.clid
                WHERE object_registry.type = %(objtype)d
                    AND nsset_contact_map.contactid = %(contact_id)d
                LIMIT %(limit)d OFFSET %(offset)d
                """,
                dict(objtype=OBJECT_REGISTRY_TYPES['nsset'], contact_id=contact.id,
                     lang=lang, limit=self.list_limit + 1, offset=offset)):

            counter += 1
            if counter > self.list_limit:
                limit_exceeded = True
                break

            row[NSSET_ID] = str(row[NSSET_ID])
            row[NUM_OF_DOMAINS] = "0" if row[NUM_OF_DOMAINS] is None else "%d" % row[NUM_OF_DOMAINS]
            state_codes, state_importance, state_descriptions = self.parse_states(row.pop())
            row.append(state_importance)
            row.append(state_descriptions)
            result.append(row)

        self.logger.log(self.logger.INFO, 'NssetInterface.getNssetList(id=%d and handle="%s") has %d rows.' % (contact.id, contact.handle, len(result)))
        return result, limit_exceeded


    @furnish_database_cursor_m
    def getNssetDetail(self, contact, nsset, lang):
        """
        struct NSSetDetail {
            TID id;
            string handle;
            string roid;
            RegistryReference registrar;
            string create_date;
            string transfer_date;
            string update_date;
            RegistryReference create_registrar;
            RegistryReference update_registrar;
            string auth_info;
            RegistryReferenceSeq admins;
            sequence<DNSHost> hosts;
            string states;
            string state_codes;
            short report_level;
        };
        """
        self._verify_user_contact(contact)

        nsset.lang = lang
        results = self.source.fetchall("""
            SELECT
                oreg.id AS id,
                oreg.name AS handle,
                oreg.roid AS roid,

                oreg.crdate AS create_date,
                obj.trdate AS transfer_date,
                obj.update AS update_date,

                obj.authinfopw AS auth_info,
                nsset.checklevel,
                get_state_descriptions(oreg.id, %(lang)s) AS states,

                updator.id AS update_registrar_id,
                updator.handle AS update_registrar_handle,
                updator.name AS update_registrar_name,

                creator.id AS create_registrar_id,
                creator.handle AS create_registrar_handle,
                creator.name AS create_registrar_name,

                current.id AS registrar_id,
                current.handle AS registrar_handle,
                current.name AS registrar_name

            FROM object_registry oreg
                LEFT JOIN object obj ON obj.id = oreg.id
                LEFT JOIN nsset ON nsset.id = oreg.id

                LEFT JOIN registrar creator ON creator.id = oreg.crid
                LEFT JOIN registrar current ON current.id = obj.clid
                LEFT JOIN registrar updator ON updator.id = obj.upid

            WHERE oreg.id = %(object_id)d
                AND oreg.name = %(handle)s
                AND oreg.type = %(type_id)d
                AND oreg.erdate IS NULL
            """, nsset.__dict__)

        if len(results) == 0:
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Nsset detail of '%s' does not have one record: %s" % (nsset, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        TID, PASSWORD = 0, 6
        nsset_detail = results[0]
        registrars = self._pop_registrars_from_detail(nsset_detail) # pop some columns from the detail here
        state_codes, state_importance, state_descriptions = self.parse_states(nsset_detail.pop())

        owner = False
        admins = [] # Registry.DomainBrowser.CoupleSeq
        for row in self.source.fetchall("""
            SELECT
                object_registry.id,
                object_registry.name,
                CASE WHEN contact.organization IS NOT NULL AND LENGTH(contact.organization) > 0 THEN
                    contact.organization ELSE contact.name
                END
            FROM nsset_contact_map
            LEFT JOIN object_registry ON object_registry.id = nsset_contact_map.contactid
            LEFT JOIN contact ON contact.id = nsset_contact_map.contactid
            WHERE nssetid = %(obj_id)d
            """, dict(obj_id=nsset_detail[TID])):
            admins.append(Registry.DomainBrowser.RegistryReference(long(row[0]), none2str(row[1]), none2str(row[2])))
            if contact.handle == row[0]:
                owner = True

        if owner:
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PRIVATE_DATA)
        else:
            # public version
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PUBLIC_DATA)
            nsset_detail[PASSWORD] = self.PASSWORD_SUBSTITUTION

        hosts = []
        for row_host in self.source.fetchall("""
                SELECT
                    MIN(host.fqdn),
                    array_accum(host_ipaddr_map.ipaddr)
                FROM host
                LEFT JOIN host_ipaddr_map ON host_ipaddr_map.hostid = host.id
                WHERE host.nssetid = %(nsset_id)d
                GROUP BY host.id""", dict(nsset_id=nsset_detail[TID])):
            #     min     |  array_accum
            #-------------+--------------
            # a.ns.nic.cz | {194.0.12.1,123.4.0.1}
            # b.ns.nic.cz | {194.0.13.1}
            # c.ns.nic.cz | {NULL}
            ip_address = parse_array_agg(row_host[1])
            hosts.append(Registry.DomainBrowser.DNSHost(fqdn=row_host[0], inet=", ".join(ip_address)))

        nsset_detail.extend(registrars)
        nsset_detail.append(admins)
        nsset_detail.append(hosts)
        nsset_detail.append(state_codes)
        #nsset_detail.append(state_importance)
        nsset_detail.append(state_descriptions)

        # replace None by empty string
        nsset_detail = ['' if value is None else value for value in nsset_detail]

        columns = ("id", "handle", "roid", "create_date", "transfer_date", "update_date",
                   "auth_info", "report_level", "registrar", "create_registrar", "update_registrar",
                   "admins", "hosts", "state_codes", "states")
        data = dict(zip(columns, nsset_detail))

        return (Registry.DomainBrowser.NSSetDetail(**data), data_type)


    def setObjectBlockStatus(self, contact_handle, objtype, selections, action):
        "Set object block status."
        return self._setObjectBlockStatus(contact_handle, objtype, selections, action,
            """
            SELECT
                objreg.id
            FROM object_registry objreg
            LEFT JOIN nsset_contact_map map ON map.nssetid = objreg.id
            WHERE type = %(objtype)d
                AND map.contactid = %(contact_id)d
                AND objreg.id IN %(selections)s
            """)


    def _object_belongs_to_contact(self, contact_id, contact_handle, object_id, source=None):
        "Check if object belongs to the contact."
        if source is None:
            source = self.source
        admins = source.fetch_array("""
            SELECT object_registry.name
            FROM nsset_contact_map
            LEFT JOIN object_registry ON object_registry.id = nsset_contact_map.contactid
            WHERE nssetid = %(object_id)d
            """, dict(object_id=object_id))

        if contact_handle not in admins:
            self.logger.log(self.logger.INFO, "Nsset ID %d does not belong to the handle '%s' with ID %d." % (object_id, contact_handle, contact_id))
            raise Registry.DomainBrowser.ACCESS_DENIED
