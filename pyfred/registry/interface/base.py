#!/usr/bin/python
from pyfred.idlstubs import Registry
from pyfred.registry.utils import normalize_and_check_handle


class BaseInterface(object):
    "Base interface object."
    logger = None
    source = None
    limits = None

    def setObjectBlockStatus(self, handle, selections, action):
        "Dummy setObjectBlockStatus"
        self.logger.log(self.logger.DEBUG, 'Call BaseInterface.setObjectBlockStatus'
                        '(handle="%s", selections="%s", action="%s", )' % (handle, selections, action))
        handle = normalize_and_check_handle(self.logger, handle) # Registry.DomainBrowser.INCORRECT_USAGE
        # TODO: ...

    def _getHandleId(self, handle, query, exception_not_exists=None):
        "Returns ID of handle."
        if exception_not_exists is None:
            exception_not_exists = Registry.DomainBrowser.OBJECT_NOT_EXISTS

        response = self.source.fetchall(query, dict(handle=handle))
        if not len(response):
            raise exception_not_exists

        return response[0][0]


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



class ListMetaInterface(BaseInterface):
    "Parent of interfaces with getDomainListMeta"

    PUBLIC_DATA, PRIVATE_DATA = range(2)
    PASSWORD_SUBSTITUTION = "********"

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
