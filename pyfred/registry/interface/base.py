#!/usr/bin/python
from pyfred.idlstubs import Registry
from pyfred.registry.utils.decorators import furnish_database_cursor_m
from pyfred.registry.utils.constants import ENUM_OBJECT_STATES, OBJECT_REGISTRY_TYPES, AUTH_INFO_LENGTH
from pyfred.registry.utils.cursors import TransactionLevelRead



class BaseInterface(object):
    "Base interface object."

    PUBLIC_DATA, PRIVATE_DATA = range(2)
    BLOCK_TRANSFER, UNBLOCK_TRANSFER, \
    BLOCK_UPDATE, UNBLOCK_UPDATE, \
    BLOCK_TRANSFER_AND_UPDATE, UNBLOCK_TRANSFER_AND_UPDATE = range(6)
    SET_STATUS_MAX_ITEMS = 500

    PASSWORD_SUBSTITUTION = "********"

    INTERNAL_SERVER_ERROR = Registry.DomainBrowser.INTERNAL_SERVER_ERROR


    def __init__(self, browser, database, logger, list_limit=None):
        self.browser = browser
        self.database = database
        self.logger = logger
        self.list_limit = list_limit
        self.source = None
        self.enum_object_states = None # cache
        self.ignore_server_blocked = False

    def setObjectBlockStatus(self, handle, objtype, selections, action):
        "Set object block status."
        raise Registry.DomainBrowser.INCORRECT_USAGE


    def owner_has_required_status(self, contact_id, names):
        "Check if contact has a required status."
        states = [ENUM_OBJECT_STATES[key] for key in names]
        results = self.source.fetchall("""
            SELECT COUNT(*)
            FROM object_state
            WHERE object_state.object_id = %(object_id)d
                AND state_id IN %(states)s
                AND valid_to IS NULL""",
            dict(object_id=contact_id, states=states))

        if results[0][0] == 0:
            self.logger.log(self.logger.INFO, "Contact ID %d has not required status %s." % (contact_id, names))
            raise Registry.DomainBrowser.ACCESS_DENIED


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
        self.owner_has_required_status(contact_id, ["validatedContact", "identifiedContact"])

        if contact_handle == object_handle:
            object_id = contact_id
        else:
            object_id = self._get_handle_id(object_handle, objtype)
            self.logger.log(self.logger.INFO, "Found object ID %d of the handle '%s'." % (object_id, object_handle))

        # ACCESS_DENIED:
        self._object_belongs_to_contact(contact_id, contact_handle, object_id)
        # OBJECT_BLOCKED:
        self.check_if_object_is_blocked(object_id)

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
        "Return objects only with given states."
        return self.source.fetch_array("""
            SELECT
                object_id
            FROM object_state
            WHERE state_id = %(state_id)s
                AND object_id IN %(objects)s
                AND valid_from <= CURRENT_TIMESTAMP AND (valid_to IS NULL OR valid_to > CURRENT_TIMESTAMP)
            """, dict(objects=object_ids, state_id=ENUM_OBJECT_STATES[state_name]))


    def check_if_object_is_blocked(self, object_id):
        "Raise OBJECT_BLOCKED is object is it."
        if len(self._objects_with_state([object_id], "serverBlocked")):
            raise Registry.DomainBrowser.OBJECT_BLOCKED


    @furnish_database_cursor_m
    def _setObjectBlockStatus(self, contact_handle, objtype, selections, action_obj, query_object_registry):
        "Set objects block status."
        # selections: ("domain.cz", "fred.cz", ...)
        if not len(selections):
            self.logger.log(self.logger.INFO, "SetObjectBlockStatus without selection for handle '%s'." % contact_handle)
            return False, []

        if len(selections) > self.SET_STATUS_MAX_ITEMS:
            raise Registry.DomainBrowser.INCORRECT_USAGE

        contact_id = self._get_user_handle_id(contact_handle)
        self.logger.log(self.logger.INFO, "Found contact ID %d of the handle '%s'." % (contact_id, contact_handle))
        self.owner_has_required_status(contact_id, ["validatedContact"])

        # find all object belongs to contact
        result = self.source.fetchall(query_object_registry,
                        dict(objtype=OBJECT_REGISTRY_TYPES[objtype], contact_id=contact_id, names=selections))
        # result: (("domain.cz", 11256), ("fred.cz", 4566), ...), ..)

        object_dict = dict(result)
        # object_dict: {"domain.cz": 11256, "fred.cz": 4566, ...}
        object_ids = object_dict.values()
        # object_ids: (11256, 4866, ...)
        missing = set(selections) - set(object_dict.keys())
        if len(missing):
            self.logger.log(self.logger.INFO, "Contact ID %d of the handle '%s' missing objects: %s" % (contact_id, contact_handle, list(missing)))
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
            return False, []

        # prepare updates: ((state_id, object_id), ...)
        update_status = []

        if (block_transfer_ids or unblock_transfer_ids) and action in (
                self.BLOCK_TRANSFER, self.BLOCK_TRANSFER_AND_UPDATE,
                self.UNBLOCK_TRANSFER, self.UNBLOCK_TRANSFER_AND_UPDATE):
            state_id = ENUM_OBJECT_STATES["serverTransferProhibited"]
            update_status.extend([(state_id, object_id) for object_id in block_transfer_ids + unblock_transfer_ids])

        if (block_update_ids or unblock_update_ids) and action in (
                self.BLOCK_UPDATE, self.BLOCK_TRANSFER_AND_UPDATE,
                self.UNBLOCK_UPDATE, self.UNBLOCK_TRANSFER_AND_UPDATE):
            state_id = ENUM_OBJECT_STATES["serverUpdateProhibited"]
            update_status.extend([(state_id, object_id) for object_id in block_update_ids + unblock_update_ids])

        # run updates from here:
        blocked = []
        retval = False
        for state_id, object_id in update_status:
            if action in (self.BLOCK_TRANSFER, self.BLOCK_UPDATE, self.BLOCK_TRANSFER_AND_UPDATE):
                if self._set_status_to_object(state_id, object_id):
                    retval = True
                else:
                    blocked.append(object_id)
            else:
                if self._remove_status_from_object(state_id, object_id):
                    retval = True
                else:
                    blocked.append(object_id)

        blocked_names = set()
        if len(blocked):
            for name, obect_id in result:
                if obect_id in blocked:
                    blocked_names.add(name)

        return retval, tuple(blocked_names)


    def _apply_status_to_object(self, state_id, object_id, query):
        "Set status to object"
        params = dict(state_id=state_id, object_id=object_id)
        attrs = dict(state_id=ENUM_OBJECT_STATES["serverBlocked"], object_id=object_id)

        with TransactionLevelRead(self.source, self.logger) as transaction:
            self.source.execute("INSERT INTO object_state_request_lock (state_id, object_id) VALUES %s" %
                                ", ".join(("(%(state_id)d, %(object_id)d)" % attrs,
                                           "(%(state_id)d, %(object_id)d)" % params)))

        # run the change of object in the transaction
        with TransactionLevelRead(self.source, self.logger) as transaction:

            # lock add/remove state 'serverBlocked' for object state_id
            self.source.execute("SELECT lock_object_state_request_lock(%(state_id)d, %(object_id)d)", attrs)
            object_with_server_blocked = self._objects_with_state([object_id], "serverBlocked")
            if len(object_with_server_blocked):
                self.logger.log(self.logger.INFO, "Change state ID %(state_id)d canceled. Object ID %(object_id)d has state 'serverBlocked'." % params)
                if not self.ignore_server_blocked:
                    return False # object is blocked

            # activate lock for the object and state
            self.source.execute("SELECT lock_object_state_request_lock(%(state_id)d, %(object_id)d)", params)
            # insert request for change object state
            self.source.execute(query, params)
            # execute the change
            self.source.execute("SELECT update_object_states(%(object_id)d)", params)

        return True # object is NOT blocked



    def _set_status_to_object(self, state_id, object_id):
        "Set status to object"
        return self._apply_status_to_object(state_id, object_id, """
                INSERT INTO object_state_request
                (object_id, state_id, valid_from) VALUES
                (%(object_id)d, %(state_id)d, CURRENT_TIMESTAMP)""")

    def _remove_status_from_object(self, state_id, object_id):
        "Remove status from object"
        return self._apply_status_to_object(state_id, object_id, """
                UPDATE object_state_request
                    SET canceled = CURRENT_TIMESTAMP
                WHERE object_id = %(object_id)d
                    AND state_id = %(state_id)d
                    AND  valid_from <= CURRENT_TIMESTAMP
                    AND (valid_to IS NULL OR valid_to > CURRENT_TIMESTAMP)
                """)


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
        if self.enum_object_states is None:
            self.enum_object_states = dict(self.source.fetchall("SELECT id, name FROM enum_object_states"))
        return self.enum_object_states

    def _map_object_states(self, states, dictkeys=None):
        "Map object states ID with theirs keys."
        result = []
        if dictkeys is None:
            dictkeys = self._dict_of_object_states()
        for state_id in states:
            result.append(dictkeys[state_id])
        return result


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

        # make backup of table 'object' (authinfopw)
        self.source.execute("INSERT INTO object_history SELECT %(history_id)d, * FROM object WHERE id = %(object_id)d", params)

        # make backup of table $OBJECT (contact, domain, nsset, keyset)
        # INSERT INTO object_history ...
        self.source.execute(self._copy_into_history_query(objtype), params)

        # refresh history pointer in "object_registry"
        self.source.execute("UPDATE object_registry SET historyid = %(history_id)d WHERE id = %(object_id)d", params)

        # refresh previous record of "history"
        ##self.source.execute("UPDATE history SET valid_to = NOW(), next = %(history_id)d WHERE id = %(prev_history_id)d", params)
        # db/sql/ccreg.sql:
        # FUNCTION object_registry_update_history_rec TRIGGER object_registry AFTER UPDATE:
        #   -- when updation object, set valid_to and next of previous history record
        #       IF OLD.historyid != NEW.historyid THEN
        #       UPDATE history SET valid_to = NOW(), next = NEW.historyid WHERE id = OLD.historyid;
        #   -- when deleting object (setting object_registry.erdate), set valid_to of current history record
        #       IF OLD.erdate IS NULL and NEW.erdate IS NOT NULL THEN
        #       UPDATE history SET valid_to = NEW.erdate WHERE id = OLD.historyid;

    def _copy_into_history_query(self, objtype):
        "Prepare query for copy object into history."
        # This function is here for case when columns in tables ${object} and ${object}_history do not have the same order.
        # List column names is required in this case. (e.g. \d domain and \d domain_history)
        return "INSERT INTO %(name)s_history SELECT %%(history_id)d, * FROM %(name)s WHERE id = %%(object_id)d" % dict(name=objtype)
