#!/usr/bin/env python
import os
try:
    from unittest.runner import TextTestRunner, TextTestResult
except ImportError:
    # backward compatibility with python version < 2.7
    from unittest2.runner import TextTestRunner, TextTestResult
# pyfred
from pyfred.unittests import pgman



class PyfredTestResult(TextTestResult):
    "Database support."

    def startTestRun(self):
        "Create database if is required."
        if os.environ.get("NODB"):
            return # do not test with database

        # create postgres server and run it
        pgman.cluster_create()
        pgman.server_start()
        # create db user and database
        pgman.create_user_and_database()
        # load database snapshot for testing domainbrowser
        path = os.environ.get("USEDB")
        if path is None:
            # load default database snapshot
            path = os.path.join(os.path.dirname(__file__), "dbdata", "fred.dump.sql")
        pgman.load_into_database(path)


    def stopTestRun(self):
        "Destroy database if it was used."
        if os.environ.get("NODB"):
            return # do not test with database

        pgman.server_stop()
        pgman.cluster_destroy()


class PyfredTestRunner(TextTestRunner):
    resultclass = PyfredTestResult
