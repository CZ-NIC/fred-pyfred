#!/usr/bin/env python
import unittest
# pyfred
from pyfred.idlstubs import Registry
from pyfred.unittests.domainbrowser.base import DomainBrowserTestCase



class Test(DomainBrowserTestCase):
    "Test DomainBrowser Keyset"
    TEST_FILE_NAME = "keyset"

    def test_010(self):
        "Test getObjectRegistryId for INCORRECT_USAGE."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.getObjectRegistryId, "foo", "KEYID01")

    def test_020(self):
        "Test getObjectRegistryId keyset KEYSID:FOO does not exist and raise OBJECT_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.OBJECT_NOT_EXISTS, self.interface.getObjectRegistryId, "keyset", "KEYSID:FOO")

    def test_030(self):
        "Test getKeysetList; language 'en' and page index 0."
        self.interface.keyset.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getKeysetList(self.user_contact, "en", 0)
        data = self.provide_data("keyset_list_en_0", dict(table=table, exceeded=exceeded))
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_040(self):
        "Test getKeysetDetail KEYID01; language 'en'."
        self.maxDiff = None
        detail, owner = self.interface.getKeysetDetail(self.user_contact, self._regref(18L, "KEYID01"), "en")
        data = self.provide_data("keyset_detail_keyid01_en", dict(detail=detail, owner=owner))
        self.addTypeEqualityFunc(type(owner), self.compareEnumItem)
        self.assertEqual(owner, data["owner"])
        self.assertIsInstance(detail, Registry.DomainBrowser.KeysetDetail)
        self.addTypeEqualityFunc(type(detail), self.compareKeysetDetail)
        self.assertEqual(detail, data["detail"])

    def test_050(self):
        "Test setAuthInfo but for unsupported type - keyset."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.setAuthInfo,
                          self.user_contact, "keyset", self._regref(18L, "KEYID01"), "password", self.request_id)

    def test_060(self):
        "Test setObjectBlockStatus."
        selections = (
            self._regref(18L, "KEYID01"),
        )
        action = Registry.DomainBrowser.ObjectBlockType._item(self.BLOCK_TRANSFER)
        status, blocked_names = self.interface.setObjectBlockStatus(self.user_contact, "keyset", selections, action)
        self.assertTrue(status)
        self.assertTupleEqual(blocked_names, ())

    def test_070(self):
        "Test setObjectBlockStatus but object has the status serverBlocked."
        selections = (
            self._regref(22L, "KEYID05"),
        )
        action = Registry.DomainBrowser.ObjectBlockType._item(self.BLOCK_TRANSFER)
        status, blocked_names = self.interface.setObjectBlockStatus(self.user_contact, "keyset", selections, action)
        self.assertFalse(status)
        self.assertTupleEqual(blocked_names, ('KEYID05',))


if __name__ == '__main__':
    unittest.main()
