#!/usr/bin/env python
# Usage:
# pyfred/unittests$
#   python -m unittest --verbose test_domainbrowser
# pyfred$
#   python -m unittest --verbose unittests.test_domainbrowser
#
import logging
import unittest
# pyfred
from pyfred.runtime_support import Logger, CorbaRefs, getConfiguration, CONFIGS
from pyfred.modules.domainbrowser import DomainBrowserServerInterface
from pyfred.unittests.utils import MockDB



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
        corba_refs = CorbaRefs()
        joblist = []
        cls.interface = DomainBrowserServerInterface(log, db, conf, joblist, corba_refs)

    def test_010_getObjectRegistryId(self):
        "Test getObjectRegistryId with domain fred.cz returns ID 33."
        response = self.interface.getObjectRegistryId("domain", "fred.cz")
        self.assertEqual(response, 33)

    def test_020_getObjectRegistryId(self):
        "Test getObjectRegistryId with contact KONTAKT returns ID 30."
        response = self.interface.getObjectRegistryId("contact", "KONTAKT")
        self.assertEqual(response, 30)


if __name__ == '__main__':
    unittest.main()
