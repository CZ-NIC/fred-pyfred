#!/usr/bin/python
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import ListMetaInterface
from pyfred.registry.utils import parse_array_agg_int, none2str
from pyfred.registry.utils.decorators import furnish_database_cursor_m
from pyfred.registry.utils.constants import DOMAIN_ROLE, OBJECT_REGISTRY_TYPES, ENUM_OBJECT_STATES



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

    @furnish_database_cursor_m
    def getKeysetList(self, contact_handle):
        "List of keysets"
        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.INFO, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))

        self.source.execute("""
            CREATE OR REPLACE TEMPORARY VIEW domains_by_keyset_view AS
            SELECT keyset, COUNT(keyset) AS number
            FROM domain
            LEFT JOIN domain_contact_map ON domain_contact_map.domainid = domain.id
                      AND domain_contact_map.role = %(role_id)d
                      AND domain_contact_map.contactid = %(contact_id)d
            WHERE domain_contact_map.contactid = %(contact_id)d
                OR domain.registrant = %(contact_id)d
            GROUP BY keyset
            """, dict(contact_id=contact_id, role_id=DOMAIN_ROLE["admin"]))

        KEYSET_HANDLE, NUM_OF_DOMAINS, OBJ_STATES = range(3)
        UPDATE_PROHIBITED, TRANSFER_PROHIBITED = 2, 3
        result, limit_exceeded = [], 0
        for row in self.source.fetchall("""
                SELECT
                    object_registry.name,
                    domains.number,
                    keyset_states.states
                FROM object_registry
                    LEFT JOIN domains_by_keyset_view domains ON domains.keyset = object_registry.id
                    LEFT JOIN keyset_states ON keyset_states.object_id = object_registry.id
                    LEFT JOIN keyset_contact_map ON keyset_contact_map.keysetid = object_registry.id
                WHERE object_registry.type = %(objtype)d
                    AND keyset_contact_map.contactid = %(contact_id)d
                LIMIT %(limit)d
                """,
                dict(objtype=OBJECT_REGISTRY_TYPES['keyset'], contact_id=contact_id,
                     limit=self.list_limit)):

            counter += 1
            if counter > self.list_limit:
                limit_exceeded = self.list_limit
                break

            # Parse 'states' from "{serverTransferProhibited,serverUpdateProhibited}" or "{NULL}":
            obj_states = parse_array_agg_int(row[OBJ_STATES])

            row[NUM_OF_DOMAINS] = "0" if row[NUM_OF_DOMAINS] is None else "%d" % row[NUM_OF_DOMAINS]
            row[UPDATE_PROHIBITED] = "t" if ENUM_OBJECT_STATES["serverUpdateProhibited"] in obj_states else "f"
            row.append("t" if ENUM_OBJECT_STATES["serverTransferProhibited"] in obj_states else "f")
            result.append(row)

        self.logger.log(self.logger.INFO, 'KeysetInterface.getKeysetList(handle="%s") has %d rows.' % (contact_handle, len(result)))
        return result, limit_exceeded

        return []

    @furnish_database_cursor_m
    def getKeysetDetail(self, contact_handle, keyset):
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

                current.handle AS registrar_handle,
                current.name AS registrar_name,

                creator.handle AS create_registrar_handle,
                creator.name AS create_registrar_name,

                updator.handle AS update_registrar_handle,
                updator.name AS update_registrar_name

            FROM object_registry oreg
                LEFT JOIN object obj ON obj.id = oreg.id

                LEFT JOIN registrar creator ON creator.id = oreg.crid
                LEFT JOIN registrar current ON current.id = obj.clid
                LEFT JOIN registrar updator ON updator.id = obj.upid

            WHERE oreg.type = %(type_id)d AND oreg.name = %(keyset)s
        """, dict(keyset=keyset, type_id=OBJECT_REGISTRY_TYPES["keyset"]))

        if len(results) == 0:
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Keyset detail of '%s' does not have one record: %s" % (keyset, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        status_list = self._get_status_list(keyset, "keyset")
        self.logger.log(self.logger.INFO, "Keyset '%s' has states: %s." % (keyset, status_list))

        TID, PASSWORD = 0, 6

        keyset_detail = results[0]
        registrar = {
            "updator": {
                "name": none2str(keyset_detail.pop()),
                "handle": none2str(keyset_detail.pop()),
            },
            "creator": {
                "name": none2str(keyset_detail.pop()),
                "handle": none2str(keyset_detail.pop()),
            },
            "current": {
                "name": none2str(keyset_detail.pop()),
                "handle": none2str(keyset_detail.pop()),
            },
        }

        owner = False
        admins = [] # Registry.DomainBrowser.CoupleSeq
        for row in self.source.fetchall("""
            SELECT object_registry.name,
                CASE WHEN contact.organization IS NOT NULL AND LENGTH(contact.organization) > 0 THEN
                    contact.organization ELSE contact.name
                END
            FROM keyset_contact_map
            LEFT JOIN object_registry ON object_registry.id = keyset_contact_map.contactid
            LEFT JOIN contact ON contact.id = keyset_contact_map.contactid
            WHERE keysetid = %(obj_id)d
            """, dict(obj_id=keyset_detail[TID])):
            admins.append(Registry.DomainBrowser.Couple(none2str(row[0]), none2str(row[1])))
            if contact_handle == row[0]:
                owner = True

        if owner:
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PRIVATE_DATA)
        else:
            # public version
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PUBLIC_DATA)
            keyset_detail[PASSWORD] = self.PASSWORD_SUBSTITUTION

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

        for key in ("current", "creator", "updator"):
            keyset_detail.append(Registry.DomainBrowser.Couple(registrar[key]["handle"], registrar[key]["name"]))
        keyset_detail.append(admins)
        keyset_detail.append(dsrecords)
        keyset_detail.append(dnskeys)
        keyset_detail.append(status_list)

        # replace None by empty string
        keyset_detail = ['' if value is None else value for value in keyset_detail]

        columns = ("id", "handle", "roid", "create_date", "transfer_date", "update_date",
                   "auth_info", "registrar", "create_registrar", "update_registrar",
                   "admins", "dsrecords", "dnskeys", "status_list")
        data = dict(zip(columns, keyset_detail))

        return (Registry.DomainBrowser.KeysetDetail(**data), data_type)


    def setObjectBlockStatus(self, contact_handle, objtype, selections, action):
        "Set object block status."
        return self._setObjectBlockStatus(contact_handle, objtype, selections, action,
            """
            SELECT
                objreg.name,
                objreg.id
            FROM object_registry objreg
            LEFT JOIN keyset_contact_map map ON map.keysetid = objreg.id
            WHERE type = %(objtype)d
                AND map.contactid = %(contact_id)d
                AND name IN %(names)s
            """)


    def _object_belongs_to_contact(self, contact_id, contact_handle, object_id):
        "Check if object belongs to the contact."
        admins = self.source.fetch_array("""
            SELECT object_registry.name
            FROM keyset_contact_map
            LEFT JOIN object_registry ON object_registry.id = keyset_contact_map.contactid
            WHERE keysetid = %(object_id)d
            """, dict(object_id=object_id))

        if contact_handle not in admins:
            self.logger.log(self.logger.INFO, "Keyset ID %d does not belong to the handle '%s' with ID %d." % (object_id, contact_handle, contact_id))
            raise Registry.DomainBrowser.ACCESS_DENIED
