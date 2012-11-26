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
        self.logger.log(self.logger.DEBUG, 'Call KeysetInterface.getKeysetDetail(handle="%s", keyset="%s")' % (handle, keyset))

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
                registrant.name AS registrant

            FROM object_registry oreg
                LEFT JOIN object obj ON obj.id = oreg.id
                LEFT JOIN domain ON oreg.id = domain.keyset
                LEFT JOIN object_registry registrant ON registrant.id = domain.registrant

                LEFT JOIN registrar creator ON creator.id = oreg.crid
                LEFT JOIN registrar current ON current.id = obj.clid
                LEFT JOIN registrar updator ON updator.id = obj.upid

            WHERE oreg.name = %(keyset)s
        """, dict(keyset=keyset))

        if len(results) == 0:
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Keyset detail of '%s' does not have one record: %s" % (keyset, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        status_list = self._get_status_list(keyset)
        self.logger.log(self.logger.DEBUG, "Keyset '%s' has states: %s." % (keyset, status_list))

        TID, PASSWORD = 0, 9

        keyset_detail = results[0]
        registrant = keyset_detail.pop()

        if registrant == handle:
            # owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PRIVATE_DATA)
        else:
            # not owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PUBLIC_DATA)
            keyset_detail[PASSWORD] = self.PASSWORD_SUBSTITUTION

        admins = self.source.fetchall("""
            SELECT object_registry.name
            FROM keyset_contact_map
            LEFT JOIN object_registry ON object_registry.id = keyset_contact_map.contactid
            WHERE keysetid = %(obj_id)d
            """, dict(obj_id=keyset_detail[TID]))

        dsrecords = []
        columns = ("key_tag", "alg", "digest_type", "digest", "max_sig_life")
        for row_dsrec in self.source.fetchall("""
                SELECT
                    keytag, alg, digesttype, digest, maxsiglife
                FROM dsrecord
                WHERE keysetid = %(keyset_id)d""",
                dict(keyset_id=keyset_detail[TID])):
            data = dict(zip(columns, row_dsrec))
            dsrecords.append(Registry.DomainBrowser.DSRecord(**data))

        dnskeys = []
        columns = ("flags", "protocol", "alg", "key")
        for row_dsrec in self.source.fetchall("""
                SELECT
                    flags, protocol, alg, key
                FROM dnskey
                WHERE keysetid = %(keyset_id)d""",
                dict(keyset_id=keyset_detail[TID])):
            data = dict(zip(columns, row_dsrec))
            dnskeys.append(Registry.DomainBrowser.DNSKey(**data))

        keyset_detail.append([row[0] for row in admins])
        keyset_detail.append(dsrecords)
        keyset_detail.append(dnskeys)
        keyset_detail.append(status_list)

        # replace None by empty string
        keyset_detail = ['' if value is None else value for value in keyset_detail]

        columns = ("id", "handle", "roid", "registrar", "create_date", "transfer_date",
                   "update_date", "create_registrar", "update_registrar", "auth_info",
                   "admins", "dsrecords", "dnskeys", "status_list")
        data = dict(zip(columns, keyset_detail))

        return (Registry.DomainBrowser.KeysetDetail(**data), data_type)
