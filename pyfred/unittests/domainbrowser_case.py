#!/usr/bin/env python
import os
import logging
import unittest
from unittest.util import safe_repr
# pyfred
from pyfred.runtime_support import Logger, CorbaRefs, getConfiguration, CONFIGS
from pyfred.modules.domainbrowser import DomainBrowserServerInterface
from pyfred.unittests.utils import MockDB
from pyfred.idlstubs import Registry



class DomainBrowserTestCase(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        "Run once per test."
        handler = logging.StreamHandler()
        logging.getLogger('').addHandler(handler)

        conf = getConfiguration(CONFIGS)
        log = Logger("pyfred")
        cls.db = MockDB(
            conf.get("General", "dbhost"),
            conf.get("General", "dbport"),
            conf.get("General", "dbname"),
            conf.get("General", "dbuser"),
            conf.get("General", "dbpassword")
        )

        # True - store SQL query and response info files.
        if os.environ.get("TRACK"):
            cls.db.track_traffic = True
        # True - overwrite existing files with query and response.
        if os.environ.get("TRACKW"):
            cls.db.overwrite_existing = True

        corba_refs = CorbaRefs()
        joblist = []
        cls.interface = DomainBrowserServerInterface(log, cls.db, conf, joblist, corba_refs)

    @classmethod
    def _regref(cls, object_id, handle, name=""):
        "return Registry.DomainBrowser.RegistryReference"
        return Registry.DomainBrowser.RegistryReference(object_id, handle, name)

    def compareContactDetail(self, detail1, detail2, msg=None):
        "Compare contact details."
        for key in detail1.__dict__.keys():
            value1, value2 = getattr(detail1, key), getattr(detail2, key)
            if key == "registrar":
                self.compareRegistryReference(value1, value2)
                continue
            if key == "disclose_flags":
                self.compareDiscloseFlags(value1, value2)
                continue
            if value1 != value2:
                raise self.failureException('ContactDetail.%s: %s != %s' % (key, safe_repr(value1), safe_repr(value2)))

    def _compare_items(self, keys, ref1, ref2, msg):
        "Compare items by keys."
        for key in keys:
            value1, value2 = getattr(ref1, key), getattr(ref2, key)
            if value1 != value2:
                raise self.failureException(msg % (key, safe_repr(value1), safe_repr(value2)))

    def compareEnumItem(self, ref1, ref2, msg=None):
        "Compare Enum item."
        #EnumItem = {_n: PUBLIC_DATA, _parent_id: 'IDL:Registry/DomainBrowser/DataAccessLevel:1.0',  _v: 1}
        self._compare_items(("_n", "_v", "_parent_id"), ref1, ref2, msg if msg else 'EnumItem.%s: %s != %s')

    def compareRegistryReference(self, ref1, ref2, msg=None):
        "Compare contact details."
        self._compare_items(("id", "handle", "name"), ref1, ref2, 'RegistryReference.%s: %s != %s')

    def compareDiscloseFlags(self, flags1, flags2):
        "Compare Disclose lags."
        self._compare_items(("name", "organization", "email", "address",
                            "telephone", "fax", "ident", "vat", "notify_email"),
                            flags1, flags2, 'DiscloseFlags.%s: %s != %s')

    def compareHost(self, ref1, ref2, msg=None):
        "Compare contact details."
        self._compare_items(("fqdn", "inet"), ref1, ref2, msg if msg else 'Host.%s: %s != %s')

    def compareNssetDetail(self, detail1, detail2, msg=None):
        "Compare contact details."
        for key in detail1.__dict__.keys():
            value1, value2 = getattr(detail1, key), getattr(detail2, key)
            if key == "hosts":
                if len(value1) != len(value2):
                    raise self.failureException('NssetDetail.%s: different length %d != %d' % (key, len(value1), len(value2)))
                for host1, host2 in zip(value1, value2):
                    self.compareHost(host1, host2, 'Nsset.host.%s: %s != %s')
                continue
            if key == "admins":
                for admin1, admin2 in zip(value1, value2):
                    self.compareRegistryReference(admin1, admin2, 'Nsset.admin.%s: %s != %s')
                continue
            if key in ("registrar", "create_registrar", "update_registrar"):
                self.compareRegistryReference(value1, value2)
                continue
            if value1 != value2:
                raise self.failureException('NssetDetail.%s: %s != %s' % (key, safe_repr(value1), safe_repr(value2)))
