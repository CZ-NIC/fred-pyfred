#!/usr/bin/env python

# Usage:
# pyfred/unittests$
#   python -m unittest --verbose test_domainbrowser_keyset
# pyfred$
#   python -m unittest --verbose unittests.test_domainbrowser_keyset
# only defined test(s):
#   python -m unittest --verbose unittests.test_domainbrowser_keyset.TestDomainBrowserKeyset.test_010
import unittest
# pyfred
from pyfred.idlstubs import Registry
from pyfred.unittests.domainbrowser.base import DomainBrowserTestCase



class TestDomainBrowserKeyset(DomainBrowserTestCase):
    "Test DomainBrowser Keyset"

    def test_010(self):
        "Test getObjectRegistryId for INCORRECT_USAGE."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.getObjectRegistryId, "foo", "KEYSID:102")

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

    def test_030(self):
        "Test getKeysetDetail KEYSID:102; language 'en'."
        self.maxDiff = None
        detail, owner = self.interface.getKeysetDetail(self.user_contact, self._regref(32L, "keysid:102"), "en")
        data = self.provide_data("keyset_detail_keysid102_en", dict(detail=detail, owner=owner))
        self.addTypeEqualityFunc(type(owner), self.compareEnumItem)
        self.assertEqual(owner, data["owner"])
        self.assertIsInstance(detail, Registry.DomainBrowser.KeysetDetail)
        self.addTypeEqualityFunc(type(detail), self.compareKeysetDetail)
        self.assertEqual(detail, data["detail"])

    def test_040(self):
        "Test setAuthInfo but for unsupported type - keyset."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.setAuthInfo,
                          self.user_contact, "keyset", self._regref(32L, "KEYSID:102"), "password", self.request_id)



if __name__ == '__main__':
    unittest.main()
