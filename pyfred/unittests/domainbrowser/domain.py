#!/usr/bin/env python

# Usage:
# pyfred/unittests$
#   python -m unittest --verbose test_domainbrowser_domain
# pyfred$
#   python -m unittest --verbose unittests.test_domainbrowser_domain
# only defined test(s):
#   python -m unittest --verbose unittests.test_domainbrowser_domain.TestDomainBrowserDomain.test_010
import unittest
# pyfred
from pyfred.unittests.utils import provide_data
from pyfred.idlstubs import Registry
from pyfred.unittests.domainbrowser_case import DomainBrowserTestCase



class TestDomainBrowserDomain(DomainBrowserTestCase):
    "Test DomainBrowser domains"

    def test_010(self):
        "Test getObjectRegistryId for INCORRECT_USAGE."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.getObjectRegistryId, "foo", "fred.cz")

    def test_020(self):
        "Test getObjectRegistryId domain foo.cz does not exist and raise OBJECT_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.OBJECT_NOT_EXISTS, self.interface.getObjectRegistryId, "domain", "foo.cz")

    def test_030(self):
        "Test getObjectRegistryId with domain fred.cz returns ID 33."
        response = self.interface.getObjectRegistryId("domain", "fred.cz")
        self.assertEqual(response, 33)

    def test_040(self):
        "Test getDomainList with wrong lang code - INCORRECT_USAGE."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE,
                          self.interface.getDomainList, self.user_contact, "es", 0)

    def test_050(self):
        "Test getDomainList non exist user XKONTAKT - USER_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.USER_NOT_EXISTS,
                          self.interface.getDomainList, self._regref(30L, "xkontakt"), "en", 0)

    def test_060(self):
        "Test getDomainList non exist user ID 31 - USER_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.USER_NOT_EXISTS,
                          self.interface.getDomainList, self._regref(31L, "kontakt"), "en", 0)

    def test_070(self):
        "Test getDomainList; language 'en' and page index 0."
        self.interface.domain.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getDomainList(self.user_contact, "en", 0)
        data = provide_data("domain_list_en_0", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_080(self):
        "Test getDomainList; language 'cs' and page index 0."
        self.interface.domain.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getDomainList(self.user_contact, "cs", 0)
        data = provide_data("domain_list_cs_0", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_090(self):
        "Test getDomainList; language 'en' and page index 1100."
        self.interface.domain.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getDomainList(self.user_contact, "en", 1100)
        data = provide_data("domain_list_en_1100", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_100(self):
        "Test getDomainsForNsset NSSET:102; language 'en' and page index 0."
        self.interface.domain.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getDomainsForNsset(self.user_contact, self._regref(31L, "NSSET:102"), "en", 0)
        data = provide_data("domains_for_nsset102_en_0", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_110(self):
        "Test getDomainsForKeyset KEYSID:102; language 'en' and page index 0."
        self.interface.domain.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getDomainsForKeyset(self.user_contact, self._regref(32L, "KEYSID:102"), "en", 0)
        data = provide_data("domains_for_keyset102_en_0", dict(table=table, exceeded=exceeded), self.db.track_traffic)
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_120(self):
        "Test getDomainDetail fred.cz; language 'en'."
        self.maxDiff = None
        detail, owner = self.interface.getDomainDetail(self.user_contact, self._regref(33L, "FRED.CZ"), "en")
        data = provide_data("domain_detail_fredcz_en", dict(detail=detail, owner=owner), self.db.track_traffic)
        self.addTypeEqualityFunc(type(owner), self.compareEnumItem)
        self.assertEqual(owner, data["owner"])
        self.assertIsInstance(detail, Registry.DomainBrowser.DomainDetail)
        self.addTypeEqualityFunc(type(detail), self.compareDomainDetail)
        self.assertEqual(detail, data["detail"])

    def test_130(self):
        "Test getDomainDetail when some relation in database is corrupted (returns more than one record)."
        self.assertRaises(Registry.DomainBrowser.INTERNAL_SERVER_ERROR, self.interface.getDomainDetail,
                          self.user_contact, self._regref(38L, "wrong.cz"), "en")

    def test_140(self):
        "Test setAuthInfo but for unsupported type - domain."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.setAuthInfo,
                          self.user_contact, "domain", self._regref(33L, "fred.cz"), "password", self.request_id)

    def test_150(self):
        "Test setObjectBlockStatus BLOCK_TRANSFER for domains."
        selections = (
            self._regref(33L, "fred.cz"),
            self._regref(162L, "nic01.cz"),
            self._regref(170L, "nic09.cz"),
        )
        action = Registry.DomainBrowser.ObjectBlockType._item(self.BLOCK_TRANSFER)
        status, blocked_names = self.interface.setObjectBlockStatus(self.user_contact, "domain", selections, action)
        self.assertTrue(status)
        self.assertTupleEqual(blocked_names, ())

    def test_160(self):
        "Test setObjectBlockStatus BLOCK_TRANSFER for domains again, but all blocks are already set."
        self.db.stage_pos = 1
        selections = (
            self._regref(33L, "fred.cz"),
            self._regref(162L, "nic01.cz"),
            self._regref(170L, "nic09.cz"),
        )
        action = Registry.DomainBrowser.ObjectBlockType._item(self.BLOCK_TRANSFER)
        status, blocked_names = self.interface.setObjectBlockStatus(self.user_contact, "domain", selections, action)
        self.assertFalse(status)
        self.assertTupleEqual(blocked_names, ())

    def test_170(self):
        "Test setObjectBlockStatus UNBLOCK_TRANSFER for domains."
        self.db.stage_pos = 1
        selections = (
            self._regref(33L, "fred.cz"),
            self._regref(162L, "nic01.cz"),
            self._regref(170L, "nic09.cz"),
        )
        action = Registry.DomainBrowser.ObjectBlockType._item(self.UNBLOCK_TRANSFER)
        status, blocked_names = self.interface.setObjectBlockStatus(self.user_contact, "domain", selections, action)
        self.assertTrue(status)
        self.assertTupleEqual(blocked_names, ())

    def test_180(self):
        "Test setObjectBlockStatus BLOCK_TRANSFER_AND_UPDATE for domains."
        selections = (
            self._regref(33L, "fred.cz"),
            self._regref(162L, "nic01.cz"),
            self._regref(170L, "nic09.cz"),
        )
        action = Registry.DomainBrowser.ObjectBlockType._item(self.BLOCK_TRANSFER_AND_UPDATE)
        status, blocked_names = self.interface.setObjectBlockStatus(self.user_contact, "domain", selections, action)
        self.assertTrue(status)
        self.assertTupleEqual(blocked_names, ())

    def test_190(self):
        "Test setObjectBlockStatus BLOCK_TRANSFER_AND_UPDATE for domains again, but all blocks are already set."
        self.db.stage_pos = 1
        selections = (
            self._regref(33L, "fred.cz"),
            self._regref(162L, "nic01.cz"),
            self._regref(170L, "nic09.cz"),
        )
        action = Registry.DomainBrowser.ObjectBlockType._item(self.BLOCK_TRANSFER_AND_UPDATE)
        status, blocked_names = self.interface.setObjectBlockStatus(self.user_contact, "domain", selections, action)
        self.assertFalse(status)
        self.assertTupleEqual(blocked_names, ())

    def test_200(self):
        "Test setObjectBlockStatus UNBLOCK_TRANSFER_AND_UPDATE for domains."
        self.db.stage_pos = 1
        selections = (
            self._regref(33L, "fred.cz"),
            self._regref(162L, "nic01.cz"),
            self._regref(170L, "nic09.cz"),
        )
        action = Registry.DomainBrowser.ObjectBlockType._item(self.UNBLOCK_TRANSFER_AND_UPDATE)
        status, blocked_names = self.interface.setObjectBlockStatus(self.user_contact, "domain", selections, action)
        self.assertTrue(status)
        self.assertTupleEqual(blocked_names, ())



if __name__ == '__main__':
    unittest.main()
