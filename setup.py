#!/usr/bin/python2
#
# Copyright (C) 2007-2022  CZ.NIC, z. s. p. o.
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

from setuptools import setup

ENTRY_POINTS = {'console_scripts': [
    'check_pyfred_genzone = pyfred.commands.check_pyfred_genzone:run_check_pyfred_genzone',
    'filemanager_admin_client = pyfred.commands.filemanager_admin_client:run_filemanager_admin_client',
    'filemanager_client = pyfred.commands.filemanager_client:run_filemanager_client',
    'fred-pyfred = pyfred.commands.fred_pyfred:run_fred_pyfred',
    'genzone_client = pyfred.commands.genzone_client:run_genzone_client',
    'mailer_admin_client = pyfred.commands.mailer_admin_client:run_mailer_admin_client',
    'mailer_client = pyfred.commands.mailer_client:run_mailer_client',
    'pyfredctl = pyfred.commands.pyfredctl:run_pyfredctl',
    'techcheck_admin_client = pyfred.commands.techcheck_admin_client:run_techcheck_admin_client',
    'techcheck_client = pyfred.commands.techcheck_client:run_techcheck_client']}


def main():
    setup(name="fred-pyfred",
          version="2.15.1",
          description="Component of FRED (Fast Registry for Enum and Domains)",
          author="Jan Kryl",
          author_email="jan.kryl@nic.cz",
          url="http://fred.nic.cz/",
          license="GPLv3+",
          platforms=['posix'],
          packages=("pyfred", "pyfred.commands", "pyfred.unittests", "pyfred.modules"),
          include_package_data=True,
          python_requires='~=2.7',
          install_requires=['PyGreSQL>=5', 'dnspython>=1.3'],
          data_files=[
              ('libexec/pyfred', ["tc_scripts/authoritative.py",
                                  "tc_scripts/autonomous.py",
                                  "tc_scripts/existance.py",
                                  "tc_scripts/heterogenous.py",
                                  "tc_scripts/presence.py",
                                  "tc_scripts/recursive4all.py",
                                  "tc_scripts/recursive.py",
                                  "tc_scripts/dnsseckeychase.py"])],
          entry_points=ENTRY_POINTS)


if __name__ == '__main__':
    main()
