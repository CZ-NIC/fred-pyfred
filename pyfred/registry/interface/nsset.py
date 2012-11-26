#!/usr/bin/python
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import ListMetaInterface
from pyfred.registry.utils import parse_array_agg
from pyfred.registry.utils.decorators import furnish_database_cursor_m, \
            normalize_contact_handle_m, normalize_handles_m
from pyfred.registry.utils.constants import EnunObjectStates


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


    @normalize_contact_handle_m
    @furnish_database_cursor_m
    def getNssetList(self, handle):
        "List of nssets"
        nsset_id = self._getHandleId(handle, "SELECT id FROM object_registry WHERE name = %(handle)s")
        self.logger.log(self.logger.DEBUG, "Found nsset ID %d of the handle '%s'." % (nsset_id, handle))

        self.cursor.execute("""
            CREATE OR REPLACE TEMPORARY VIEW domains_by_nsset_view AS
            SELECT nsset, COUNT(nsset) AS number FROM domain GROUP BY nsset""")

        self._group_object_states()

        NSSET_ID, NSSET_HANDLE, NUM_OF_DOMAINS, OBJ_STATES = range(4)
        UPDATE_PROHIBITED, TRANSFER_PROHIBITED = 3, 4
        result = []
        for row in self.cursor.fetchall("""
                SELECT
                    object_registry.id,
                    object_registry.name,
                    domains.number,
                    object_states_view.states,
                    ''
                FROM object_registry
                LEFT JOIN domains_by_nsset_view domains ON domains.nsset = object_registry.id
                LEFT JOIN object_states_view ON object_states_view.id = object_registry.id
                WHERE object_registry.id = %(nsset_id)d
                LIMIT %(limit)d""",
                dict(nsset_id=nsset_id, limit=self.limits["list_nssets"])):

            # Parse 'states' from "{serverTransferProhibited,serverUpdateProhibited}" or "{NULL}":
            obj_states = parse_array_agg(row[OBJ_STATES])

            row[NSSET_ID] = "%d" % row[NSSET_ID]
            row[NUM_OF_DOMAINS] = "%d" % row[NUM_OF_DOMAINS]
            row[UPDATE_PROHIBITED] = "t" if EnunObjectStates.server_update_prohibited in obj_states else "f"
            row[TRANSFER_PROHIBITED] = "t" if EnunObjectStates.server_transfer_prohibited in obj_states else "f"
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
        self.logger.log(self.logger.DEBUG, 'Call NssetInterface.getNssetDetail(nsset="%s", handle="%s")' % (nsset, handle))

        PUBLIC_DATA, PRIVATE_DATA = range(2)
        return (Registry.DomainBrowser.NSSetDetail(
                id=130,
                handle=handle,
                roid='C0000000003-CZ',
                registrar='REG-DESIGNATED',
                create_date='2012-03-14 11:16:28.516926',
                transfer_date='',
                update_date='',
                create_registrar='REG-CREATED',
                update_registrar='',
                auth_info='password',
                admins=('CONTACT04',),
                hosts=(
                    Registry.DomainBrowser.DNSHost("a.ns.nic.cz", "193.29.206.1 2001:678:1::1"),
                    Registry.DomainBrowser.DNSHost("b.ns.nic.cz", "196.30.208.2 2001:677:1::2")
                ),
                status_list = (),
                report_level=0
                ),
                Registry.DomainBrowser.DataAccessLevel._item(PRIVATE_DATA))
