#!/usr/bin/python
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import ListMetaInterface
from pyfred.registry.utils import normalize_and_check_handle
from pyfred.registry.utils.decorators import furnish_database_cursor_m


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
    def getKeysetList(self, handle):
        return []

    def getKeysetDetail(self, keyset, handle):
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
        """
        self.logger.log(self.logger.DEBUG, 'Call KeysetInterface.getKeysetDetail(keyset="%s", handle="%s")' % (keyset, handle))
        handle = normalize_and_check_handle(self.logger, handle) # Registry.DomainBrowser.INCORRECT_USAGE
        return Registry.DomainBrowser.KeysetDetail(id=0)
