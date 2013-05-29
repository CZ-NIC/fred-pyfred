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

        cls._conf = getConfiguration(CONFIGS)
        cls._log = Logger("pyfred")
        cls._db = MockDB(
            cls._conf.get("General", "dbhost"),
            cls._conf.get("General", "dbport"),
            cls._conf.get("General", "dbname"),
            cls._conf.get("General", "dbuser"),
            cls._conf.get("General", "dbpassword")
        )
        cls._corba_refs = CorbaRefs()
        cls._joblist = []


    def setUp(self):
        self.interface = DomainBrowserServerInterface(self._log, self._db,
                                    self._conf, self._joblist, self._corba_refs)

    def test_010_getObjectRegistryId(self):
        "Test getObjectRegistryId with domain fred.cz returns ID 33."
        response = self.interface.getObjectRegistryId("domain", "fred.cz")
        self.assertEqual(response, 33)



if __name__ == '__main__':
    unittest.main()
