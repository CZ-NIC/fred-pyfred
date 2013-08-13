#!/usr/bin/env python

# Usage:
# pyfred$
#   python -m unittest --verbose pyfred.unittests.domainbrowser

import unittest

# pyfred
from pyfred.unittests.domainbrowser.contact import Test as TestDomainBrowserContact
from pyfred.unittests.domainbrowser.domain import Test as TestDomainBrowserDomain
from pyfred.unittests.domainbrowser.nsset import Test as TestDomainBrowserNsset
from pyfred.unittests.domainbrowser.keyset import Test as TestDomainBrowserKeyset


if __name__ == '__main__':
    suite = unittest.TestSuite()
    suite.addTest(TestDomainBrowserContact())
    suite.addTest(TestDomainBrowserDomain())
    suite.addTest(TestDomainBrowserNsset())
    suite.addTest(TestDomainBrowserKeyset())
    unittest.main()
