#!/usr/bin/python
from pyfred.idlstubs import Registry
from pyfred.registry.utils.decorators import furnish_database_cursor_m
from pyfred.registry.utils.constants import ENUM_OBJECT_STATES, OBJECT_REGISTRY_TYPES, \
                                            AUTH_INFO_LENGTH, UPDATE_DISABLED_STATE_ID
from pyfred.registry.utils.cursors import TransactionLevelRead
from pyfred.registry.utils import none2str, StateItem



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
        self.enum_object_states = None # cache
        self.ignore_server_blocked = False
        self._cache = dict(states=dict(), minimal_importance=None)

    def setObjectBlockStatus(self, handle, objtype, selections, action):
        "Set object block status."
        raise Registry.DomainBrowser.INCORRECT_USAGE


    def owner_has_required_status(self, source, contact_id, names):
        "Check if contact has a required status."
        states = [ENUM_OBJECT_STATES[key] for key in names]
        results = source.fetchall("""
            SELECT COUNT(*)
            FROM object_state
            WHERE object_state.object_id = %(object_id)d
                AND state_id IN %(states)s
                AND valid_to IS NULL""",
            dict(object_id=contact_id, states=states))

        if results[0][0] == 0:
            self.logger.log(self.logger.INFO, "Contact ID %d has not required status %s." % (contact_id, names))
            raise Registry.DomainBrowser.ACCESS_DENIED


    def _object_belongs_to_contact(self, source, contact_id, contact_handle, object_id):
        "Check if object belongs to the contact."
        raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR


    @furnish_database_cursor_m
    def setAuthInfo(self, contact, objtype, objref, auth_info, request_id, source=None):
        "Set objects auth info."
        if len(auth_info) > AUTH_INFO_LENGTH:
            # authinfopw | character varying(300)
            raise Registry.DomainBrowser.INCORRECT_USAGE

        self._verify_user_contact(source, contact)
        self._verify(source, objref)
        self.owner_has_required_status(source, contact.id, ["validatedContact", "identifiedContact"])

        # ACCESS_DENIED:
        self._object_belongs_to_contact(source, contact.id, contact.handle, objref.id)
        # OBJECT_BLOCKED:
        self.check_if_object_is_blocked(source, objref.id)

        authinfopw = source.getval("""
            SELECT
                object.authinfopw
            FROM object_registry objreg
            JOIN object ON objreg.id = object.id
            WHERE objreg.id = %(object_id)d
            FOR UPDATE OF objreg, object
            """, dict(object_id=objref.id))

        if auth_info == authinfopw:
            self.logger.log(self.logger.INFO, 'No change of auth info at %s.' % objref)
            return False

        self.logger.log(self.logger.INFO, 'Change %s auth info.' % objref)
        with TransactionLevelRead(source, self.logger) as transaction:
            source.execute("""
                UPDATE object SET authinfopw = %(auth_info)s
                WHERE id = %(object_id)d""", dict(auth_info=auth_info, object_id=objref.id))
            self._update_history(source, contact.id, objref.handle, objtype, request_id)
        return True


    def _objects_with_state(self, source, object_ids, state_name):
        "Return objects only with given states."
        return source.fetch_array("""
            SELECT
                object_id
            FROM object_state
            WHERE state_id = %(state_id)s
                AND object_id IN %(objects)s
                AND valid_from <= CURRENT_TIMESTAMP AND (valid_to IS NULL OR valid_to > CURRENT_TIMESTAMP)
            """, dict(objects=object_ids, state_id=ENUM_OBJECT_STATES[state_name]))


    def check_if_object_is_blocked(self, source, object_id):
        "Raise OBJECT_BLOCKED is object is it."
        if len(self._objects_with_state(source, [object_id], "serverBlocked")):
            raise Registry.DomainBrowser.OBJECT_BLOCKED


    @furnish_database_cursor_m
    def _setObjectBlockStatus(self, contact, objtype, regrefseq, action_obj, query_object_registry, source=None):
        "Set objects block status."
        # regrefseq: (RegistryReference(id=123, handle="domain.cz"), ...)
        self._verify_user_contact(source, contact)
        if not len(regrefseq):
            self.logger.log(self.logger.INFO, "SetObjectBlockStatus without selection for handle %s." % contact)
            return False, ()

        if len(regrefseq) > self.SET_STATUS_MAX_ITEMS:
            raise Registry.DomainBrowser.INCORRECT_USAGE

        self.owner_has_required_status(source, contact.id, ["validatedContact"])

        selections = [] # object_ids: (11256, 4866, ...)
        object_dict = {} # object_dict: {11256: "domain.cz", 4566: "fred.cz", ...}
        for reg in regrefseq:
            selections.append(reg.id)
            object_dict[reg.id] = reg.handle

        # find all object belongs to contact
        object_ids = [] # object_ids: (11256, 4566, ...)
        for registry_id, handle in source.fetchall(query_object_registry,
                    dict(objtype=OBJECT_REGISTRY_TYPES[objtype], contact_id=contact.id, selections=selections)):
            # response: [[11256, "domain.cz"], [4566, "fred.cz"], ...]
            if object_dict.get(registry_id) != handle:
                self.logger.log(self.logger.INFO, "Object ID %s %s received by %s %s was not found." % (registry_id, handle, contact.id, contact.handle))
                raise Registry.DomainBrowser.OBJECT_NOT_EXISTS
            object_ids.append(registry_id)

        missing = set(selections) - set(object_ids)
        if len(missing):
            self.logger.log(self.logger.INFO, "Contact ID %d of the handle '%s' missing objects: %s" % (contact.id, contact.handle, list(missing)))
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        action = action_obj._v # action value
        block_transfer_ids, block_update_ids, unblock_transfer_ids, unblock_update_ids = [], [], [], []

        # Get a list of ID objects that have required status:
        object_with_transfer_prohibited = self._objects_with_state(source, object_ids, "serverTransferProhibited")
        object_with_update_prohibited = self._objects_with_state(source, object_ids, "serverUpdateProhibited")

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
            self.logger.log(self.logger.INFO, "None of the objects %s has required set/unset statuses "
                    "for the contact ID %d of the handle '%s'." % (object_ids, contact.id, contact.handle))
            return False, ()

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
        blocked = set()
        retval = False
        for state_id, object_id in update_status:
            if action in (self.BLOCK_TRANSFER, self.BLOCK_UPDATE, self.BLOCK_TRANSFER_AND_UPDATE):
                if self._set_status_to_object(source, state_id, object_id):
                    retval = True
                else:
                    blocked.add(object_dict[object_id])
            else:
                if self._remove_status_from_object(source, state_id, object_id):
                    retval = True
                else:
                    blocked.add(object_dict[object_id])

        return retval, tuple(blocked)


    def _apply_status_to_object(self, source, state_id, object_id, query):
        "Set status to object"
        params = dict(state_id=state_id, object_id=object_id)
        attrs = dict(state_id=ENUM_OBJECT_STATES["serverBlocked"], object_id=object_id)

        with TransactionLevelRead(source, self.logger) as transaction:
            source.execute("INSERT INTO object_state_request_lock (state_id, object_id) VALUES %s" %
                                ", ".join(("(%(state_id)d, %(object_id)d)" % attrs,
                                           "(%(state_id)d, %(object_id)d)" % params)))

        # run the change of object in the transaction
        with TransactionLevelRead(source, self.logger) as transaction:

            # lock add/remove state 'serverBlocked' for object state_id
            source.execute("SELECT lock_object_state_request_lock(%(state_id)d, %(object_id)d)", attrs)
            object_with_server_blocked = self._objects_with_state(source, [object_id], "serverBlocked")
            if len(object_with_server_blocked):
                self.logger.log(self.logger.INFO, "Change state ID %(state_id)d canceled. Object ID %(object_id)d has state 'serverBlocked'." % params)
                if not self.ignore_server_blocked:
                    return False # object is blocked

            # activate lock for the object and state
            source.execute("SELECT lock_object_state_request_lock(%(state_id)d, %(object_id)d)", params)
            # insert request for change object state
            source.execute(query, params)
            # execute the change
            source.execute("SELECT update_object_states(%(object_id)d)", params)

        return True # object is NOT blocked



    def _set_status_to_object(self, source, state_id, object_id):
        "Set status to object"
        return self._apply_status_to_object(source, state_id, object_id, """
                INSERT INTO object_state_request
                (object_id, state_id, valid_from) VALUES
                (%(object_id)d, %(state_id)d, CURRENT_TIMESTAMP)""")

    def _remove_status_from_object(self, source, state_id, object_id):
        "Remove status from object"
        return self._apply_status_to_object(source, state_id, object_id, """
                UPDATE object_state_request
                    SET canceled = CURRENT_TIMESTAMP
                WHERE object_id = %(object_id)d
                    AND state_id = %(state_id)d
                    AND  valid_from <= CURRENT_TIMESTAMP
                    AND (valid_to IS NULL OR valid_to > CURRENT_TIMESTAMP)
                """)


    def _get_handle_id(self, source, objtype, handle):
        "Returns ID of handle."
        return source.getval("""
            SELECT
                object_registry.id
            FROM object_registry
            WHERE
                type = %(type_id)d
                AND object_registry.name = %(handle)s
                AND object_registry.erdate IS NULL
            """, dict(handle=handle, type_id=OBJECT_REGISTRY_TYPES[objtype]))


    def _verify(self, source, regref, is_user_contact=False):
        """
        Verify if object ID and HANDLE are valid - object exists and is active.
        Raise OBJECT_NOT_EXISTS or USER_NOT_EXISTS if not.
        """
        response = source.fetchall("""
            SELECT oreg.id
            FROM object_registry oreg
            WHERE oreg.id = %(object_id)d
                  AND oreg.name = %(handle)s
                  AND type = %(type_id)d
                  AND oreg.erdate IS NULL""", regref.__dict__)
        if not len(response):
            if is_user_contact:
                raise Registry.DomainBrowser.USER_NOT_EXISTS
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS


    def _verify_user_contact(self, source, regref):
        """
        Verify if contact ID and HANDLE exists and is active.
        Raise USER_NOT_EXISTS if not.
        """
        return self._verify(source, regref, True) # True sets USER_NOT_EXISTS


    def _update_history(self, source, object_id, handle, objtype, request_id):
        "Update object history."
        params = dict(object_id=object_id, request_id=request_id)

        # remember timestamp of update
        source.execute("UPDATE object SET update = NOW() WHERE id = %(object_id)d", params)

        # create new "history" record
        params["history_id"] = history_id = source.getval("INSERT INTO history (request_id, valid_from) VALUES (%(request_id)d, NOW()) RETURNING id", params)
        self.logger.log(self.logger.INFO, 'Next history ID %d for object ID %d with handle "%s".' % (history_id, object_id, handle))

        # read previous history ID
        params["prev_history_id"] = prev_history_id = source.getval("SELECT historyid FROM object_registry WHERE id = %(object_id)d", params)
        self.logger.log(self.logger.INFO, 'Previous history ID %d for object ID %d with handle "%s".' % (prev_history_id, object_id, handle))

        # make backup of table 'object' (authinfopw)
        source.execute("INSERT INTO object_history SELECT %(history_id)d, id, clid, upid, trdate, update, authinfopw FROM object WHERE id = %(object_id)d", params)

        # make backup of table $OBJECT (contact, domain, nsset, keyset)
        # INSERT INTO object_history ...
        source.execute(self._get_history_query(), params)

        # refresh history pointer in "object_registry"
        source.execute("UPDATE object_registry SET historyid = %(history_id)d WHERE id = %(object_id)d", params)


    def _get_history_query(self):
        "Prepare SQL query for copy object into history. The query must prepare every object type separately."
        raise NotImplementedError("Function %s._get_history_query() is not implemented." % self.__class__.__name__)

    def parse_states(self, source, states):
        "Parse states struct into the lists."
        # example: states = 't\t20\toutzone\tDomain is not generated into zone\n...'
        state_codes, state_descriptions, state_importance = [], [], 0

        for row in states.split("&"):
            if row == "":
                continue
            #data = [external, importance, name, description]
            data = row.split("#")
            state_codes.append(data[2])
            if data[0] == 't':
                if data[1]:
                    state_importance |= int(data[1])
                state_descriptions.append(data[3])

        if state_importance == 0:
            state_importance = self.get_status_minimal_importance(source)

        return ",".join(state_codes), str(state_importance), "|".join(state_descriptions)


    def get_status_minimal_importance(self, source):
        "Get minimal status importance."
        if self._cache["minimal_importance"] is None:
            self._cache["minimal_importance"] = source.getval("SELECT MAX(importance) * 2 FROM enum_object_states")
        return self._cache["minimal_importance"]


    def get_enum_external_states_desc(self, source, lang):
        """Get states of selected lang code.
        self._cache["states"][lang] = {
            status_id: (importance, description),
        }
        """
        if lang not in self._cache["states"]:
            # load states for language
            self._cache["states"][lang] = dict()
            minimal_importance = self.get_status_minimal_importance(source)
            for row in source.fetchall("""
                SELECT
                    stat.id,
                    stat.importance,
                    des.description
                FROM enum_object_states stat
                JOIN enum_object_states_desc des
                    ON stat.id = des.state_id
                    AND des.lang = %(lang)s
                WHERE stat.external = 't'
                """, dict(lang=lang)):
                staste_id, importace, description = row
                if importace is None:
                    importace = minimal_importance
                self._cache["states"][lang][staste_id] = (importace, description)

        return self._cache["states"][lang]


    def appendStatus(self, source, result, found, lang, importance_column_pos,
                     description_column_pos, update_disabled_pos):
        "Append status into result."
        if not found:
            return # no domains

        def convert():
            prev_rec = result[prev_pos]
            state = prev_rec[importance_column_pos]
            prev_rec[importance_column_pos] = state.strImportance()
            prev_rec[description_column_pos] = state.strDescription()

        minimal_status_importance = self.get_status_minimal_importance(source)
        states = self.get_enum_external_states_desc(source, lang)

        previous_id, prev_pos = None, None
        for row in source.fetchall("""
            SELECT
                os.object_id,
                os.state_id
            FROM object_state os
            WHERE os.object_id IN %(keys)s
                AND os.valid_from <= CURRENT_TIMESTAMP
                AND (os.valid_to IS NULL OR os.valid_to > CURRENT_TIMESTAMP)
            ORDER BY os.object_id
            """, dict(keys=found.keys())):

            object_id, state_id = row
            if state_id not in states:
                continue # state ID is not external status

            state_item = states[state_id]
            pos = found[object_id]
            rec = result[pos]

            if state_id == UPDATE_DISABLED_STATE_ID:
                rec[update_disabled_pos] = 't'

            if object_id != previous_id:
                # convert instace StateItem to strings
                if previous_id is not None:
                    convert()
                # create instace StateItem
                rec[importance_column_pos] = StateItem(state_item)
                previous_id = object_id
                prev_pos = pos
            else:
                rec[importance_column_pos].add(state_item)

        if previous_id is not None:
            convert()


    def _pop_registrars_from_detail(self, detail):
        "Pop registrars from sql result and create registrars."
        registrars = []
        for pos in range(3): # current, creator, updator
            name = none2str(detail.pop())
            handle = none2str(detail.pop())
            object_id = detail.pop()
            registrars.append(Registry.DomainBrowser.RegistryReference(0 if object_id is None else object_id, handle, name))
        return registrars
