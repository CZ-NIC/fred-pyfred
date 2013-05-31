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
    LIST_LIMIT = 50

    def test_001(self):
        "Test getObjectRegistryId for INCORRECT_USAGE."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.getObjectRegistryId, "xdomain", "fred.cz")

    def test_002(self):
        "Test getObjectRegistryId domain foo.cz does not exist and raise OBJECT_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.OBJECT_NOT_EXISTS, self.interface.getObjectRegistryId, "domain", "foo.cz")

    def test_003(self):
        "Test getObjectRegistryId with domain fred.cz returns ID 33."
        response = self.interface.getObjectRegistryId("domain", "fred.cz")
        self.assertEqual(response, 33)

    def test_004(self):
        "Test getObjectRegistryId with contact KONTAKT returns ID 30."
        response = self.interface.getObjectRegistryId("contact", "KONTAKT")
        self.assertEqual(response, 30)

    def test_005(self):
        "Test getDomainList with wrong lang code - INCORRECT_USAGE."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE,
                          self.interface.getDomainList, self._regref(30L, "kontakt"), "es", 0)

    def test_006(self):
        "Test getDomainList non exist user XKONTAKT - USER_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.USER_NOT_EXISTS,
                          self.interface.getDomainList, self._regref(30L, "xkontakt"), "en", 0)

    def test_007(self):
        "Test getDomainList non exist user ID 31 - USER_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.USER_NOT_EXISTS,
                          self.interface.getDomainList, self._regref(31L, "kontakt"), "en", 0)

    def test_008(self):
        "Test getDomainList; language 'en' and page index 0."
        self.interface.domain.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getDomainList(self._regref(30L, "kontakt"), "en", 0)
        data = provide_data("domain_list_en_0", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_009(self):
        "Test getDomainList; language 'cs' and page index 0."
        self.interface.domain.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getDomainList(self._regref(30L, "kontakt"), "cs", 0)
        data = provide_data("domain_list_cs_0", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_010(self):
        "Test getDomainList; language 'en' and page index 1100."
        self.interface.domain.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getDomainList(self._regref(30L, "kontakt"), "en", 1100)
        data = provide_data("domain_list_en_1100", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_011(self):
        "Test getNssetList; language 'en' and page index 0."
        self.interface.nsset.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getNssetList(self._regref(30L, "kontakt"), "en", 0)
        data = provide_data("nsset_list_en_0", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_012(self):
        "Test getKeysetList; language 'en' and page index 0."
        self.interface.keyset.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getKeysetList(self._regref(30L, "kontakt"), "en", 0)
        data = provide_data("keyset_list_en_0", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_013(self):
        "Test getDomainsForNsset NSSET:102; language 'en' and page index 0."
        self.interface.domain.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getDomainsForNsset(self._regref(30L, "kontakt"), self._regref(31L, "NSSET:102"), "en", 0)
        data = provide_data("domains_for_nsset102_en_0", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_014(self):
        "Test getDomainsForKeyset KEYSID:102; language 'en' and page index 0."
        self.interface.domain.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getDomainsForKeyset(self._regref(30L, "kontakt"), self._regref(32L, "KEYSID:102"), "en", 0)
        data = provide_data("domains_for_keyset102_en_0", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_015(self):
        "Test getContactDetail KONTAKT; language 'en'."
        self.maxDiff = None
        detail, owner = self.interface.getContactDetail(self._regref(30L, "kontakt"), self._regref(30L, "kontakt"), "en")
        data = provide_data("contact_detail_kontakt_en", dict(detail=detail, owner=owner), self.db.track_traffic)
        self.addTypeEqualityFunc(type(owner), self.compareEnumItem)
        self.assertEqual(owner, data["owner"])
        self.assertIsInstance(detail, Registry.DomainBrowser.ContactDetail)
        self.addTypeEqualityFunc(type(detail), self.compareContactDetail)
        self.assertEqual(detail, data["detail"])



if __name__ == '__main__':
    unittest.main()
