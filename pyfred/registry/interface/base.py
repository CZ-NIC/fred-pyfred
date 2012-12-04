#!/usr/bin/python
from pyfred.idlstubs import Registry
from pyfred.registry.utils import normalize_and_check_handle, normalize_and_check_domain
from pyfred.registry.utils.decorators import furnish_database_cursor_m
from pyfred.registry.utils.constants import ENUM_OBJECT_STATES, OBJECT_REGISTRY_TYPES, AUTH_INFO_LENGTH
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


    def _object_is_editable(self, object_id, handle):
        "Check if is possible to update object."
        results = self.source.fetchall("""
            SELECT COUNT(*)
            FROM object_state
            WHERE object_state.object_id = %(object_id)d
                AND state_id IN %(states)s
                AND valid_to IS NULL""",
            dict(object_id=object_id, states=(ENUM_OBJECT_STATES["serverUpdateProhibited"],
                                              ENUM_OBJECT_STATES["deleteCandidate"])))

        if results[0][0] != 0:
            self.logger.log(self.logger.INFO, 'Can not update object "%s" due to state restriction.' % handle)
            raise Registry.DomainBrowser.ACCESS_DENIED


    def _copy_into_history_query(self, objtype):
        "Prepare query for copy object into history."
        # This function is here for case when columns in tables ${object} and ${object}_history do not have the same order.
        # List column names is required in this case. (e.g. \d domain and \d domain_history)
        return "INSERT INTO %(name)s_history SELECT %%(history_id)d, * FROM %(name)s WHERE id = %%(object_id)d" % dict(name=objtype)

    @furnish_database_cursor_m
    def setAuthInfo(self, contact_handle, object_handle, objtype, auth_info):
        "Set objects auth info."
        if len(auth_info) > AUTH_INFO_LENGTH:
            # authinfopw | character varying(300)
            raise Registry.DomainBrowser.INCORRECT_USAGE

        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))

        object_id = self._get_handle_id(object_handle, objtype)
        self.logger.log(self.logger.DEBUG, "Found object ID %d of the handle '%s'." % (object_id, object_handle))

        # ACCESS_DENIED:
        self._object_is_editable(object_id, object_handle)
        self._object_belongs_to_contact(contact_id, contact_handle, object_id)

        authinfopw = self.source.getval("""
            SELECT
                object.authinfopw
            FROM object_registry objreg
            LEFT JOIN object ON objreg.id = object.id
            WHERE objreg.id = %(object_id)d
            """, dict(object_id=object_id))

        if auth_info == authinfopw:
            self.logger.log(self.logger.DEBUG, 'No change of auth info at object[%d] "%s".' % (object_id, object_handle))
            return

        self.logger.log(self.logger.INFO, 'Change object[%d] "%s" auth info.' % (object_id, object_handle))
        with TransactionLevelRead(self.source, self.logger) as transaction:
            self.source.execute("""
                UPDATE object SET authinfopw = %(auth_info)s
                WHERE id = %(object_id)d""", dict(auth_info=auth_info, object_id=object_id))
            self._update_history(contact_id, object_handle, objtype)


    @furnish_database_cursor_m
    def _setObjectBlockStatus(self, contact_handle, objtype, selections, action, query_object_registry):
        "Set objects block status."
        if not len(selections):
            self.logger.log(self.logger.DEBUG, "SetObjectBlockStatus without selection for handle '%s'." % contact_handle)
            return

        if objtype not in OBJECT_REGISTRY_TYPES:
            raise Registry.DomainBrowser.INCORRECT_USAGE

        ##normalize = normalize_and_check_domain if objtype == "domain" else normalize_and_check_handle
        ##names = []
        ##for name in selections:
        ##    names.append(normalize(self.logger, name))
        ##self.logger.log(self.logger.DEBUG, "Normalized names: %s" % names)

        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))

        # find all object belongs to contact
        result = self.source.fetchall(query_object_registry,
                        dict(objtype=OBJECT_REGISTRY_TYPES[objtype], contact_id=contact_id, names=selections))

        object_dict = dict(result)
        object_ids = object_dict.values()
        missing = set(selections) - set(object_dict.keys())
        if len(missing):
            self.logger.log(self.logger.INFO, "Contact ID %d of the handle '%s' missing objects: %s" % (contact_id, contact_handle, missing))
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        # Create request lock in the separate transaction
        with TransactionLevelRead(self.source, self.logger) as transaction:

            if action._v in (self.BLOCK_TRANSFER, self.BLOCK_TRANSFER_AND_UPDATE,
                             self.UNBLOCK_TRANSFER, self.UNBLOCK_TRANSFER_AND_UPDATE):
                self._create_request_lock(object_ids, "serverTransferProhibited")

            if action._v in (self.BLOCK_UPDATE, self.BLOCK_TRANSFER_AND_UPDATE,
                             self.UNBLOCK_UPDATE, self.UNBLOCK_TRANSFER_AND_UPDATE):
                self._create_request_lock(object_ids, "serverUpdateProhibited")

        if not transaction.success:
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        # Update objcet history in next transaction
        with TransactionLevelRead(self.source, self.logger) as transaction:

            BLOCK, UNBLOCK = True, False
            if action._v in (self.BLOCK_TRANSFER, self.BLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.DEBUG, "BLOCK TRANSFER of %s" % selections)
                self._blockUnblockObject(BLOCK, object_ids, "serverTransferProhibited")

            elif action._v in (self.UNBLOCK_TRANSFER, self.UNBLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.DEBUG, "UNBLOCK TRANSFER of %s" % selections)
                self._blockUnblockObject(UNBLOCK, object_ids, "serverTransferProhibited")

            if action._v in (self.BLOCK_UPDATE, self.BLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.DEBUG, "BLOCK UPDATE of %s" % selections)
                self._blockUnblockObject(BLOCK, object_ids, "serverUpdateProhibited")

            elif action._v in (self.UNBLOCK_UPDATE, self.UNBLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.DEBUG, "UNBLOCK UPDATE of %s" % selections)
                self._blockUnblockObject(UNBLOCK, object_ids, "serverUpdateProhibited")


    def _create_request_lock(self, object_ids, state):
        "Create request lock for state and objects."
        state_id = ENUM_OBJECT_STATES[state]
        for object_id in object_ids:
            self.source.execute("""
                INSERT INTO object_state_request_lock
                (state_id, object_id)
                VALUES (%(state_id)d, %(object_id)d);
                SELECT lock_object_state_request_lock(%(state_id)d, %(object_id)d)
                """, dict(state_id=state_id, object_id=object_id))


    def _blockUnblockObject(self, block, object_ids, state):
        """Set block transfer.
        state: "serverTransferProhibited", "serverUpdateProhibited"
        """
        state_id = ENUM_OBJECT_STATES[state]
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


    def _get_handle_id(self, object_handle, type_name):
        "Returns ID of handle."
        response = self.source.fetchall("""
            SELECT object_registry.id
            FROM object_registry
            WHERE type = %(type_id)d AND object_registry.name = %(handle)s""",
            dict(handle=object_handle, type_id=OBJECT_REGISTRY_TYPES[type_name]))
        if not len(response):
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS
        return response[0][0]

    def _get_user_handle_id(self, contact_handle):
        "Returns ID of handle."
        response = self.source.fetchall("""
            SELECT object_registry.id
            FROM object_registry
            WHERE type = %(type_id)d AND object_registry.name = %(handle)s""",
            dict(handle=contact_handle, type_id=OBJECT_REGISTRY_TYPES["contact"]))
        if not len(response):
            raise Registry.DomainBrowser.USER_NOT_EXISTS
        return response[0][0]


    def _dict_of_object_states(self):
        "Group objecst states into VIEW."
        return dict(self.source.fetchall("SELECT id, name FROM enum_object_states"))

    def _map_object_states(self, states, dictkeys=None):
        "Map object states ID with theirs keys."
        result = []
        if dictkeys is None:
            dictkeys = self._dict_of_object_states()
        for state_id in states:
            result.append(dictkeys[state_id])
        return result


    def _get_status_list(self, object_handle, objtype):
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
                WHERE object_registry.type = %(type_id)d AND object_registry.name = %(name)s""",
                dict(name=object_handle, type_id=OBJECT_REGISTRY_TYPES[objtype])):
            if row_states[0]:
                status_list.append(row_states[0])
        return status_list


    def _update_history(self, object_id, handle, objtype):
        "Update object history."
        params = dict(object_id=object_id)

        # remember timestamp of update
        self.source.execute("UPDATE object SET update = NOW() WHERE id = %(object_id)d", params)

        # create new "history" record
        params["history_id"] = history_id = self.source.getval("INSERT INTO history (valid_from) VALUES (NOW()) RETURNING id")
        self.logger.log(self.logger.DEBUG, 'Next history ID %d for object ID %d with handle "%s".' % (history_id, object_id, handle))

        # read previous history ID
        params["prev_history_id"] = prev_history_id = self.source.getval("SELECT historyid FROM object_registry WHERE id = %(object_id)d", params)
        self.logger.log(self.logger.DEBUG, 'Previous history ID %d for object ID %d with handle "%s".' % (prev_history_id, object_id, handle))

        # make backup of talbe $OBJECT (contact, domain, nsset, keyset)
        # INSERT INTO object_history ...
        self.source.execute(self._copy_into_history_query(objtype), params)

        # refresh history pointer in "object_registry"
        self.source.execute("UPDATE object_registry SET historyid = %(history_id)d WHERE id = %(object_id)d", params)

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
