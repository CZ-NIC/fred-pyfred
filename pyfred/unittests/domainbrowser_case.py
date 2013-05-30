#!/usr/bin/env python
import os
import logging
import unittest
# pyfred
from pyfred.runtime_support import Logger, CorbaRefs, getConfiguration, CONFIGS
from pyfred.modules.domainbrowser import DomainBrowserServerInterface
from pyfred.unittests.utils import MockDB
from pyfred.idlstubs import Registry



class DomainBrowserTestCase(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        "Run once per test."
        handler = logging.StreamHandler()
        logging.getLogger('').addHandler(handler)

        conf = getConfiguration(CONFIGS)
        log = Logger("pyfred")
        cls.db = MockDB(
            conf.get("General", "dbhost"),
            conf.get("General", "dbport"),
            conf.get("General", "dbname"),
            conf.get("General", "dbuser"),
            conf.get("General", "dbpassword")
        )

        # True - store SQL query and response info files.
        if os.environ.get("TRACK"):
            cls.db.track_traffic = True
        # True - overwrite existing files with query and response.
        if os.environ.get("TRACKW"):
            cls.db.overwrite_existing = True

        corba_refs = CorbaRefs()
        joblist = []
        cls.interface = DomainBrowserServerInterface(log, cls.db, conf, joblist, corba_refs)

    @classmethod
    def _regref(cls, object_id, handle, name=""):
        "return Registry.DomainBrowser.RegistryReference"
        return Registry.DomainBrowser.RegistryReference(object_id, handle, name)
