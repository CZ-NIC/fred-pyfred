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
    def getNssetList(self, contact_handle, lang, offset):
        "List of nssets"
        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.INFO, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))

        self.source.execute("""
            CREATE OR REPLACE TEMPORARY VIEW domains_by_nsset_view AS
            SELECT nsset, COUNT(nsset) AS number
            FROM domain
            LEFT JOIN domain_contact_map ON domain_contact_map.domainid = domain.id
                      AND domain_contact_map.role = %(role_id)d
                      AND domain_contact_map.contactid = %(contact_id)d
            WHERE domain_contact_map.contactid = %(contact_id)d
                OR domain.registrant = %(contact_id)d
            GROUP BY nsset
            """, dict(contact_id=contact_id, role_id=DOMAIN_ROLE["admin"]))

        NSSET_HANDLE, STATES, NUM_OF_DOMAINS = range(3)
        result, counter, limit_exceeded = [], 0, False
        for row in self.source.fetchall("""
                SELECT
                    object_registry.name,
                    external_state_description(nsset_contact_map.nssetid, %(lang)s) AS status_list,
                    domains.number,
                    registrar.handle,
                    registrar.name AS registrar_name
                FROM object_registry
                    LEFT JOIN domains_by_nsset_view domains ON domains.nsset = object_registry.id
                    LEFT JOIN nsset_contact_map ON nsset_contact_map.nssetid = object_registry.id
                    LEFT JOIN object ON object.id = object_registry.id
                    LEFT JOIN registrar ON registrar.id = object.clid
                WHERE object_registry.type = %(objtype)d
                    AND nsset_contact_map.contactid = %(contact_id)d
                LIMIT %(limit)d OFFSET %(offset)d
                """,
                dict(objtype=OBJECT_REGISTRY_TYPES['nsset'], contact_id=contact_id,
                     lang=lang, limit=self.list_limit + 1, offset=offset)):

            counter += 1
            if counter > self.list_limit:
                limit_exceeded = True
                break

            row[NUM_OF_DOMAINS] = "0" if row[NUM_OF_DOMAINS] is None else "%d" % row[NUM_OF_DOMAINS]
            result.append(row)

        self.logger.log(self.logger.INFO, 'NssetInterface.getNssetList(handle="%s") has %d rows.' % (contact_handle, len(result)))
        return result, limit_exceeded


    @furnish_database_cursor_m
    def getNssetDetail(self, contact_handle, nsset, lang):
        """
        struct NSSetDetail {
            TID id;
            string handle;
            string roid;
            Couple registrar;
            string create_date;
            string transfer_date;
            string update_date;
            Couple create_registrar;
            Couple update_registrar;
            string auth_info;
            CoupleSeq admins;
            sequence<DNSHost> hosts;
            string states;
            string state_codes;
            short report_level;
        };
        """
        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.INFO, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))

        results = self.source.fetchall("""
            SELECT
                oreg.id AS id,
                oreg.name AS handle,
                oreg.roid AS roid,

                oreg.crdate AS create_date,
                obj.trdate AS transfer_date,
                obj.update AS update_date,

                obj.authinfopw AS auth_info,
                external_state_description(oreg.id, %(lang)s) AS states,
                get_object_states(oreg.id) AS state_codes,
                nsset.checklevel,

                current.handle AS registrar_handle,
                current.name AS registrar_name,

                creator.handle AS create_registrar_handle,
                creator.name AS create_registrar_name,

                updator.handle AS update_registrar_handle,
                updator.name AS update_registrar_name

            FROM object_registry oreg
                LEFT JOIN object obj ON obj.id = oreg.id
                LEFT JOIN nsset ON nsset.id = oreg.id

                LEFT JOIN registrar creator ON creator.id = oreg.crid
                LEFT JOIN registrar current ON current.id = obj.clid
                LEFT JOIN registrar updator ON updator.id = obj.upid

            WHERE oreg.type = %(type_id)d AND oreg.name = %(nsset)s
        """, dict(nsset=nsset, type_id=OBJECT_REGISTRY_TYPES["nsset"], lang=lang))

        if len(results) == 0:
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Nsset detail of '%s' does not have one record: %s" % (nsset, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        TID, PASSWORD = 0, 6
        nsset_detail = results[0]
        registrar = {
            "updator": {
                "name": none2str(nsset_detail.pop()),
                "handle": none2str(nsset_detail.pop()),
            },
            "creator": {
                "name": none2str(nsset_detail.pop()),
                "handle": none2str(nsset_detail.pop()),
            },
            "current": {
                "name": none2str(nsset_detail.pop()),
                "handle": none2str(nsset_detail.pop()),
            },
        }
        report_level = nsset_detail.pop()

        owner = False
        admins = [] # Registry.DomainBrowser.CoupleSeq
        for row in self.source.fetchall("""
            SELECT object_registry.name,
                CASE WHEN contact.organization IS NOT NULL AND LENGTH(contact.organization) > 0 THEN
                    contact.organization ELSE contact.name
                END
            FROM nsset_contact_map
            LEFT JOIN object_registry ON object_registry.id = nsset_contact_map.contactid
            LEFT JOIN contact ON contact.id = nsset_contact_map.contactid
            WHERE nssetid = %(obj_id)d
            """, dict(obj_id=nsset_detail[TID])):
            admins.append(Registry.DomainBrowser.Couple(none2str(row[0]), none2str(row[1])))
            if contact_handle == row[0]:
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

        for key in ("current", "creator", "updator"):
            nsset_detail.append(Registry.DomainBrowser.Couple(registrar[key]["handle"], registrar[key]["name"]))
        nsset_detail.append(admins)
        nsset_detail.append(hosts)
        nsset_detail.append(report_level)

        # replace None by empty string
        nsset_detail = ['' if value is None else value for value in nsset_detail]

        columns = ("id", "handle", "roid", "create_date", "transfer_date", "update_date",
                   "auth_info", "states", "state_codes", "registrar", "create_registrar", "update_registrar",
                   "admins", "hosts", "report_level")
        data = dict(zip(columns, nsset_detail))

        return (Registry.DomainBrowser.NSSetDetail(**data), data_type)


    def setObjectBlockStatus(self, contact_handle, objtype, selections, action):
        "Set object block status."
        return self._setObjectBlockStatus(contact_handle, objtype, selections, action,
            """
            SELECT
                objreg.name,
                objreg.id
            FROM object_registry objreg
            LEFT JOIN nsset_contact_map map ON map.nssetid = objreg.id
            WHERE type = %(objtype)d
                AND map.contactid = %(contact_id)d
                AND name IN %(names)s
            """)


    def _object_belongs_to_contact(self, contact_id, contact_handle, object_id):
        "Check if object belongs to the contact."
        admins = self.source.fetch_array("""
            SELECT object_registry.name
            FROM nsset_contact_map
            LEFT JOIN object_registry ON object_registry.id = nsset_contact_map.contactid
            WHERE nssetid = %(object_id)d
            """, dict(object_id=object_id))

        if contact_handle not in admins:
            self.logger.log(self.logger.INFO, "Nsset ID %d does not belong to the handle '%s' with ID %d." % (object_id, contact_handle, contact_id))
            raise Registry.DomainBrowser.ACCESS_DENIED
