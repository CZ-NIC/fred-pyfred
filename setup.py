#!/usr/bin/env python
import os
import re

from freddist.core import setup
from freddist.command.install import install


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
#$prefix/bin/pyfred_server
DEFAULT_PYFREDSERVER = 'fred-pyfred'
#$prefix/etc/fred/pyfred.conf
DEFAULT_PYFREDSERVERCONF = 'fred/pyfred.conf'
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

    def update_script(self, filename):
        content = open(filename).read()
        content = content.replace('sys.path.insert(0, \'\')',
                                  'sys.path.insert(0, \'%s\')' % self.expand_filename('$purelib'))
        content = content.replace('configfile = \'/etc/fred/pyfred.conf\'',
                                  'configfile = \'%s\'' % self.expand_filename('$sysconf/fred/pyfred.conf'))
        open(filename, 'w').write(content)
        self.announce("File '%s' was updated" % filename)

    def update_genzone(self, filename):
        content = open(filename).read()
        content = content.replace('sys.path.insert(0, \'\')',
                                  'sys.path.insert(0, \'%s\')' % self.expand_filename('$purelib'))
        content = content.replace('configfile = \'/etc/fred/genzone.conf\'',
                                  'configfile = \'%s\'' % self.expand_filename('$sysconf/fred/genzone.conf'))
        open(filename, 'w').write(content)
        self.announce("File '%s' was updated" % filename)

    def update_pyfred_server(self, filename):
        """
        Update paths in fred-pyfred file (path to config file and search
        path for modules).
        """
        content = open(filename).read()
        content = re.compile('^PYFRED_INSTALL_PATH\s*=.*', re.MULTILINE).sub(
                         'PYFRED_INSTALL_PATH = "%s" # replaced by setup.py' % self.expand_filename('$purelib'),
                         content, 1)
        content = re.compile('^CONFIGS\s*=\s*\(.*', re.MULTILINE).sub(
                         'CONFIGS = ("%s", # replaced by setup.py' % self.expand_filename('$sysconf/%s' % DEFAULT_PYFREDSERVERCONF),
                         content, 1)
        open(filename, 'w').write(content)
        self.announce("File '%s' was updated" % filename)

    def update_pyfredctl(self, filename):
        """
        Update paths in pyfredctl file (location of pid file and
        fred-pyfred file)
        """
        content = open(filename).read()
        content = content.replace('pidfile = \'/var/run/pyfred.pid\'',
                                  'pidfile = \'%s\'' % self.expand_filename('$localstate/%s' % DEFAULT_PIDFILE))
        content = content.replace('pyfred_server = \'/usr/bin/fred-pyfred\'',
                                  'pyfred_server = \'%s\'' % self.expand_filename('$scripts/%s' % DEFAULT_PYFREDSERVER))
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
          version="2.10.0",
          description="Component of FRED (Fast Registry for Enum and Domains)",
          author="Jan Kryl",
          author_email="jan.kryl@nic.cz",
          url="http://fred.nic.cz/",
          license="GNU GPL",
          platforms=['posix'],
          cmdclass={"install": Install},
          packages=("pyfred",
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
          modify_files={'$scripts/genzone_client': 'update_genzone',
                        '$scripts/check_pyfred_genzone': 'update_genzone',
                        '$scripts/filemanager_client': 'update_script',
                        '$scripts/filemanager_admin_client': 'update_script',
                        '$scripts/mailer_client': 'update_script',
                        '$scripts/mailer_admin_client': 'update_script',
                        '$scripts/techcheck_client': 'update_script',
                        '$scripts/techcheck_admin_client': 'update_script',
                        '$scripts/fred-pyfred': 'update_pyfred_server',
                        '$scripts/pyfredctl': 'update_pyfredctl',
                        '$purelib/pyfred/unittests/test_filemanager.py': 'update_test_filemanager',
                        '$purelib/pyfred/unittests/test_genzone.py': 'update_test_genzone',
                        '$sysconf/fred/pyfred.conf': 'update_server_config',
                        '$sysconf/fred/genzone.conf': 'update_genzone_config',
                        })


if __name__ == '__main__':
    main()
