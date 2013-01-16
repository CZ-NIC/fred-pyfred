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
            raise Registry.DomainBrowser.OBJECT_BLOCKED


    def owner_has_required_status(self, contact_id):
        "Check if contact has a required status."
        results = self.source.fetchall("""
            SELECT COUNT(*)
            FROM object_state
            WHERE object_state.object_id = %(object_id)d
                AND state_id IN %(states)s
                AND valid_to IS NULL""",
            dict(object_id=contact_id, states=(ENUM_OBJECT_STATES["validatedContact"],
                                               ENUM_OBJECT_STATES["identifiedContact"])))

        if results[0][0] == 0:
            self.logger.log(self.logger.INFO, "Contact ID %d has not a required status (validatedContact, identifiedContact)." % contact_id)
            raise Registry.DomainBrowser.ACCESS_DENIED


    def _copy_into_history_query(self, objtype):
        "Prepare query for copy object into history."
        # This function is here for case when columns in tables ${object} and ${object}_history do not have the same order.
        # List column names is required in this case. (e.g. \d domain and \d domain_history)
        return "INSERT INTO %(name)s_history SELECT %%(history_id)d, * FROM %(name)s WHERE id = %%(object_id)d" % dict(name=objtype)

    def _object_belongs_to_contact(self, contact_id, contact_handle, object_id):
        "Check if object belongs to the contact."
        raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR


    @furnish_database_cursor_m
    def setAuthInfo(self, contact_handle, object_handle, objtype, auth_info):
        "Set objects auth info."
        if len(auth_info) > AUTH_INFO_LENGTH:
            # authinfopw | character varying(300)
            raise Registry.DomainBrowser.INCORRECT_USAGE

        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.INFO, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))

        object_id = self._get_handle_id(object_handle, objtype)
        self.logger.log(self.logger.INFO, "Found object ID %d of the handle '%s'." % (object_id, object_handle))

        # ACCESS_DENIED:
        self._object_is_editable(object_id, object_handle)
        self._object_belongs_to_contact(contact_id, contact_handle, object_id)
        self.owner_has_required_status(contact_id)

        authinfopw = self.source.getval("""
            SELECT
                object.authinfopw
            FROM object_registry objreg
            LEFT JOIN object ON objreg.id = object.id
            WHERE objreg.id = %(object_id)d
            """, dict(object_id=object_id))

        if auth_info == authinfopw:
            self.logger.log(self.logger.INFO, 'No change of auth info at object[%d] "%s".' % (object_id, object_handle))
            return False

        self.logger.log(self.logger.INFO, 'Change object[%d] "%s" auth info.' % (object_id, object_handle))
        with TransactionLevelRead(self.source, self.logger) as transaction:
            self.source.execute("""
                UPDATE object SET authinfopw = %(auth_info)s
                WHERE id = %(object_id)d""", dict(auth_info=auth_info, object_id=object_id))
            self._update_history(contact_id, object_handle, objtype)
        return True


    def _objects_with_state(self, object_ids, state_name):
        "Return objects only with given statuses."
        return self.source.fetch_array("""
            SELECT
                object_id
            FROM object_state
            WHERE valid_to IS NULL
                AND state_id = %(state_id)s
                AND object_id IN %(objects)s
            """, dict(objects=object_ids, state_id=ENUM_OBJECT_STATES[state_name]))


    @furnish_database_cursor_m
    def _setObjectBlockStatus(self, contact_handle, objtype, selections, action_obj, query_object_registry):
        "Set objects block status."
        if not len(selections):
            self.logger.log(self.logger.INFO, "SetObjectBlockStatus without selection for handle '%s'." % contact_handle)
            return False

        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.INFO, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))
        self.owner_has_required_status(contact_id)

        # find all object belongs to contact
        result = self.source.fetchall(query_object_registry,
                        dict(objtype=OBJECT_REGISTRY_TYPES[objtype], contact_id=contact_id, names=selections))

        object_dict = dict(result)
        object_ids = object_dict.values()
        missing = set(selections) - set(object_dict.keys())
        if len(missing):
            self.logger.log(self.logger.INFO, "Contact ID %d of the handle '%s' missing objects: %s" % (contact_id, contact_handle, missing))
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        action = action_obj._v # action value
        block_transfer_ids, block_update_ids, unblock_transfer_ids, unblock_update_ids = [], [], [], []

        # Get a list of ID objects that have required status:
        object_with_transfer_prohibited = self._objects_with_state(object_ids, "serverTransferProhibited")
        object_with_update_prohibited = self._objects_with_state(object_ids, "serverUpdateProhibited")

        if action in (self.BLOCK_TRANSFER, self.BLOCK_TRANSFER_AND_UPDATE):
            # filter only objects with no status
            block_transfer_ids = [oid for oid in set(object_ids) - set(object_with_transfer_prohibited)]
            self.logger.log(self.logger.INFO, "Required IDs to set Transfer prohibited %s." % block_transfer_ids)

        if action in (self.BLOCK_UPDATE, self.BLOCK_TRANSFER_AND_UPDATE):
            # filter only objects with no status
            block_update_ids = [oid for oid in set(object_ids) - set(object_with_update_prohibited)]
            self.logger.log(self.logger.INFO, "Required IDs to set Update prohibited %s." % block_update_ids)

        if action in (self.UNBLOCK_TRANSFER, self.UNBLOCK_TRANSFER_AND_UPDATE):
            # use only objects with status
            unblock_transfer_ids = object_with_transfer_prohibited
            self.logger.log(self.logger.INFO, "Required IDs to remove Transfer prohibited %s." % unblock_transfer_ids)

        if action in (self.UNBLOCK_UPDATE, self.UNBLOCK_TRANSFER_AND_UPDATE):
            # use only objects with status
            unblock_update_ids = object_with_update_prohibited
            self.logger.log(self.logger.INFO, "Required IDs to remove Update prohibited %s." % unblock_update_ids)

        if not (block_transfer_ids or block_update_ids or unblock_transfer_ids or unblock_update_ids):
            self.logger.log(self.logger.INFO, "None of the objects %s %s has required set/unset statuses "
                    "for the contact ID %d of the handle '%s'." % (object_ids, selections, contact_id, contact_handle))
            return False

        # Create request lock in the separate transaction
        with TransactionLevelRead(self.source, self.logger) as transaction:

            if (block_transfer_ids or unblock_transfer_ids) and action in (
                    self.BLOCK_TRANSFER, self.BLOCK_TRANSFER_AND_UPDATE,
                    self.UNBLOCK_TRANSFER, self.UNBLOCK_TRANSFER_AND_UPDATE):
                self._create_request_lock(block_transfer_ids + unblock_transfer_ids, "serverTransferProhibited")

            if (block_update_ids or unblock_update_ids) and action in (
                    self.BLOCK_UPDATE, self.BLOCK_TRANSFER_AND_UPDATE,
                    self.UNBLOCK_UPDATE, self.UNBLOCK_TRANSFER_AND_UPDATE):
                self._create_request_lock(block_update_ids + unblock_update_ids, "serverUpdateProhibited")

        if not transaction.success:
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        # Update object history in next transaction
        with TransactionLevelRead(self.source, self.logger) as transaction:

            if block_transfer_ids and action in (self.BLOCK_TRANSFER, self.BLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.INFO, "Block Transfer of %s" % block_transfer_ids)
                self._blockState(block_transfer_ids, "serverTransferProhibited")

            if unblock_transfer_ids and action in (self.UNBLOCK_TRANSFER, self.UNBLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.INFO, "Unblock Transfer of %s" % unblock_transfer_ids)
                self._unBlockState(unblock_transfer_ids, "serverTransferProhibited")

            if block_update_ids and action in (self.BLOCK_UPDATE, self.BLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.INFO, "Block Update of %s" % block_update_ids)
                self._blockState(block_update_ids, "serverUpdateProhibited")

            if unblock_update_ids and action in (self.UNBLOCK_UPDATE, self.UNBLOCK_TRANSFER_AND_UPDATE):
                self.logger.log(self.logger.INFO, "Unblock Update of %s" % unblock_update_ids)
                self._unBlockState(unblock_update_ids, "serverUpdateProhibited")

        return True


    def _create_request_lock(self, object_ids, state_name):
        "Create request lock for state and objects."
        for object_id in object_ids:
            self.source.execute("""
                INSERT INTO object_state_request_lock
                (state_id, object_id)
                VALUES (%(state_id)d, %(object_id)d);
                SELECT lock_object_state_request_lock(%(state_id)d, %(object_id)d)
                """, dict(state_id=ENUM_OBJECT_STATES[state_name], object_id=object_id))


    def _blockState(self, remains_to_change, state_name):
        "Block state"
        params = dict(state_id=ENUM_OBJECT_STATES[state_name])
        for object_id in remains_to_change:
            params["object_id"] = object_id
            self.source.execute("""
                INSERT INTO object_state_request
                (object_id, state_id, valid_from) VALUES
                (%(object_id)d, %(state_id)d, NOW())""", params)
            self.source.execute("SELECT update_object_states(%(object_id)d)", params)

    def _unBlockState(self, remains_to_change, state_name):
        "Block state"
        params = dict(state_id=ENUM_OBJECT_STATES[state_name])
        for object_id in remains_to_change:
            params["object_id"] = object_id
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
                    AND (object_state.valid_from <= NOW()
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
        self.logger.log(self.logger.INFO, 'Next history ID %d for object ID %d with handle "%s".' % (history_id, object_id, handle))

        # read previous history ID
        params["prev_history_id"] = prev_history_id = self.source.getval("SELECT historyid FROM object_registry WHERE id = %(object_id)d", params)
        self.logger.log(self.logger.INFO, 'Previous history ID %d for object ID %d with handle "%s".' % (prev_history_id, object_id, handle))

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
