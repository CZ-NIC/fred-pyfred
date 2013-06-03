#!/usr/bin/env python

# Usage:
# pyfred/unittests$
#   python -m unittest --verbose test_domainbrowser_contact
# pyfred$
#   python -m unittest --verbose unittests.test_domainbrowser_contact
# only defined test(s):
#   python -m unittest --verbose unittests.test_domainbrowser_contact.TestDomainBrowserContact.test_010
import unittest
# pyfred
from pyfred.unittests.utils import provide_data
from pyfred.idlstubs import Registry
from pyfred.unittests.domainbrowser_case import DomainBrowserTestCase



class TestDomainBrowserContact(DomainBrowserTestCase):
    "Test DomainBrowser contacts"

    def test_010(self):
        "Test getObjectRegistryId with invalid registry object type - INCORRECT_USAGE."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.getObjectRegistryId, "foo", "kontakt")

    def test_020(self):
        "Test getObjectRegistryId contact foo does not exist and raise OBJECT_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.OBJECT_NOT_EXISTS, self.interface.getObjectRegistryId, "contact", "foo")

    def test_030(self):
        "Test getObjectRegistryId with contact KONTAKT returns ID 30."
        response = self.interface.getObjectRegistryId("contact", "KONTAKT")
        self.assertEqual(response, 30)

    def test_040(self):
        "Test getContactDetail KONTAKT; language 'en'."
        self.maxDiff = None
        detail, owner = self.interface.getContactDetail(self.user_contact, self._regref(30L, "kontakt"), "en")
        data = provide_data("contact_detail_kontakt_en", dict(detail=detail, owner=owner), self.db.track_traffic)
        self.addTypeEqualityFunc(type(owner), self.compareEnumItem)
        self.assertEqual(owner, data["owner"])
        self.assertIsInstance(detail, Registry.DomainBrowser.ContactDetail)
        self.addTypeEqualityFunc(type(detail), self.compareContactDetail)
        self.assertEqual(detail, data["detail"])

    def test_045(self):
        "Test getContactDetail when some relation in database is corrupted (returns more than one record)."
        self.assertRaises(Registry.DomainBrowser.INTERNAL_SERVER_ERROR, self.interface.getContactDetail,
                          self.user_contact, self._regref(141L, "BOB"), "en")

    def test_050(self):
        "Test getRegistrarDetail REG-FRED_A"
        self.maxDiff = None
        detail = self.interface.getRegistrarDetail(self._regref(30L, "KONTAKT"), "REG-FRED_A")
        refdetail = provide_data("registrar_detail_regfreda", detail, self.db.track_traffic)
        self.assertIsInstance(detail, Registry.DomainBrowser.RegistrarDetail)
        self.assertIsInstance(refdetail, Registry.DomainBrowser.RegistrarDetail)
        self.assertDictEqual(detail.__dict__, refdetail.__dict__)

    def test_060(self):
        "Test setContactDiscloseFlags for KONTAKT with disclose notify_email."
        flags = Registry.DomainBrowser.UpdateContactDiscloseFlags(
                    email=True,
                    address=False,
                    telephone=True,
                    fax=False,
                    ident=False,
                    vat=False,
                    notify_email=False
                   )
        response = self.interface.setContactDiscloseFlags(self._regref(30L, "kontakt"), flags, self.request_id)
        self.assertTrue(response)

    def test_070(self):
        "Test setContactDiscloseFlags for KONTAKT with disclose notify_email but no change."
        self.db.stage_pos = 1 # The db state is after UPDATE contact.disclose_flag.notify_email
        flags = Registry.DomainBrowser.UpdateContactDiscloseFlags(
                    email=True,
                    address=False,
                    telephone=True,
                    fax=False,
                    ident=False,
                    vat=False,
                    notify_email=False
                   )
        response = self.interface.setContactDiscloseFlags(self._regref(30L, "kontakt"), flags, self.request_id)
        self.assertFalse(response)

    def test_080(self):
        "Test setContactDiscloseFlags try to set readlony flags (name, organization)."
        flags = Registry.DomainBrowser.ContactDiscloseFlags(
                    name=True, # this is not a parameter of UpdateContactDiscloseFlags
                    organization=True, # this is not a parameter of UpdateContactDiscloseFlags
                    email=True,
                    address=False,
                    telephone=True,
                    fax=False,
                    ident=False,
                    vat=False,
                    notify_email=False
                   )
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.setContactDiscloseFlags,
                          self._regref(30L, "kontakt"), flags, self.request_id)

    def test_090(self):
        "Test setAuthInfo to KONTAKT."
        response = self.interface.setAuthInfo(self.user_contact, "contact",
                                              self._regref(30L, "KONTAKT"), "password", self.request_id)
        self.assertTrue(response)

    def test_100(self):
        "Test setAuthInfo to KONTAKT but it is already set."
        self.db.stage_pos = 1
        response = self.interface.setAuthInfo(self.user_contact, "contact",
                                              self._regref(30L, "KONTAKT"), "password", self.request_id)
        self.assertFalse(response)

    def test_110(self):
        "Test setAuthInfo but for unsupported type - domain."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.setAuthInfo,
                          self.user_contact, "domain", self._regref(33L, "fred.cz"), "password", self.request_id)

    def test_120(self):
        "Test setAuthInfo but for unsupported type - nsset."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.setAuthInfo,
                          self.user_contact, "nsset", self._regref(31L, "NSSET:102"), "password", self.request_id)

    def test_130(self):
        "Test setAuthInfo but for unsupported type - keyset."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.setAuthInfo,
                          self.user_contact, "keyset", self._regref(32L, "KEYSID:102"), "password", self.request_id)

    def test_140(self):
        "Test getPublicStatusDesc; language 'en'."
        response = self.interface.getPublicStatusDesc("en")
        data = provide_data("public_status_desc_en", response, self.db.track_traffic)
        self.assertListEqual(response, data)




if __name__ == '__main__':
    unittest.main()
