#!/usr/bin/env python

# Usage:
# pyfred/unittests$
#   python -m domainbrowser.run --verbose domainbrowser.nsset
# pyfred$
#   python -m unittests.domainbrowser.run --verbose unittests.domainbrowser.nsset
# only defined test(s):
#   python -m unittests.domainbrowser.run --verbose unittests.domainbrowser.nsset.TestDomainBrowserNsset.test_010
try:
    from unittest.util import safe_repr
    import unittest
except ImportError:
    # backward compatibility with python version < 2.7
    from unittest2.util import safe_repr
    import unittest2 as unittest
# pyfred
from pyfred.idlstubs import Registry
from pyfred.unittests.domainbrowser.base import DomainBrowserTestCase



class Test(DomainBrowserTestCase):
    "Test DomainBrowser NSSET"
    TEST_FILE_NAME = "nsset"

    def test_010(self):
        "Test getObjectRegistryId for INCORRECT_USAGE."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.getObjectRegistryId, "foo", "NSSID01")

    def test_020(self):
        "Test getObjectRegistryId nsset NSSET:FOO does not exist and raise OBJECT_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.OBJECT_NOT_EXISTS, self.interface.getObjectRegistryId, "nsset", "NSSET:FOO")

    def test_030(self):
        "Test getNssetList; language 'en' and page index 0."
        self.interface.nsset.list_limit = self.LIST_LIMIT
        table, exceeded = self.interface.getNssetList(self.user_contact, "en", 0)
        data = self.provide_data("nsset_list_en_0", dict(table=table, exceeded=exceeded))
        self.assertEqual(exceeded, data["exceeded"])
        self.assertListEqual(table, data["table"])

    def test_040(self):
        "Test getNssetDetail NSSID01; language 'en'."
        self.maxDiff = None
        detail, owner = self.interface.getNssetDetail(self.user_contact, self._regref(8L, "NSSID01"), "en")
        data = self.provide_data("nsset_detail_nssid01_en", dict(detail=detail, owner=owner))
        self.addTypeEqualityFunc(type(owner), self.compareEnumItem)
        self.assertEqual(owner, data["owner"])
        self.assertIsInstance(detail, Registry.DomainBrowser.NSSetDetail)
        self.addTypeEqualityFunc(type(detail), self.compareNssetDetail)
        self.assertEqual(detail, data["detail"])

    def test_050(self):
        "Test setAuthInfo but for unsupported type - nsset."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.setAuthInfo,
                          self.user_contact, "nsset", self._regref(8L, "NSSID01"), "password", self.request_id)



if __name__ == '__main__':
    unittest.main()
