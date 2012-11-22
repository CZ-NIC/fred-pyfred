#!/usr/bin/python
from pyfred.idlstubs import Registry
from pyfred.registry.utils import normalize_and_check_handle


class BaseInterface(object):
    "Base interface object."
    logger = None
    cursor = None
    limits = None

    def setObjectBlockStatus(self, handle, selections, action):
        "Dummy setObjectBlockStatus"
        self.logger.log(self.logger.DEBUG, 'Call BaseInterface.setObjectBlockStatus'
                        '(handle="%s", selections="%s", action="%s", )' % (handle, selections, action))
        handle = normalize_and_check_handle(self.logger, handle) # Registry.DomainBrowser.INCORRECT_USAGE
        # TODO: ...


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
