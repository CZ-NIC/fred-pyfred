#!/usr/bin/env python
# Usage:
# pyfred/unittests$
#   python -m unittest --verbose test_domainbrowser
# pyfred$
#   python -m unittest --verbose unittests.test_domainbrowser
# only defined test(s):
#   python -m unittest --verbose unittests.test_domainbrowser.TestDomainBrowser.test_0030
import logging
import unittest
# pyfred
from pyfred.runtime_support import Logger, CorbaRefs, getConfiguration, CONFIGS
from pyfred.modules.domainbrowser import DomainBrowserServerInterface
from pyfred.unittests.utils import MockDB
from pyfred.idlstubs import Registry



class TestDomainBrowser(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        "Run once per test."
        handler = logging.StreamHandler()
        logging.getLogger('').addHandler(handler)

        conf = getConfiguration(CONFIGS)
        log = Logger("pyfred")
        db = MockDB(
            conf.get("General", "dbhost"),
            conf.get("General", "dbport"),
            conf.get("General", "dbname"),
            conf.get("General", "dbuser"),
            conf.get("General", "dbpassword")
        )

        # True - store SQL query and response info files.
        #db.track_traffic = True
        # True - overwrite existing files with query and response.
        #db.overwrite_existing = True

        corba_refs = CorbaRefs()
        joblist = []
        cls.interface = DomainBrowserServerInterface(log, db, conf, joblist, corba_refs)

    def test_0010(self):
        "Test getObjectRegistryId with domain fred.cz returns ID 33."
        response = self.interface.getObjectRegistryId("domain", "fred.cz")
        self.assertEqual(response, 33)

    def test_0020(self):
        "Test getObjectRegistryId with contact KONTAKT returns ID 30."
        response = self.interface.getObjectRegistryId("contact", "KONTAKT")
        self.assertEqual(response, 30)

    def test_0030(self):
        "Test getObjectRegistryId nsset NSSET does not exist and raise OBJECT_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.OBJECT_NOT_EXISTS, self.interface.getObjectRegistryId, "nsset", "NSSET")


if __name__ == '__main__':
    unittest.main()
