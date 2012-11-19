#!/usr/bin/python
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import ListMetaInterface
from pyfred.registry.utils import normalize_and_check_handle
from pyfred.registry.utils.decorators import furnish_database_cursor_m


class NssetInterface(ListMetaInterface):
    "NSSET corba interface."

    def getNssetListMeta(self):
        "Get Nsset List Meta"
        return self._getObjectListMeta((
                            ("nsset_handle",     "TEXT"),
                            ("domain_count",     "INT"),
                            ("blocked_update",   "BOOL"),
                            ("blocked_transfer", "BOOL"),
                        ))

    @furnish_database_cursor_m
    def getNssetList(self, handle):
        return []

    def getNssetDetail(self, nsset, handle):
        """
        struct NSSetDetail {
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
            sequence<DNSHost> hosts;
            ObjectStatusSeq status_list;
            short report_level;
        };
        """
        self.logger.log(self.logger.DEBUG, 'Call NssetInterface.getNssetDetail(nsset="%s", handle="%s")' % (nsset, handle))
        handle = normalize_and_check_handle(self.logger, handle) # Registry.DomainBrowser.INCORRECT_USAGE
        return Registry.DomainBrowser.NssetDetail(id=0)
