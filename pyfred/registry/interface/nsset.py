#!/usr/bin/python
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import ListMetaInterface
from pyfred.registry.utils import parse_array_agg
from pyfred.registry.utils.decorators import furnish_database_cursor_m, \
            normalize_object_handle_m, normalize_handles_m
from pyfred.registry.utils.constants import EnunObjectStates, OBJECT_REGISTRY_TYPES



class NssetInterface(ListMetaInterface):
    "NSSET corba interface."

    def getNssetListMeta(self):
        "Get Nsset List Meta"
        return self._getObjectListMeta((
                            ("nsset_handle",     "TEXT"),
                            ("domain_count",     "INT"),
                            ("blocked_update",   "BOOL"),
                            ("blocked_transfer", "BOOL"),
                        ))


    @normalize_object_handle_m
    @furnish_database_cursor_m
    def getNssetList(self, handle):
        "List of nssets"
        contact_id = self._getContactHandleId(handle)
        self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, handle))

        self.source.execute("""
            CREATE OR REPLACE TEMPORARY VIEW domains_by_nsset_view AS
            SELECT nsset, COUNT(nsset) AS number FROM domain GROUP BY nsset""")

        self._group_object_states()

        NSSET_HANDLE, NUM_OF_DOMAINS, OBJ_STATES = range(3)
        UPDATE_PROHIBITED, TRANSFER_PROHIBITED = 2, 3
        result = []
        for row in self.source.fetchall("""
                SELECT
                    object_registry.name,
                    domains.number,
                    object_states_view.states
                FROM object_registry
                    LEFT JOIN domains_by_nsset_view domains ON domains.nsset = object_registry.id
                    LEFT JOIN object_states_view ON object_states_view.id = object_registry.id
                    LEFT JOIN nsset_contact_map ON nsset_contact_map.nssetid = object_registry.id
                WHERE object_registry.type = %(objtype)d
                    AND nsset_contact_map.contactid = %(contact_id)d
                LIMIT %(limit)d
                """,
                dict(objtype=OBJECT_REGISTRY_TYPES['nsset'], contact_id=contact_id,
                     limit=self.list_limit)):

            # row: ['KONTAKT', None, '{linked}']
            # Parse 'states' from "{serverTransferProhibited,serverUpdateProhibited}" or "{NULL}":
            obj_states = parse_array_agg(row[OBJ_STATES])

            row[NUM_OF_DOMAINS] = "0" if row[NUM_OF_DOMAINS] is None else "%d" % row[NUM_OF_DOMAINS]
            row[UPDATE_PROHIBITED] = "t" if EnunObjectStates.server_update_prohibited in obj_states else "f"
            row.append("t" if EnunObjectStates.server_transfer_prohibited in obj_states else "f")

            result.append(row)

        self.logger.log(self.logger.DEBUG, 'NssetInterface.getNssetList(handle="%s") has %d rows.' % (handle, len(result)))
        return result


    @normalize_handles_m(((0, "handle"), (1, "nsset")))
    @furnish_database_cursor_m
    def getNssetDetail(self, handle, nsset):
        """
        struct NSSetDetail {
            TID id;
            string handle;
            string roid;
            string registrar;
            string create_date;
            string transfer_date;
            string update_date;
            string create_registrar;
            string update_registrar;
            string auth_info;
            ContactHandleSeq admins;
            sequence<DNSHost> hosts;
            ObjectStatusSeq status_list;
            short report_level;
        };
        """
        self.logger.log(self.logger.DEBUG, 'Call NssetInterface.getNssetDetail(handle="%s", nsset="%s")' % (handle, nsset))

        contact_id = self._getContactHandleId(handle)
        self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, handle))

        results = self.source.fetchall("""
            SELECT
                oreg.id AS id,
                oreg.name AS handle,
                oreg.roid AS roid,

                current.handle AS registrar,

                oreg.crdate AS create_date,
                obj.trdate AS transfer_date,
                obj.update AS update_date,

                creator.handle AS create_registrar,
                updator.handle AS update_registrar,

                obj.authinfopw AS auth_info,
                registrant.name AS registrant,
                nsset.checklevel

            FROM object_registry oreg
                LEFT JOIN object obj ON obj.id = oreg.id
                LEFT JOIN nsset ON nsset.id = oreg.id
                LEFT JOIN domain ON oreg.id = domain.nsset
                LEFT JOIN object_registry registrant ON registrant.id = domain.registrant

                LEFT JOIN registrar creator ON creator.id = oreg.crid
                LEFT JOIN registrar current ON current.id = obj.clid
                LEFT JOIN registrar updator ON updator.id = obj.upid

            WHERE oreg.name = %(nsset)s
        """, dict(nsset=nsset))

        if len(results) == 0:
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Nsset detail of '%s' does not have one record: %s" % (nsset, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        status_list = self._get_status_list(nsset)
        self.logger.log(self.logger.DEBUG, "Nsset '%s' has states: %s." % (nsset, status_list))

        TID, PASSWORD = 0, 9

        nsset_detail = results[0]
        report_level = nsset_detail.pop()
        registrant = nsset_detail.pop()

        if registrant == handle:
            # owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PRIVATE_DATA)
        else:
            # not owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PUBLIC_DATA)
            nsset_detail[PASSWORD] = self.PASSWORD_SUBSTITUTION

        admins = self.source.fetchall("""
            SELECT object_registry.name
            FROM nsset_contact_map
            LEFT JOIN object_registry ON object_registry.id = nsset_contact_map.contactid
            WHERE nssetid = %(obj_id)d
            """, dict(obj_id=nsset_detail[TID]))

        hosts = []
        for row_host in self.source.fetchall("""
                SELECT
                    MIN(host.fqdn),
                    array_agg(host_ipaddr_map.ipaddr)
                FROM host_ipaddr_map
                LEFT JOIN host ON host_ipaddr_map.hostid = host.id
                WHERE host_ipaddr_map.nssetid = %(nsset_id)d
                GROUP BY host_ipaddr_map.hostid""", dict(nsset_id=nsset_detail[TID])):
            #     min     |  array_agg
            #-------------+--------------
            # a.ns.nic.cz | {194.0.12.1,123.4.0.1}
            # b.ns.nic.cz | {194.0.13.1}
            # c.ns.nic.cz | {NULL}
            ip_address = parse_array_agg(row_host[1])
            hosts.append(Registry.DomainBrowser.DNSHost(fqdn=row_host[0], inet=", ".join(ip_address)))

        nsset_detail.append([row[0] for row in admins])
        nsset_detail.append(hosts)
        nsset_detail.append(status_list)
        nsset_detail.append(report_level)

        # replace None by empty string
        nsset_detail = ['' if value is None else value for value in nsset_detail]

        columns = ("id", "handle", "roid", "registrar", "create_date", "transfer_date",
                   "update_date", "create_registrar", "update_registrar", "auth_info",
                   "admins", "hosts", "status_list", "report_level")
        data = dict(zip(columns, nsset_detail))

        return (Registry.DomainBrowser.NSSetDetail(**data), data_type)
