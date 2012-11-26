#!/usr/bin/python
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import ListMetaInterface
from pyfred.registry.utils import parse_array_agg
from pyfred.registry.utils.decorators import furnish_database_cursor_m, \
            normalize_object_handle_m, normalize_handles_m
from pyfred.registry.utils.constants import EnunObjectStates



class KeysetInterface(ListMetaInterface):
    "Keyset corba interface."

    def getKeysetListMeta(self):
        "Get Keyset List Meta"
        return self._getObjectListMeta((
                            ("keyset_handle",    "TEXT"),
                            ("domain_count",     "INT"),
                            ("blocked_update",   "BOOL"),
                            ("blocked_transfer", "BOOL"),
                        ))

    @normalize_object_handle_m
    @furnish_database_cursor_m
    def getKeysetList(self, handle):
        "List of keysets"
        keyset_id = self._getHandleId(handle, "SELECT id FROM object_registry WHERE name = %(handle)s")
        self.logger.log(self.logger.DEBUG, "Found keyset ID %d of the handle '%s'." % (keyset_id, handle))

        self.source.execute("""
            CREATE OR REPLACE TEMPORARY VIEW domains_by_keyset_view AS
            SELECT keyset, COUNT(keyset) AS number FROM domain GROUP BY keyset""")

        self._group_object_states()

        KEYSET_ID, KEYSET_HANDLE, NUM_OF_DOMAINS, OBJ_STATES = range(4)
        UPDATE_PROHIBITED, TRANSFER_PROHIBITED = 3, 4
        result = []
        for row in self.source.fetchall("""
                SELECT
                    object_registry.id,
                    object_registry.name,
                    domains.number,
                    object_states_view.states,
                    ''
                FROM object_registry
                LEFT JOIN domains_by_keyset_view domains ON domains.keyset = object_registry.id
                LEFT JOIN object_states_view ON object_states_view.id = object_registry.id
                WHERE object_registry.id = %(keyset_id)d
                LIMIT %(limit)d""",
                dict(keyset_id=keyset_id, limit=self.limits["list_keysets"])):

            # Parse 'states' from "{serverTransferProhibited,serverUpdateProhibited}" or "{NULL}":
            obj_states = parse_array_agg(row[OBJ_STATES])

            row[KEYSET_ID] = "%d" % row[KEYSET_ID]
            row[NUM_OF_DOMAINS] = "%d" % row[NUM_OF_DOMAINS]
            row[UPDATE_PROHIBITED] = "t" if EnunObjectStates.server_update_prohibited in obj_states else "f"
            row[TRANSFER_PROHIBITED] = "t" if EnunObjectStates.server_transfer_prohibited in obj_states else "f"
            result.append(row)

        self.logger.log(self.logger.DEBUG, 'KeysetInterface.getKeysetList(handle="%s") has %d rows.' % (handle, len(result)))
        return result

        return []

    @normalize_handles_m(((0, "handle"), (1, "keyset")))
    @furnish_database_cursor_m
    def getKeysetDetail(self, handle, keyset):
        """
        struct KeysetDetail {
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
            sequence<DSRecord> dsrecords;
            sequence<DNSKey> dnskeys;
            ObjectStatusSeq  status_list;
        };

        struct DSRecord
        {
            long key_tag;
            long alg;
            long digest_type;
            string digest;
            long max_sig_life;
        };

        struct DNSKey
        {
            unsigned short flags;
            unsigned short protocol;
            unsigned short alg;
            string         key;
        };
        """
        self.logger.log(self.logger.DEBUG, 'Call KeysetInterface.getKeysetDetail(keyset="%s", handle="%s")' % (keyset, handle))

        key = "BQEAAAABt3LenoCVTV0okqKYPDnnVJqvwCD9MKJNXg8fcOCdLQYncyoehpwM5RK2UkZDcDxWkMo7yMa35ej+Mhpa" \
              "ji9si4xXD+Syl4Q06LFiFkdN/5GlVlrIdE3GW7zC7Z4sS14Vz8FbYfcRmhsh19Ob718jGZneGfw2UPbvkyxUR8wD" \
              "7mguZn02fQ6tjj/Ktp4uSW9tpz3bjGMo2rX+iZk4xgbPaesAOlR/AaHdatGZsWC9CPon8mnLZeu6czm8CBDgBmnf" \
              "3PE8c5+uyWj1Pw4pp0VQmnX5UrnuGpErg7qXhJm7wY2CRVRMcLX3zmjVWXW1uT9JFh2G+/pZzxnASfKKltZpuw=="

        PUBLIC_DATA, PRIVATE_DATA = range(2)
        return (Registry.DomainBrowser.KeysetDetail(
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
                dsrecords = (
                    Registry.DomainBrowser.DSRecord(27979, 5, 1, 'FF11E740A0254EC63C738A47E52ABF3AD91D8C43', 0),
                    Registry.DomainBrowser.DSRecord(27980, 5, 1, 'AA11E740A0254EC63C738A47E52ABF3AD91D8C00', 0),
                    ),
                dnskeys = (
                    Registry.DomainBrowser.DNSKey(257, 3, 5, key),
                    Registry.DomainBrowser.DNSKey(256, 4, 6, key),
                ),

                status_list = (),
                ),
                Registry.DomainBrowser.DataAccessLevel._item(PRIVATE_DATA))
