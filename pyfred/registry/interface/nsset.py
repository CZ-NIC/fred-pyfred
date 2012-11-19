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

        PUBLIC_DATA, PRIVATE_DATA = range(2)
        return (Registry.DomainBrowser.NSSetDetail(
                id=130,
                handle=handle,
                roid='C0000000003-CZ',
                registrar='REG-DESIGNATED',
                create_date='2012-03-14 11:16:28.516926',
                transfer_date='',
                update_date='',
                create_registrar='REG-CREATED',
                update_registrar='',
                auth_info='password',
                admins=('CONTACT04',),
                hosts=(
                    Registry.DomainBrowser.DNSHost("a.ns.nic.cz", "193.29.206.1 2001:678:1::1"),
                    Registry.DomainBrowser.DNSHost("b.ns.nic.cz", "196.30.208.2 2001:677:1::2")
                ),
                status_list = (),
                report_level=0
                ),
                Registry.DomainBrowser.DataAccessLevel._item(PRIVATE_DATA))
