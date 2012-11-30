#!/usr/bin/python
from pyfred.idlstubs import Registry
from pyfred.registry.utils import normalize_and_check_handle, normalize_and_check_domain
from pyfred.registry.utils.decorators import furnish_database_cursor_m, \
            normalize_object_handle_m
from pyfred.registry.utils.constants import ENUM_OBJECT_STATES, OBJECT_REGISTRY_TYPES
from pyfred.registry.utils.cursors import TransactionLevelRead



class BaseInterface(object):
    "Base interface object."

    PUBLIC_DATA, PRIVATE_DATA = range(2)
    BLOCK_TRANSFER, UNBLOCK_TRANSFER, \
    BLOCK_UPDATE, UNBLOCK_UPDATE, \
    BLOCK_TRANSFER_AND_UPDATE, UNBLOCK_TRANSFER_AND_UPDATE = range(6)

    PASSWORD_SUBSTITUTION = "********"

    INTERNAL_SERVER_ERROR = Registry.DomainBrowser.INTERNAL_SERVER_ERROR


    def __init__(self, database, logger, list_limit=None):
        self.database = database
        self.logger = logger
        self.list_limit = list_limit
        self.source = None

    def setObjectBlockStatus(self, handle, objtype, selections, action):
        "Set object block status."
        raise Registry.DomainBrowser.INCORRECT_USAGE

    @normalize_object_handle_m
    @furnish_database_cursor_m
    def _setObjectBlockStatus(self, handle, objtype, selections, action, query_object_registry):
        "Set objects block status."
        if not len(selections):
            self.logger.log(self.logger.DEBUG, "SetObjectBlockStatus without selection for handle '%s'." % handle)
            return

        if objtype not in OBJECT_REGISTRY_TYPES:
            raise Registry.DomainBrowser.INCORRECT_USAGE

        normalize = normalize_and_check_domain if objtype == "domain" else normalize_and_check_handle
        names = []
        for name in selections:
            names.append(normalize(self.logger, name))
        self.logger.log(self.logger.DEBUG, "Normalized names: %s" % names)

        contact_id = self._getContactHandleId(handle)
        self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, handle))
        # find all object belongs to contact
        result = self.source.fetchall(query_object_registry,
                        dict(objtype=OBJECT_REGISTRY_TYPES[objtype], contact_id=contact_id, names=names))

        object_dict = dict(result)
        object_ids = object_dict.values()
        missing = set(names) - set(object_dict.keys())
        if len(missing):
            self.logger.log(self.logger.INFO, "Contact ID %d of the handle '%s' missing objects: %s" % (contact_id, handle, missing))
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        with TransactionLevelRead(self.source, self.logger) as transaction:

            BLOCK, UNBLOCK = True, False
            if action._v in (self.BLOCK_TRANSFER, self.BLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.DEBUG, "BLOCK TRANSFER of %s" % names)
                self._blockUnblockObject(BLOCK, object_ids, "serverTransferProhibited")

            elif action._v in (self.UNBLOCK_TRANSFER, self.UNBLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.DEBUG, "UNBLOCK TRANSFER of %s" % names)
                self._blockUnblockObject(UNBLOCK, object_ids, "serverTransferProhibited")

            if action._v in (self.BLOCK_UPDATE, self.BLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.DEBUG, "BLOCK UPDATE of %s" % names)
                self._blockUnblockObject(BLOCK, object_ids, "serverUpdateProhibited")

            elif action._v in (self.UNBLOCK_UPDATE, self.UNBLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.DEBUG, "UNBLOCK UPDATE of %s" % names)
                self._blockUnblockObject(UNBLOCK, object_ids, "serverUpdateProhibited")


    def _blockUnblockObject(self, block, object_ids, state):
        """Set block transfer.
        state: "serverTransferProhibited", "serverUpdateProhibited"
        """
        state_id = ENUM_OBJECT_STATES[state]

        for object_id in object_ids:
            self.source.execute("""
                INSERT INTO object_state_request_lock
                (state_id, object_id)
                VALUES (%(state_id)d, %(object_id)d)""", dict(state_id=state_id, object_id=object_id))

        with_state = self.source.fetch_array("""
            SELECT
                object_id
            FROM object_state
            WHERE valid_to IS NULL
                AND state_id = %(state_id)d
                AND object_id IN %(objects)s
            """, dict(objects=object_ids, state_id=state_id))

        # remains to change:
        if block:
            # difference
            self._blockState(state_id, set(object_ids) - set(with_state))
        else:
            # intersection
            self._unblockState(state_id, set(object_ids) & set(with_state))


    def _blockState(self, state_id, remains_to_change):
        "Block state"
        for object_id in remains_to_change:
            params = dict(state_id=state_id, object_id=object_id)
            self.source.execute("""
                INSERT INTO object_state_request
                (object_id, state_id, valid_from) VALUES
                (%(object_id)d, %(state_id)d, NOW())""", params)
            self.source.execute("SELECT update_object_states(%(object_id)d)", params)

    def _unblockState(self, state_id, remains_to_change):
        "Block state"
        for object_id in remains_to_change:
            params = dict(state_id=state_id, object_id=object_id)
            self.source.execute("""
                UPDATE object_state_request
                SET valid_to = NOW() - INTERVAL '1 sec'
                WHERE valid_to IS NULL
                    AND object_id = %(object_id)d
                    AND state_id = %(state_id)d""", params)
            self.source.execute("SELECT update_object_states(%(object_id)d)", params)


    def _getHandleId(self, handle, query, exception_not_exists=None):
        "Returns ID of handle."
        if exception_not_exists is None:
            exception_not_exists = Registry.DomainBrowser.OBJECT_NOT_EXISTS

        response = self.source.fetchall(query, dict(handle=handle))
        if not len(response):
            raise exception_not_exists

        return response[0][0]


    def _getContactHandleId(self, handle):
        "Returns ID of contact handle."
        return self._getHandleId(handle, """
            SELECT
                object_registry.id, object_registry.name
            FROM object_registry
            LEFT JOIN contact ON object_registry.id = contact.id
            WHERE object_registry.name = %(handle)s""",
            Registry.DomainBrowser.USER_NOT_EXISTS)


    def _group_object_states(self):
        "Group objecst states into VIEW."
        self.source.execute("""
            CREATE OR REPLACE TEMPORARY VIEW object_states_view AS SELECT
                object_registry.id, array_accum(enum_object_states.name) AS states
            FROM object_registry
            LEFT JOIN object_state ON object_state.object_id = object_registry.id
                AND (object_state.valid_from < NOW()
                AND (object_state.valid_to IS NULL OR object_state.valid_to > NOW()))
            LEFT JOIN enum_object_states ON enum_object_states.id = object_state.state_id
            GROUP BY object_registry.id""")


    def _get_status_list(self, handle):
        "Returns the list of status."
        status_list = []
        for row_states in self.source.fetchall("""
                SELECT
                    enum_object_states.name
                FROM object_registry
                LEFT JOIN object_state ON object_state.object_id = object_registry.id
                    AND (object_state.valid_from < NOW()
                    AND (object_state.valid_to IS NULL OR object_state.valid_to > NOW()))
                LEFT JOIN enum_object_states ON enum_object_states.id = object_state.state_id
                WHERE object_registry.name = %(name)s""", dict(name=handle)):
            if row_states[0]:
                status_list.append(row_states[0])
        return status_list


    def _update_history(self, object_id, handle, table_name):
        "Update object history."
        params = dict(object_id=object_id)

        # remember timestamp of update
        self.source.execute("UPDATE object SET update = NOW() WHERE id = %(object_id)d", params)

        # create new "history" record
        params["history_id"] = history_id = self.source.getval("SELECT NEXTVAL('history_id_seq')")
        self.logger.log(self.logger.DEBUG, 'Next history ID %d for object ID %d with handle "%s".' % (history_id, object_id, handle))
        self.source.execute("INSERT INTO history (id, valid_from) VALUES (%(history_id)d, NOW())", params)

        # read previous history ID
        params["prev_history_id"] = prev_history_id = self.source.getval("SELECT historyid FROM object_registry WHERE id = %(object_id)d", params)
        self.logger.log(self.logger.DEBUG, 'Previous history ID %d for object ID %d with handle "%s".' % (prev_history_id, object_id, handle))

        # make backup of table "object"
        # make backup of "$OBJECT" (contact, domain, nsset, keyset)
        # refresh history pointer in "object_registry"
        self.source.execute("""
            INSERT INTO object_history SELECT %%(history_id)d, * FROM object WHERE id = %%(object_id)d;
            INSERT INTO %(name)s_history SELECT %%(history_id)d, * FROM %(name)s WHERE id = %%(object_id)d;
            UPDATE object_registry SET historyid = %%(history_id)d WHERE id = %%(object_id)d
            """ % dict(name=table_name), params)

        # refresh previous record of "history"
        self.source.execute("UPDATE history SET valid_to = NOW(), next = %(history_id)d WHERE id = %(prev_history_id)d", params)



class ListMetaInterface(BaseInterface):
    "Parent of interfaces with getDomainListMeta"

    def _getObjectListMeta(self, list_of_meta_names):
        """
        Returns the object (domain, nssest, keyset) list column names.

        enum RecordType {
            TEXT,
            DATE,
            BOOL,
            INT
        };
        struct RecordSetMeta
        {
            sequence<string> column_names;
            sequence<RecordType> data_types; // for sorting in frontend
        };
        """
        # prepare record types into dictionnary:
        rtp = dict([(inst._n, inst) for inst in Registry.DomainBrowser.RecordType._items])

        column_names, data_types = [], []
        for name, value in list_of_meta_names:
            column_names.append(name)
            data_types.append(rtp[value])

        return Registry.DomainBrowser.RecordSetMeta(column_names, data_types)
