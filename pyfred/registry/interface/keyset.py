#!/usr/bin/python
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import BaseInterface
from pyfred.registry.utils import none2str
from pyfred.registry.utils.decorators import furnish_database_cursor_m
from pyfred.registry.utils.constants import DOMAIN_ROLE, OBJECT_REGISTRY_TYPES, ENUM_OBJECT_STATES



class KeysetInterface(BaseInterface):
    "Keyset corba interface."

    @furnish_database_cursor_m
    def getKeysetList(self, contact, lang, offset, source=None):
        "List of keysets"
        self._verify_user_contact(source, contact)
        str_minimal_status_importance = str(self.get_status_minimal_importance(source))

        class Cols:
            OBJECT_ID, HANDLE, NUM_OF_DOMAINS, REG_HANDLE, REG_NAME, STATUS_IMPORTANCE, STATUS_DESC, UPDATE_DISABLED = range(8)

        UPDATE_PROHIBITED, TRANSFER_PROHIBITED = 2, 3
        result, counter, limit_exceeded = [], 0, False
        #CREATE OR REPLACE VIEW domains_by_keyset_view AS
        #    SELECT keyset, COUNT(keyset) AS number FROM domain WHERE keyset IS NOT NULL GROUP BY keyset
        found = {}
        for row in source.fetchall("""
            SELECT
                oreg.id,
                oreg.name,
                domains.number,
                registrar.handle,
                registrar.name AS registrar_name
            FROM object_registry oreg
                JOIN object ON object.id = oreg.id
                JOIN keyset_contact_map ON keyset_contact_map.keysetid = oreg.id
                JOIN registrar ON registrar.id = object.clid
                LEFT JOIN domains_by_keyset_view domains ON domains.keyset = oreg.id
            WHERE oreg.type = %(objtype)d
                AND keyset_contact_map.contactid = %(contact_id)d
            ORDER BY oreg.id
            LIMIT %(limit)d OFFSET %(offset)d""",
                dict(objtype=OBJECT_REGISTRY_TYPES['keyset'], contact_id=contact.id,
                     limit=self.list_limit + 1, offset=offset)):

            if counter < self.list_limit:
                found[row[Cols.OBJECT_ID]] = len(result)
                row[Cols.OBJECT_ID] = str(row[Cols.OBJECT_ID])
                row[Cols.NUM_OF_DOMAINS] = "0" if row[Cols.NUM_OF_DOMAINS] is None else "%d" % row[Cols.NUM_OF_DOMAINS]
                row.append(str_minimal_status_importance) # Cols.STATUS_IMPORTANCE
                row.append("") # Cols.STATUS_DESC
                row.append("f") # Cols.UPDATE_DISABLED
                result.append(row)
            counter += 1

        self.appendStatus(source, result, found, lang, Cols.STATUS_IMPORTANCE, Cols.STATUS_DESC, Cols.UPDATE_DISABLED)

        self.logger.log(self.logger.INFO, 'KeysetInterface.getKeysetList(id=%d and handle="%s") has %d rows.' % (contact.id, contact.handle, len(result)))
        return result, counter > self.list_limit

        return []

    @furnish_database_cursor_m
    def getKeysetDetail(self, contact, keyset, lang, source=None):
        """
        struct KeysetDetail {
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
            sequence<DSRecord> dsrecords;
            sequence<DNSKey> dnskeys;
            string states;
            string state_codes;
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
        self._verify_user_contact(source, contact)

        keyset.lang = lang
        results = source.fetchall("""
            SELECT
                oreg.id AS id,
                oreg.name AS handle,
                oreg.roid AS roid,

                oreg.crdate AS create_date,
                obj.trdate AS transfer_date,
                obj.update AS update_date,

                obj.authinfopw AS auth_info,
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

                JOIN registrar creator ON creator.id = oreg.crid
                JOIN registrar current ON current.id = obj.clid
                LEFT JOIN registrar updator ON updator.id = obj.upid

            WHERE oreg.id = %(object_id)d
                AND oreg.name = %(handle)s
                AND oreg.type = %(type_id)d
                AND oreg.erdate IS NULL
        """, keyset.__dict__)

        if len(results) == 0:
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Keyset detail of '%s' does not have one record: %s" % (keyset, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        TID, HANDLE, NAME, PASSWORD = 0, 1, 2, 6
        keyset_detail = results[0]
        registrars = self._pop_registrars_from_detail(keyset_detail) # pop some columns from the detail here
        state_codes, state_importance, state_descriptions = self.parse_states(source, keyset_detail.pop())

        owner = False
        admins = [] # Registry.DomainBrowser.CoupleSeq
        for row in source.fetchall("""
            SELECT
                object_registry.id,
                object_registry.name,
                CASE WHEN contact.organization IS NOT NULL AND LENGTH(contact.organization) > 0 THEN
                    contact.organization ELSE contact.name
                END
            FROM keyset_contact_map
            JOIN object_registry ON object_registry.id = keyset_contact_map.contactid
            JOIN contact ON contact.id = keyset_contact_map.contactid
            WHERE keysetid = %(obj_id)d
            ORDER BY object_registry.name
            """, dict(obj_id=keyset_detail[TID])):
            admins.append(Registry.DomainBrowser.RegistryReference(long(row[TID]), none2str(row[HANDLE]), none2str(row[NAME])))
            if contact.handle == row[HANDLE]:
                owner = True

        if owner:
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PRIVATE_DATA)
        else:
            # public version
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PUBLIC_DATA)
            keyset_detail[PASSWORD] = self.PASSWORD_SUBSTITUTION

        dsrecords = []
        columns = ("key_tag", "alg", "digest_type", "digest", "max_sig_life")
        for row_dsrec in source.fetchall("""
                SELECT
                    keytag, alg, digesttype, digest, maxsiglife
                FROM dsrecord
                WHERE keysetid = %(keyset_id)d""",
                dict(keyset_id=keyset_detail[TID])):
            data = dict(zip(columns, row_dsrec))
            dsrecords.append(Registry.DomainBrowser.DSRecord(**data))

        dnskeys = []
        columns = ("flags", "protocol", "alg", "key")
        for row_dsrec in source.fetchall("""
                SELECT
                    flags, protocol, alg, key
                FROM dnskey
                WHERE keysetid = %(keyset_id)d""",
                dict(keyset_id=keyset_detail[TID])):
            data = dict(zip(columns, row_dsrec))
            dnskeys.append(Registry.DomainBrowser.DNSKey(**data))

        keyset_detail.extend(registrars)
        keyset_detail.append(admins)
        keyset_detail.append(dsrecords)
        keyset_detail.append(dnskeys)
        keyset_detail.append(state_codes)
        #keyset_detail.append(state_importance)
        keyset_detail.append(state_descriptions)

        # replace None by empty string
        keyset_detail = ['' if value is None else value for value in keyset_detail]

        columns = ("id", "handle", "roid", "create_date", "transfer_date", "update_date",
                   "auth_info", "registrar", "create_registrar", "update_registrar",
                   "admins", "dsrecords", "dnskeys", "state_codes", "states")
        data = dict(zip(columns, keyset_detail))

        return (Registry.DomainBrowser.KeysetDetail(**data), data_type)


    def setObjectBlockStatus(self, contact_handle, objtype, selections, action):
        "Set object block status."
        return self._setObjectBlockStatus(contact_handle, objtype, selections, action,
            """
            SELECT
                objreg.id,
                objreg.name
            FROM object_registry objreg
            JOIN keyset_contact_map map ON map.keysetid = objreg.id
            WHERE type = %(objtype)d
                AND map.contactid = %(contact_id)d
                AND objreg.id IN %(selections)s
            """)


    def _object_belongs_to_contact(self, source, contact_id, contact_handle, object_id):
        "Check if object belongs to the contact."
        admins = source.fetch_array("""
            SELECT object_registry.name
            FROM keyset_contact_map
            JOIN object_registry ON object_registry.id = keyset_contact_map.contactid
            WHERE keysetid = %(object_id)d
            """, dict(object_id=object_id))

        if contact_handle not in admins:
            self.logger.log(self.logger.INFO, "Keyset ID %d does not belong to the handle '%s' with ID %d." % (object_id, contact_handle, contact_id))
            raise Registry.DomainBrowser.ACCESS_DENIED
