#!/usr/bin/env python

# Usage:
# pyfred/unittests$
#   python -m unittest --verbose test_domainbrowser
# pyfred$
#   python -m unittest --verbose unittests.test_domainbrowser
#   python -m unittest --verbose unittests.domainbrowser.contact
#   python -m unittest --verbose unittests.domainbrowser.contact.TestDomainBrowserContact.test_010

# write new dbdata:
#   TRACK=y python -m unittest --verbose unittests.domainbrowser.contact.TestDomainBrowserContact.test_010
#   where:
#       * TRACK=y means write database responses into files
#       * TRACKW=y means overwrite existing files
#
import unittest
# pyfred
from pyfred.unittests.domainbrowser.contact import TestDomainBrowserContact
from pyfred.unittests.domainbrowser.domain import TestDomainBrowserDomain
from pyfred.unittests.domainbrowser.nsset import TestDomainBrowserNsset
from pyfred.unittests.domainbrowser.keyset import TestDomainBrowserKeyset


if __name__ == '__main__':
    suite = unittest.TestSuite()
    suite.addTest(TestDomainBrowserContact())
    suite.addTest(TestDomainBrowserDomain())
    suite.addTest(TestDomainBrowserNsset())
    suite.addTest(TestDomainBrowserKeyset())
    unittest.main()
