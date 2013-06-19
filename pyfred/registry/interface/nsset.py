#!/usr/bin/python
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import BaseInterface
from pyfred.registry.utils import parse_array_agg, none2str, parse_pg_array
from pyfred.registry.utils.decorators import furnish_database_cursor_m
from pyfred.registry.utils.constants import DOMAIN_ROLE, OBJECT_REGISTRY_TYPES, ENUM_OBJECT_STATES



class NssetInterface(BaseInterface):
    "NSSET corba interface."

    @furnish_database_cursor_m
    def getNssetList(self, contact, lang, offset):
        "List of nssets"
        self._verify_user_contact(contact)

        minimal_status_importance = self.get_status_minimal_importance()
        str_minimal_status_importance = str(minimal_status_importance)

        class Cols:
            OBJECT_ID, HANDLE, NUM_OF_DOMAINS, REG_HANDLE, REG_NAME, STATUS_IMPORTANCE, STATUS_DESC = range(7)

        result, counter, limit_exceeded = [], 0, False
        #CREATE OR REPLACE VIEW domains_by_nsset_view AS
        #    SELECT nsset, COUNT(nsset) AS number FROM domain WHERE nsset IS NOT NULL GROUP BY nsset
        position = {}
        for row in self.browser.threading_local.source.fetchall("""
            SELECT
                reg.id,
                reg.name,
                reg.number,
                reg.handle,
                reg.registrar_name,
                NULL::integer[],
                NULL::varchar[]
            FROM (
                SELECT
                    oreg.id,
                    oreg.name,
                    domains.number,
                    registrar.handle,
                    registrar.name AS registrar_name
                FROM object_registry oreg
                    JOIN object ON object.id = oreg.id
                    JOIN registrar ON registrar.id = object.clid
                    JOIN nsset_contact_map ON nsset_contact_map.nssetid = oreg.id
                    LEFT JOIN domains_by_nsset_view domains ON domains.nsset = oreg.id
                WHERE oreg.type = %(objtype)d
                    AND nsset_contact_map.contactid = %(contact_id)d
                LIMIT %(limit)d OFFSET %(offset)d
            ) AS reg

                UNION ALL

            SELECT
                stat.id,
                NULL::varchar,
                NULL::integer,
                NULL::varchar,
                NULL::varchar,
                stat.importance,
                stat.description
            FROM (
                SELECT
                    oreg.id,
                    array_agg(es.importance) AS importance,
                    array_agg(des.description) AS description
                FROM object_registry oreg
                    JOIN object ON object.id = oreg.id
                    JOIN nsset_contact_map ON nsset_contact_map.nssetid = oreg.id
                    LEFT JOIN object_state os ON os.object_id = oreg.id
                        AND os.valid_from <= CURRENT_TIMESTAMP
                        AND (os.valid_to IS NULL OR os.valid_to > CURRENT_TIMESTAMP)
                    JOIN enum_object_states es ON os.state_id = es.id AND es.external = 't'
                    JOIN enum_object_states_desc des ON os.state_id = des.state_id AND des.lang = %(lang)s
                WHERE oreg.type = %(objtype)d
                    AND nsset_contact_map.contactid = %(contact_id)d
                GROUP BY oreg.id
            ) AS stat
            """,
                dict(objtype=OBJECT_REGISTRY_TYPES['nsset'], contact_id=contact.id,
                     lang=lang, limit=self.list_limit + 1, offset=offset)):

            if row[Cols.HANDLE] is not None:
                if counter < self.list_limit:
                    position[row[Cols.OBJECT_ID]] = len(result)
                    row[Cols.OBJECT_ID] = str(row[Cols.OBJECT_ID])
                    row[Cols.NUM_OF_DOMAINS] = "0" if row[Cols.NUM_OF_DOMAINS] is None else "%d" % row[Cols.NUM_OF_DOMAINS]
                    row[Cols.STATUS_IMPORTANCE] = str_minimal_status_importance
                    row[Cols.STATUS_DESC] = ""
                    result.append(row)
                counter += 1
            else:
                try:
                    pos = position[row[Cols.OBJECT_ID]]
                except KeyError:
                    pass
                else:
                    importances = parse_pg_array(row[Cols.STATUS_IMPORTANCE], True)
                    descriptions = parse_pg_array(row[Cols.STATUS_DESC])
                    if len(importances):
                        imps = [(minimal_status_importance if num == 0 else num) for num in importances]
                        status_sorted_by_importance = [desc for num, desc in sorted(zip(imps, descriptions))]
                    else:
                        status_sorted_by_importance = []
                    importance = 0
                    for num in importances:
                        importance |= num
                    if importance == 0:
                        importance = minimal_status_importance
                    record = result[pos]
                    record[Cols.STATUS_IMPORTANCE] = str(importance)
                    record[Cols.STATUS_DESC] = "|".join(status_sorted_by_importance)

        self.logger.log(self.logger.INFO, 'NssetInterface.getNssetList(id=%d and handle="%s") has %d rows.' % (contact.id, contact.handle, len(result)))
        return result, counter > self.list_limit


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
        results = self.browser.threading_local.source.fetchall("""
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
                JOIN object obj ON obj.id = oreg.id
                JOIN nsset ON nsset.id = oreg.id

                JOIN registrar creator ON creator.id = oreg.crid
                JOIN registrar current ON current.id = obj.clid
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
        for row in self.browser.threading_local.source.fetchall("""
            SELECT
                object_registry.id,
                object_registry.name,
                CASE WHEN contact.organization IS NOT NULL AND LENGTH(contact.organization) > 0 THEN
                    contact.organization ELSE contact.name
                END
            FROM nsset_contact_map
            JOIN object_registry ON object_registry.id = nsset_contact_map.contactid
            JOIN contact ON contact.id = nsset_contact_map.contactid
            WHERE nssetid = %(obj_id)d
            ORDER BY object_registry.name
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
        for row_host in self.browser.threading_local.source.fetchall("""
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
                objreg.id,
                objreg.name
            FROM object_registry objreg
            JOIN nsset_contact_map map ON map.nssetid = objreg.id
            WHERE type = %(objtype)d
                AND map.contactid = %(contact_id)d
                AND objreg.id IN %(selections)s
            """)


    def _object_belongs_to_contact(self, contact_id, contact_handle, object_id, source=None):
        "Check if object belongs to the contact."
        if source is None:
            source = self.browser.threading_local.source
        admins = source.fetch_array("""
            SELECT object_registry.name
            FROM nsset_contact_map
            JOIN object_registry ON object_registry.id = nsset_contact_map.contactid
            WHERE nssetid = %(object_id)d
            """, dict(object_id=object_id))

        if contact_handle not in admins:
            self.logger.log(self.logger.INFO, "Nsset ID %d does not belong to the handle '%s' with ID %d." % (object_id, contact_handle, contact_id))
            raise Registry.DomainBrowser.ACCESS_DENIED
