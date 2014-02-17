#!/usr/bin/env python
import os
import logging
import unittest
# pyfred
from pyfred.runtime_support import Logger, CorbaRefs, getConfiguration, init_logger
from pyfred.modules.domainbrowser import DomainBrowserServerInterface
from pyfred.unittests.utils import MockDB, provide_data, backup_subfolder
from pyfred.idlstubs import Registry
from pyfred.unittests.utils import provide_data, safe_repr


# Fisrt item was replaced by setup.py to the path according to installation path.
CONFIGS = ("/usr/etc/fred/pyfred.conf",
           "/etc/fred/pyfred.conf",
           "/usr/local/etc/fred/pyfred.conf",
           "pyfred.conf",
          )


class DomainBrowserTestCase(unittest.TestCase):

    LIST_LIMIT = 10 # reduce default limit of lists to increase the speed of tests

    BLOCK_TRANSFER, UNBLOCK_TRANSFER, \
    BLOCK_UPDATE, UNBLOCK_UPDATE, \
    BLOCK_TRANSFER_AND_UPDATE, UNBLOCK_TRANSFER_AND_UPDATE = range(6)

    DBDATA_SUBFOLDER = "domainbrowser/dbdata"
    REFDATA_SUBFOLDER = "domainbrowser/refdata"

    # this name is overwritten by child class
    TEST_FILE_NAME = "base"

    # None means do not short differences
    #maxDiff = None

    @classmethod
    def setUpClass(cls):
        "Run once per test."
        handler = logging.StreamHandler()
        logging.getLogger('').addHandler(handler)

        conf = getConfiguration(CONFIGS)

        # logger configuration
        logger_name = "pyfut"
        #loghandler = "file" # conf.get("General", "loghandler").lower()
        #loglevel = "debug" # conf.get("General", "loglevel").lower()
        #logfacility = conf.get("General", "logfacility").lower()
        #logfilename = "/tmp/fred-pyfred.log" # conf.get("General", "logfilename")
        #init_logger(loghandler, loglevel, logfacility, logfilename, logger_name)
        log = Logger(logger_name)

        cls.db = MockDB(None, None, None, None, None)
        cls.db.refs_folder_name = cls.REFDATA_SUBFOLDER
        cls.db.db_data = provide_data(cls.TEST_FILE_NAME, subfolder=cls.DBDATA_SUBFOLDER)

        corba_refs = CorbaRefs()
        joblist = []
        cls.interface = DomainBrowserServerInterface(log, cls.db, conf, joblist, corba_refs)

    @classmethod
    def _regref(cls, object_id, handle, name=""):
        "return Registry.DomainBrowser.RegistryReference"
        return Registry.DomainBrowser.RegistryReference(object_id, handle, name)


    def setUp(self):
        "set default db stage."
        self.db.stage_pos = 0
        self.request_id = 1
        self.user_contact = self._regref(6L, "TESTER")


    def provide_data(self, name, data):
        "Load (and save) data for asserting db response."
        return provide_data(name, data, self.db.refs_folder_name)


    def compareContactDetail(self, detail1, detail2, msg=None):
        "Compare contact details."
        for key in detail1.__dict__.keys():
            value1, value2 = getattr(detail1, key), getattr(detail2, key)
            if key == "registrar":
                self.compareRegistryReference(value1, value2, "Contact.registrar.%s: %s != %s")
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
        self._compare_items(("id", "handle", "name"), ref1, ref2, msg if msg else 'RegistryReference.%s: %s != %s')

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
                self.compareRegistryReference(value1, value2, "Nsset." + key + ".%s: %s != %s")
                continue
            if value1 != value2:
                raise self.failureException('NssetDetail.%s: %s != %s' % (key, safe_repr(value1), safe_repr(value2)))

    def compareDNSkeys(self, ref1, ref2, msg=None):
        "Compare contact details."
        # {alg: 5, flags: 257, key: AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8, protocol: 3}
        self._compare_items(("alg", "flags", "key", "protocol"), ref1, ref2, msg if msg else 'DNSkeys.%s: %s != %s')

    def compareDSrecords(self, ref1, ref2, msg=None):
        "Compare contact details."
        # {alg: 2, digest: HASH, digest_type: 256, key_tag: 11, max_sig_life: 128}
        self._compare_items(("alg", "digest", "digest_type", "key_tag", "max_sig_life"),
            ref1, ref2, msg if msg else 'DSrecords.%s: %s != %s')

    def compareKeysetDetail(self, detail1, detail2, msg=None):
        "Compare contact details."
        for key in detail1.__dict__.keys():
            value1, value2 = getattr(detail1, key), getattr(detail2, key)
            if key == "dnskeys":
                if len(value1) != len(value2):
                    raise self.failureException('KeysetDetail.%s: different length %d != %d' % (key, len(value1), len(value2)))
                for host1, host2 in zip(value1, value2):
                    self.compareDNSkeys(host1, host2, 'Keyset.dnskeys.%s: %s != %s')
                continue
            if key == "dsrecords":
                if len(value1) != len(value2):
                    raise self.failureException('KeysetDetail.%s: different length %d != %d' % (key, len(value1), len(value2)))
                for host1, host2 in zip(value1, value2):
                    self.compareDSrecords(host1, host2, 'Keyset.dsrecords.%s: %s != %s')
                continue
            if key == "admins":
                for admin1, admin2 in zip(value1, value2):
                    self.compareRegistryReference(admin1, admin2, 'Keyset.admin.%s: %s != %s')
                continue
            if key in ("registrar", "create_registrar", "update_registrar"):
                self.compareRegistryReference(value1, value2, "Keyset." + key + ".%s: %s != %s")
                continue
            if value1 != value2:
                raise self.failureException('KeysetDetail.%s: %s != %s' % (key, safe_repr(value1), safe_repr(value2)))

    def compareDomainDetail(self, detail1, detail2, msg=None):
        "Compare contact details."
        for key in detail1.__dict__.keys():
            value1, value2 = getattr(detail1, key), getattr(detail2, key)
            if key == "admins":
                for admin1, admin2 in zip(value1, value2):
                    self.compareRegistryReference(admin1, admin2, 'Domain.admin.%s: %s != %s')
                continue
            if key in ("registrant", "registrar", "nsset", "keyset"):
                self.compareRegistryReference(value1, value2, "Domain." + key + ".%s: %s != %s")
                continue
            if value1 != value2:
                raise self.failureException('DomainDetail.%s: %s != %s' % (key, safe_repr(value1), safe_repr(value2)))