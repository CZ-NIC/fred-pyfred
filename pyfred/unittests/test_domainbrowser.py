#!/usr/bin/env python

# Usage:
# pyfred/unittests$
#   python -m unittest --verbose test_domainbrowser
# pyfred$
#   python -m unittest --verbose unittests.test_domainbrowser
# only defined test(s):
#   python -m unittest --verbose unittests.test_domainbrowser.TestDomainBrowser.test_0030

# write new dbdata:
#   TRACK=y python -m unittest --verbose unittests.test_domainbrowser.TestDomainBrowser.test_0030
#   where:
#       * TRACK=y means write database responses into files
#       * TRACKW=y means overwrite existing files
#
import unittest
# pyfred
from pyfred.unittests.utils import provide_data
from pyfred.idlstubs import Registry
from pyfred.unittests.domainbrowser_case import DomainBrowserTestCase



class TestDomainBrowser(DomainBrowserTestCase):
    "Test DomainBrowser"

    def test_0010(self):
        "Test getObjectRegistryId for INCORRECT_USAGE."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.getObjectRegistryId, "xdomain", "fred.cz")

    def test_0020(self):
        "Test getObjectRegistryId domain foo.cz does not exist and raise OBJECT_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.OBJECT_NOT_EXISTS, self.interface.getObjectRegistryId, "domain", "foo.cz")

    def test_0030(self):
        "Test getObjectRegistryId with domain fred.cz returns ID 33."
        response = self.interface.getObjectRegistryId("domain", "fred.cz")
        self.assertEqual(response, 33)

    def test_0040(self):
        "Test getObjectRegistryId with contact KONTAKT returns ID 30."
        response = self.interface.getObjectRegistryId("contact", "KONTAKT")
        self.assertEqual(response, 30)

    def test_0050(self):
        "Test getDomainList with wrong lang code - INCORRECT_USAGE."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE,
                          self.interface.getDomainList, self._regref(30L, "KONTAKT"), "es", 0)

    def test_0060(self):
        "Test getDomainList non exist user XKONTAKT - USER_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.USER_NOT_EXISTS,
                          self.interface.getDomainList, self._regref(30L, "XKONTAKT"), "en", 0)

    def test_0070(self):
        "Test getDomainList non exist user ID 31 - USER_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.USER_NOT_EXISTS,
                          self.interface.getDomainList, self._regref(31L, "KONTAKT"), "en", 0)

    def test_0080(self):
        "Test getDomainList page index 0."
        table, exceeded = self.interface.getDomainList(self._regref(30L, "KONTAKT"), "en", 0)
        data = provide_data("test_0080", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])



if __name__ == '__main__':
    unittest.main()
