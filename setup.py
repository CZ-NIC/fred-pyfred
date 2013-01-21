#!/usr/bin/env python
import os
import re

from distutils import errors, log, util
from subprocess import check_call, CalledProcessError

from freddist.core import setup
from freddist.command.build_py import build_py
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
#list of parameters for omniidl executable
OMNIIDL_PARAMS = ["-bpython", "-Wbinline", "-Wbpackage=pyfred.idlstubs"]


def compile_idl(omniidl, idl_params, files):
    """
    Compile idl stubs.
    """
    cmd = [omniidl] + idl_params + files
    log.info(' '.join(cmd))
    try:
        check_call(cmd)
    except CalledProcessError, error:
        raise errors.DistutilsExecError("Compilation of IDL failed: %s" % error)


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
        ("omniidl=", "i",
         "omniidl program used to build stubs [omniidl]"),
        ("idldir=", "d",
         "directory where IDL files reside [$data/share/idl/fred]"),
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
        self.idldir = None
        self.omniidl = 'omniidl'

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

        if not self.idldir:
            self.idldir = self.expand_filename('$data/share/idl/fred')

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
        content = content.replace('sys.path.insert(0, \'\')',
                                  'sys.path.insert(0, \'%s\')' % self.expand_filename('$purelib'))
        pattern = re.compile(r'configs = .*$', re.MULTILINE)
        content = pattern.sub('configs = ["%s",' % self.expand_filename('$sysconf/%s' % DEFAULT_PYFREDSERVERCONF),
                              content)
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


class BuildPy(build_py):
    user_options = build_py.user_options + [
        ('omniidl=', 'i',
         "omniidl program used to build stubs [omniidl]"),
        ('idldir=', 'd',
         "directory where IDL files reside [/usr/share/idl/fred]"),
    ]

    def initialize_options(self):
        build_py.initialize_options(self)
        self.omniidl = None
        self.idldir = None

    def finalize_options(self):
        build_py.finalize_options(self)
        # Get data from install command if it is finalized.
        # This is not the way `set_undefined_options` should be used :-/
        install_obj = self.distribution.get_command_obj('install')
        if install_obj.finalized:
            self.set_undefined_options('install',
                ('omniidl', 'omniidl'),
                ('idldir', 'idldir'))
        else:
            if not self.omniidl:
                self.omniidl = 'omniidl'
            if not self.idldir:
                self.idldir = '/usr/share/idl/fred'

    def run(self):
        # Run buidl itself
        build_py.run(self)
        # Now build idl stubs
        idl_file = os.path.join(self.build_lib, 'ccReg')
        if self.force or not os.path.exists(idl_file):
            args = (self.omniidl, OMNIIDL_PARAMS + ['-C%s' % self.build_lib],
                    [os.path.join(self.idldir, '%s.idl' % module) for module in MODULES])
            util.execute(compile_idl, args, "Compiling python stubs from IDL files")
        else:
            log.debug("skipping compilation of %s", idl_file)

    def get_outputs(self, include_bytecode=1):
        outputs = build_py.get_outputs(self, include_bytecode=include_bytecode)
        idl_build_dir = os.path.join(self.build_lib, 'pyfred', 'idlstubs')
        for module in MODULES:
            outputs.append(os.path.join(idl_build_dir, '%s.py' % module))
            if include_bytecode:
                outputs.append(os.path.join(idl_build_dir, '%s.pyc' % module))
                outputs.append(os.path.join(idl_build_dir, '%s.pyo' % module))
        return outputs


def main():
    setup(name="fred-pyfred",
          description="Component of FRED (Fast Registry for Enum and Domains)",
          author="Jan Kryl",
          author_email="jan.kryl@nic.cz",
          url="http://fred.nic.cz/",
          license="GNU GPL",
          platforms=['posix'],
          cmdclass={"install": Install, "build_py": BuildPy},
          packages=("pyfred", "pyfred.idlstubs", "pyfred.modules", "pyfred.unittests"),
          package_data={
              'pyfred.unittests': ['create_environment.sh', 'README', 'zone-file-check'],
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
