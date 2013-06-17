#!/usr/bin/env python

# Usage:
# pyfred/unittests$
#   python -m domainbrowser.run --verbose test_domainbrowser
# pyfred$
#   python -m unittests.domainbrowser.run --verbose unittests.test_domainbrowser

# write new dbdata:
#   TRACK=y python -m unittest --verbose unittests.domainbrowser.contact.TestDomainBrowserContact.test_010
#   where:
#       * TRACK=y means write database responses into files
#       * TRACKW=y means overwrite existing files
#
try:
    from unittest.util import safe_repr
    import unittest
except ImportError:
    # backward compatibility with python version < 2.7
    import unittest2 as unittest

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
