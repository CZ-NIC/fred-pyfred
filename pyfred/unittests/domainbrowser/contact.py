#!/usr/bin/env python
import os
import unittest
# pyfred
from pyfred.idlstubs import Registry
from pyfred.unittests.domainbrowser.base import DomainBrowserTestCase



class Test(DomainBrowserTestCase):
    "Test DomainBrowser contacts"
    TEST_FILE_NAME = "contact"

    def test_010(self):
        "Test getObjectRegistryId with invalid registry object type - INCORRECT_USAGE."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.getObjectRegistryId, "foo", "kontakt")

    def test_020(self):
        "Test getObjectRegistryId contact foo does not exist and raise OBJECT_NOT_EXISTS."
        self.assertRaises(Registry.DomainBrowser.OBJECT_NOT_EXISTS, self.interface.getObjectRegistryId, "contact", "foo")

    def test_030(self):
        "Test getObjectRegistryId with contact CONTACT returns ID 1."
        response = self.interface.getObjectRegistryId("contact", "CONTACT")
        self.assertEqual(response, 1)

    def test_040(self):
        "Test getContactDetail CIHAK; language 'en'."
        self.maxDiff = None
        detail, owner = self.interface.getContactDetail(self.user_contact, self._regref(2L, "cihak"), "en")
        data = self.provide_data("contact_detail_cihak_en", dict(detail=detail, owner=owner))
        self.addTypeEqualityFunc(type(owner), self.compareEnumItem)
        self.assertEqual(owner, data["owner"])
        self.assertIsInstance(detail, Registry.DomainBrowser.ContactDetail)
        self.addTypeEqualityFunc(type(detail), self.compareContactDetail)
        self.assertEqual(detail, data["detail"])

    def test_045(self):
        "Test getContactDetail when some relation in database is corrupted (returns more than one record)."
        self.assertRaises(Registry.DomainBrowser.INTERNAL_SERVER_ERROR, self.interface.getContactDetail,
                          self.user_contact, self._regref(7L, "BOB"), "en")

    def test_050(self):
        "Test getRegistrarDetail REG-FRED_A"
        self.maxDiff = None
        detail = self.interface.getRegistrarDetail(self.user_contact, "REG-FRED_A")
        refdetail = self.provide_data("registrar_detail_regfreda", detail)
        self.assertIsInstance(detail, Registry.DomainBrowser.RegistrarDetail)
        self.assertIsInstance(refdetail, Registry.DomainBrowser.RegistrarDetail)
        self.assertDictEqual(detail.__dict__, refdetail.__dict__)

    def test_060(self):
        "Test setContactDiscloseFlags for TESTER with disclose email, telephone, notify_email."
        #Disclose:                 voice
        #                          email
        #                          addr
        #Hide:                     vat
        #                          ident
        #                          fax
        #                          notify_email
        flags = Registry.DomainBrowser.UpdateContactDiscloseFlags(
                    email=True,
                    address=False,
                    telephone=True,
                    fax=False,
                    ident=False,
                    vat=False,
                    notify_email=True
                   )
        response = self.interface.setContactDiscloseFlags(self.user_contact, flags, self.request_id)
        self.assertTrue(response)


    def test_070(self):
        "Do setContactDiscloseFlags for TESTER again with no change."
        self.db.stage_pos = 1 # The db state is after UPDATE contact.disclose_flag.notify_email
        flags = Registry.DomainBrowser.UpdateContactDiscloseFlags(
                    email=True,
                    address=False,
                    telephone=True,
                    fax=False,
                    ident=False,
                    vat=False,
                    notify_email=True
                   )
        response = self.interface.setContactDiscloseFlags(self.user_contact, flags, self.request_id)
        self.assertFalse(response)

    def test_075(self):
        "Set setContactDiscloseFlags for ANNA fails with ACCESS_DENIED."
        flags = Registry.DomainBrowser.UpdateContactDiscloseFlags(
                    email=True,
                    address=False,
                    telephone=True,
                    fax=False,
                    ident=False,
                    vat=False,
                    notify_email=True
                   )
        self.assertRaises(Registry.DomainBrowser.ACCESS_DENIED, self.interface.setContactDiscloseFlags,
                          self._regref(4L, "ANNA"), flags, self.request_id)

    def test_080(self):
        "setContactDiscloseFlags try to set readlony flags (name, organization)."
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
                          self.user_contact, flags, self.request_id)

    def test_090(self):
        "Test setAuthInfo to TESTER."
        response = self.interface.setAuthInfo(self.user_contact, "contact",
                                              self._regref(6L, "TESTER"), "password", self.request_id)
        self.assertTrue(response)

    def test_100(self):
        "Test setAuthInfo to TESTER but it is already set."
        self.db.stage_pos = 1
        response = self.interface.setAuthInfo(self.user_contact, "contact",
                                              self._regref(6L, "TESTER"), "password", self.request_id)
        self.assertFalse(response)

    def test_110(self):
        "Test setAuthInfo but for unsupported type - domain."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.setAuthInfo,
                          self.user_contact, "domain", self._regref(28L, "nic01.cz"), "password", self.request_id)

    def test_120(self):
        "Test setAuthInfo but for unsupported type - nsset."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.setAuthInfo,
                          self.user_contact, "nsset", self._regref(8L, "NSSID01"), "password", self.request_id)

    def test_130(self):
        "Test setAuthInfo but for unsupported type - keyset."
        self.assertRaises(Registry.DomainBrowser.INCORRECT_USAGE, self.interface.setAuthInfo,
                          self.user_contact, "keyset", self._regref(18L, "KEYID01"), "password", self.request_id)

    def test_140(self):
        "Test getPublicStatusDesc; language 'en'."
        response = self.interface.getPublicStatusDesc("en")
        data = self.provide_data("public_status_desc_en", response)
        self.assertListEqual(response, data)




if __name__ == '__main__':
    unittest.main()
