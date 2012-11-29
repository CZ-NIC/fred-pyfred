#!/usr/bin/python
from pyfred.idlstubs import Registry
from pyfred.registry.utils import normalize_and_check_handle
from pyfred.registry.utils.decorators import furnish_database_cursor_m, \
            normalize_object_handle_m



class BaseInterface(object):
    "Base interface object."

    PUBLIC_DATA, PRIVATE_DATA = range(2)
    PASSWORD_SUBSTITUTION = "********"

    INTERNAL_SERVER_ERROR = Registry.DomainBrowser.INTERNAL_SERVER_ERROR


    def __init__(self, database, logger, list_limit=None):
        self.database = database
        self.logger = logger
        self.list_limit = list_limit
        self.source = None

    @normalize_object_handle_m
    @furnish_database_cursor_m
    def setObjectBlockStatus(self, handle, selections, action):
        "Dummy setObjectBlockStatus"
        # TODO: ...

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
                object_registry.id, array_agg(enum_object_states.name) AS states
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
