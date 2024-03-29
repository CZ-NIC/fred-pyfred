#!/usr/bin/python2
#
# Copyright (C) 2013-2021  CZ.NIC, z. s. p. o.
#
# This file is part of FRED.
#
# FRED is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# FRED is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FRED.  If not, see <https://www.gnu.org/licenses/>.

import hashlib
import os
import re
import shutil

import pgdb
import yaml

from pyfred.runtime_support import DB

_MAX_LENGTH = 80
def safe_repr(obj, short=False):
    try:
        result = repr(obj)
    except Exception:
        result = object.__repr__(obj)
    if not short or len(result) < _MAX_LENGTH:
        return result
    return result[:_MAX_LENGTH] + ' [truncated]...'



def provide_data(name, data=None, subfolder=''):
    "Load or save data and return result."
    path = os.path.join(os.path.dirname(__file__), subfolder, "%s.yaml" % name)

    with open(path) as handle:
        data = yaml.load(handle)

    return data



def backup_subfolder(subfolder):
    "Backup data folder."
    fldname = lambda path, pos: "%s.bak%d" % (path, pos)
    path = os.path.join(os.path.dirname(__file__), subfolder)
    pos = 1
    # find free subfolder name
    while os.path.isdir(fldname(path, pos)):
        pos += 1
    shutil.move(path, fldname(path, pos))
    # create new subfolder
    os.mkdir(path)



class MockPgdbCursor(pgdb.pgdbCursor):
    "Mock Cursor Object."

    def __init__(self, dbcnx):
        self._dbcnx = dbcnx
        self._data_path = os.path.join(os.path.dirname(__file__), self._dbcnx.data_folder_name)
        self._cache_query = None

    def close(self):
        """Close the cursor object."""

    def execute(self, operation, params=None):
        "Prepare and execute a database operation (query or command)."
        self._cache_query = dict(query=operation, params=params)

    def fetchall(self):
        """Fetch all (remaining) rows of a query result."""
        query = self._cache_query["query"].strip()
        params = self._cache_query["params"]
        query_code = hashlib.md5(re.sub("\s+", " ", query).lower()).hexdigest()
        params_code = hashlib.md5(u"%s" % params).hexdigest()

        try:
            return self._dbcnx.db_data[query_code]["values"][params_code]["response"][self._dbcnx.stage_pos]
        except KeyError, msg:
            print
            print "KeyError:", msg
            print query_code
            print query
            print params_code
            print params
            print


class MockPgdbCnx(pgdb.pgdbCnx):
    "Mock Connection Object."

    data_folder_name = "dbdata"
    refs_folder_name = "refdata"

    # Database stage position is a data snapshot between any updates.
    stage_pos = 0

    def __init__(self, cnx=None):
        """Create a database connection object."""

    def close(self):
        "Close context"

    def cursor(self):
        "Return a new Cursor Object using the connection."
        return MockPgdbCursor(self)

    def commit(self):
        "Mock cursor commit"

    def rollback(self):
        "Mock cursor rollback"


class MockDB(DB):
    "Mock database."
    refs_folder_name = "refdata"
    db_data = None
    stage_pos = 0


    def getConn(self):
        "Obtain connection to database."
        contx = MockPgdbCnx(None)
        contx.db_data = self.db_data
        contx.stage_pos = self.stage_pos
        contx.refs_folder_name = self.refs_folder_name
        return contx
