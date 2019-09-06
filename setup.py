#!/usr/bin/env python
#
# Copyright (C) 2007-2019  CZ.NIC, z. s. p. o.
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

import os

from freddist.command.install import install
from freddist.core import setup

PROJECT_NAME = 'pyfred_server'
PACKAGE_NAME = 'pyfred_server'

DEFAULT_DBUSER = 'fred'
DEFAULT_DBNAME = 'fred'
DEFAULT_DBHOST = 'localhost'
DEFAULT_DBPORT = '5432'
DEFAULT_DBPASS = ''
DEFAULT_MODULES = 'genzone mailer filemanager techcheck'
DEFAULT_NSCONTEXT = 'fred'
DEFAULT_NSHOST = 'localhost'
DEFAULT_NSPORT = '2809'
DEFAULT_PYFREDPORT = '2225'

#$localstatedir/lib/pyfred/filemanager
DEFAULT_FILEMANAGERFILES = 'lib/pyfred/filemanager/'
#whole path is by default $libexecdir/pyfred
DEFAULT_TECHCHECKSCRIPTDIR = 'pyfred'
#whole is $localstatedir/run/pyfred.pid
DEFAULT_PIDFILE = 'run/pyfred.pid'
#whole is $localstatedir/zonebackup
DEFAULT_ZONEBACKUPDIR = 'zonebackup'
#whole is $localstatedir/log/fred-pyfred.log
DEFAULT_LOGFILENAME = 'log/fred-pyfred.log'

#list of all default pyfred modules
MODULES = ["FileManager", "Mailer", "TechCheck", "ZoneGenerator"]


class Install(install):
    user_options = install.user_options + [
        ('modules=', None,
         "which pyfred modules will be loaded [genzone mailer filemanager techcheck]"),
        ('nscontext=', None,
         "CORBA nameservice context name [fred]"),
        ('nshost=', None,
         "CORBA nameservice host [localhost]"),
        ('nsport=', None,
         "Port where CORBA nameservice listen [2809]"),
        ('dbuser=', None,
         "Name of FRED database user [fred]"),
        ('dbname=', None,
         "Name of FRED database [fred]"),
        ('dbhost=', None,
         "FRED database host [localhost]"),
        ('dbport=', None,
         "Port where PostgreSQL database listening [5432]"),
        ('dbpass=', None,
         "Password to FRED database []"),
        ('pyfredport=', None,
         "  [2225]"),
        ("sendmail=", None,
         "sendmail path"),
        ("drill=", None,
         "drill utility path"),
    ]

    DEPS_PYMODULE = ('omniORB', 'pgdb (>= 3.6)', 'dns (>= 1.3)', 'neo_cgi _C_API_NUM(== 4)')
    DEPS_COMMAND = ('sendmail', 'drill')

    def initialize_options(self):
        install.initialize_options(self)
        self.basedir = None
        self.dbuser = DEFAULT_DBUSER
        self.dbname = DEFAULT_DBNAME
        self.dbhost = DEFAULT_DBHOST
        self.dbport = DEFAULT_DBPORT
        self.dbpass = DEFAULT_DBPASS

        self.drill = None
        self.nscontext = DEFAULT_NSCONTEXT
        self.nshost = DEFAULT_NSHOST
        self.nsport = DEFAULT_NSPORT
        self.modules = DEFAULT_MODULES
        self.pyfredport = DEFAULT_PYFREDPORT
        self.sendmail = None

    def finalize_options(self):
        install.finalize_options(self)
        if self.sendmail is None:
            for path in ('/usr/bin', '/usr/sbin'):
                full_path = os.path.join(path, 'sendmail')
                if os.path.exists(full_path):
                    self.sendmail = full_path
                    break
            else:
                raise SystemExit('sendmail not found.')

        if self.drill is None:
            for path in ('/usr/bin', '/usr/sbin'):
                full_path = os.path.join(path, 'drill')
                if os.path.exists(full_path):
                    self.drill = full_path
                    break
            else:
                raise SystemExit('drill not found.')

    def update_server_config(self, filename):
        """
        Update config items and paths in pyfred.conf file.
        """
        content = open(filename).read()
        content = content.replace('MODULES', self.modules)
        content = content.replace('DBUSER', self.dbuser)
        content = content.replace('DBNAME', self.dbname)
        content = content.replace('DBHOST', self.dbhost)
        content = content.replace('DBPORT', self.dbport)
        content = content.replace('DBPASS', self.dbpass)
        content = content.replace('NSCONTEXT', self.nscontext)
        content = content.replace('NSHOST', self.nshost)
        content = content.replace('NSPORT', self.nsport)
        content = content.replace('SENDMAIL', self.sendmail)
        content = content.replace('PYFREDPORT', self.pyfredport)
        content = content.replace('DRILL', self.drill)
        content = content.replace('FILEMANAGERFILES', self.expand_filename('$localstate/%s' % DEFAULT_FILEMANAGERFILES))
        content = content.replace('TECHCHECKSCRIPTDIR',
                                  self.expand_filename('$libexec/%s' % DEFAULT_TECHCHECKSCRIPTDIR))
        content = content.replace('PIDFILE', self.expand_filename('$localstate/%s' % DEFAULT_PIDFILE))
        content = content.replace('LOGFILENAME', self.expand_filename('$localstate/%s' % DEFAULT_LOGFILENAME))
        open(filename, 'w').write(content)
        self.announce("File '%s' was updated" % filename)

    def update_genzone_config(self, filename):
        """
        Update paths in genzone.conf file.
        """
        content = open(filename).read()
        content = content.replace('ZONEBACKUPDIR', self.expand_filename('$localstate'))
        content = content.replace('NAMESERVICE', '%s:%s' % (self.nshost, self.nsport))
        content = content.replace('CONTEXT', self.nscontext)
        open(filename, 'w').write(content)
        self.announce("File '%s' was updated" % filename)

    def update_test_filemanager(self, filename):
        content = open(filename).read()
        content = content.replace('pyfred_bin_dir = \'/usr/local/bin/\'',
                                  'pyfred_bin_dir = \'%s\'' % self.expand_filename('$scripts/'))
        open(filename, 'w').write(content)
        self.announce("File '%s' was updated" % filename)

    def update_test_genzone(self, filename):
        content = open(filename).read()
        content = content.replace('pyfred_bin_dir = \'/usr/local/bin/\'',
                                  'pyfred_bin_dir = \'%s\'' % self.expand_filename('$scripts/'))
        content = content.replace('\'/etc/fred/pyfred.conf\'',
                                  '\'%s\'' % self.expand_filename('$sysconf/fred/pyfred.conf'))
        content = content.replace('\'/etc/fred/genzone.conf\'',
                                  '\'%s\'' % self.expand_filename('$sysconf/fred/genzone.conf'))
        open(filename, 'w').write(content)
        self.announce("File '%s' was updated" % filename)



def main():
    setup(name="fred-pyfred",
          version="2.12.1",
          description="Component of FRED (Fast Registry for Enum and Domains)",
          author="Jan Kryl",
          author_email="jan.kryl@nic.cz",
          url="http://fred.nic.cz/",
          license="GPLv3+",
          platforms=['posix'],
          cmdclass={"install": Install},
          packages=("pyfred",
                    "pyfred.commands",
                    "pyfred.unittests",
                    "pyfred.modules"
                ),
          package_data={
              'pyfred.unittests': ['create_environment.sh', 'README', 'zone-file-check', 'dbdata/*'],
          },
          scripts=("scripts/fred-pyfred",
                   "scripts/pyfredctl",
                   "scripts/filemanager_admin_client",
                   "scripts/filemanager_client",
                   "scripts/genzone_client",
                   "scripts/check_pyfred_genzone",
                   "scripts/mailer_admin_client",
                   "scripts/mailer_client",
                   "scripts/techcheck_admin_client",
                   "scripts/techcheck_client"),
          data_files=[
              ('$localstate/run', []),
              ('$localstate/lib/pyfred/filemanager', []),
              ('$libexec/pyfred', ["tc_scripts/authoritative.py",
                                   "tc_scripts/autonomous.py",
                                   "tc_scripts/existance.py",
                                   "tc_scripts/heterogenous.py",
                                   "tc_scripts/presence.py",
                                   "tc_scripts/recursive4all.py",
                                   "tc_scripts/recursive.py",
                                   "tc_scripts/dnsseckeychase.py"]),
              ('$sysconf/fred', ['conf/pyfred.conf', 'conf/genzone.conf'])],
          modify_files={'$purelib/pyfred/unittests/test_filemanager.py': 'update_test_filemanager',
                        '$purelib/pyfred/unittests/test_genzone.py': 'update_test_genzone',
                        '$sysconf/fred/pyfred.conf': 'update_server_config',
                        '$sysconf/fred/genzone.conf': 'update_genzone_config',
                        })


if __name__ == '__main__':
    main()
