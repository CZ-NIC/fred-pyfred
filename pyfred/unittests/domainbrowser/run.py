#!/usr/bin/env python
"Main entry pyfred (domainbrowser) unittest point."

__unittest = True

try:
    from unittest.main import main, TestProgram, USAGE_AS_MAIN
except ImportError:
    # backward compatibility with python version < 2.7
    from unittest2.main import main, TestProgram, USAGE_AS_MAIN

# pyfred
from pyfred.unittests.runner import PyfredTestRunner


TestProgram.USAGE = USAGE_AS_MAIN
main(module=None, testRunner=PyfredTestRunner)
