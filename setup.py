#!/usr/bin/env python
# vim: set ts=4 sw=4:
#
import sys, os, string, commands, re, shutil
from distutils import core
from distutils import cmd
from distutils import log
from distutils import util
from distutils import errors
from distutils import version
from distutils.dir_util import remove_tree
from distutils.command import config
from distutils.command import clean
from distutils.command import install

PROJECT_NAME = 'pyfred_server'
PACKAGE_NAME = 'pyfred_server'
PACKAGE_VERSION = '1.8.0'
DEFAULT_DBUSER = 'fred'
DEFAULT_DBNAME = 'fred'
DEFAULT_DBHOST = 'localhost'
DEFAULT_DBPORT = '5432'
DEFAULT_DBPASS = ''
DEFAULT_MODULES = 'genzone mailer filemanager techcheck'
DEFAULT_NSCONTEXT = 'fred'
DEFAULT_NSHOST = 'localhost'
DEFAULT_NSPORT = '2809'
DEFAULT_SENDMAIL = '/usr/sbin/sendmail'
DEFAULT_FILEMANAGERFILES = 'lib/pyfred/filemanager/'
#whole path is by default prefix/libexecdir/pyfred
DEFAULT_TECHCHECKSCRIPTDIR = 'pyfred' 
DEFAULT_PIDFILE = 'run/pyfred.pid'
DEFAULT_PYFREDSERVER = 'bin/pyfred_server'
DEFAULT_PYFREDSERVERCONF = 'fred/pyfred.conf'

core.DEBUG = False
modules = ["FileManager", "Mailer", "TechCheck", "ZoneGenerator"]

class Config (config.config):
    """
    This is config class, which checks for pyfred specific prerequisities.
    """

    description = "Check prerequisities of pyfred"

    def run(self):
        """
        The equivalent of classic configure script. The list of things tested
        here:
            *) OS
            *) Python version
            *) presence of omniORB, pygresql, dnspython, clearsilver modules
        """

        # List of tests which follow
        error = False

        # OS
        log.info(" * Operating system ... %s", sys.platform)
        if sys.platform[:5] != "linux":
            log.error("    The pyfred is not platform independent and requires "
                    "linux OS to run.")

        # python version
        python_version = version.LooseVersion(sys.version.split(' ')[0])
        log.info(" * Python version ... %s", python_version)
        # check lower bound
        if python_version < "2.4":
            log.error("    At least version 2.4 is required.")
            error = True
        # check upper bound
        if python_version >= "2.6":
            log.warn("    Pyfred was tested with version 2.4 and 2.5. Running "
                    "more recent version of \n    python might lead to a "
                    "problems. You have been warned.")

        # check module (package) dependencies
        try:
            import omniORB
            log.info(" * Package omniORB found (version cannot be verified).")
        except ImportError, e:
            log.error(" * Package omniORB with python bindings is required and "
                    "not installed!")
            log.info("    omniORB is ORB implementation in C++ "
                    "(http://omniorb.sourceforge.net/)")
            error = True

        try:
            import pgdb
            pgdb_version = version.StrictVersion(pgdb.version)
            log.info(" * package pygresql version ... %s", pgdb.version)
            if pgdb_version < "3.6":
                log.error("    At least version 3.6 of pygresql is required!")
                error = True
            if pgdb_version >= "3.9":
                log.warn("    Versions newer than 3.8 of pygresql are not "
                        "tested to work with pyfred.\n    Use at your own risk.")
        except ImportError, e:
            log.error(" * Package pygresql is required and not installed!")
            log.info("    pygresql is DB2 API compliant library for postgresql "
                    "(http://www.pygresql.org/).")
            error = True

        try:
            import dns.version
            log.info(" * Package dnspython version ... %s", dns.version.version)
            dns_version = version.StrictVersion(dns.version.version)
            if dns_version < "1.3":
                log.error("    At least version 1.3 of dnspython is required!")
                error = True
            if dns_version > "1.5":
                log.warn("    Versions newer than 1.5 of dnspython are not "
                        "tested to work with pyfred.\n    Use at your own risk.")
        except ImportError, e:
            log.error(" * Package dnspython with python bindings is required "
                    "and not installed!")
            log.info("    dnspython is DNS library (http://www.dnspython.org/)")
            error = True

        try:
            import neo_cgi
            cs_CAPI_version = neo_cgi._C_API_NUM
            log.info(" * C API version of clearsilver ... %d", cs_CAPI_version)
            if cs_CAPI_version != 4:
                log.warn("    The only tested C API version of clearsilver is 4."
                        "   Use at your own risk")
        except ImportError, e:
            log.error(" * Package clearsilver with python bindings is required "
                    "and not installed!")
            log.info("    clearsilver is template system "
                    "(http://www.clearsilver.net/).")
            error = True

        # bad test
        #error = True

        # print concluding status of test
        if error:
            log.error("One or more errors were detected. Please fix them and "
                    "then run the \nsetup script again.")
            raise SystemExit(1)
        else:
            log.info("All tests were passed successfully")

def isDir(path):
    """return True if path is directory, otherwise False"""
    return os.path.stat.S_ISDIR(os.stat(path)[os.path.stat.ST_MODE])

def isFile(path):
    """return True if path is regular file, otherwise True"""
    return os.path.stat.S_ISREG(os.stat(path)[os.path.stat.ST_MODE])

def compile_idl(cmd, pars, files):
    """
    Put together command line for python stubs generation.
    """
    cmdline = cmd +' '+ string.join(pars) +' '+ string.join(files)
    log.info(cmdline)
    status, output = commands.getstatusoutput(cmdline)
    log.info(output)
    if status != 0:
        raise errors.DistutilsExecError("Return status of %s is %d" %
                (cmd, status))

def gen_idl_name(dir, name):
    """
    Generate name of idl file from directory prefix and IDL module name.
    """
    return os.path.join(dir, name + ".idl")

class Install (install.install, object):
    user_options = []
    user_options.extend(install.install.user_options)
    user_options.append(('modules=', None, 'which pyfred modules will be loaded \
        [genzone mailer filemanager techcheck]'))
    user_options.append(('sysconfdir=', None, 
        'System configuration directory [PREFIX/etc]'))
    user_options.append(('libexecdir=', None,
        'Program executables [PREFIX/libexec]'))
    user_options.append(('localstatedir=', None,
        'Modifiable single machine data [PREFIX/var]'))
    user_options.append(('nscontext=', None, 
        'CORBA nameservice context name [fred]'))
    user_options.append(('nshost=', None, 
        'CORBA nameservice host [localhost]'))
    user_options.append(('nsport=', None, 
        'Port where CORBA nameservice listen [2809]'))
    user_options.append(('dbuser=', None, 
        'Name of FRED database user [fred]'))
    user_options.append(('dbname=', None, 
        'Name of FRED database [fred]'))
    user_options.append(('dbhost=', None, 'FRED database host [localhost]'))
    user_options.append(('dbport=', None, 
        'Port where PostgreSQL database listening [5432]'))
    user_options.append(('dbpass=', None, 'Password to FRED database []'))
    user_options.append(('preservepath', None, 
        'Preserve path in configuration file.'))
    user_options.append(("omniidl=", "i", 
        "omniidl program used to build stubs [omniidl]"))
    user_options.append(("idldir=",  "d", 
        "directory where IDL files reside [PREFIX/share/idl/fred/]"))
    user_options.append(("idlforce", "o", 
        "force idl stubs to be always generated"))

    def __init__(self, *attrs):
        super(Install, self).__init__(*attrs)

        self.basedir = None
        self.interactive = None
        self.preservepath = None
        self.is_bdist_mode = None
        
        self.dbuser = DEFAULT_DBUSER
        self.dbname = DEFAULT_DBNAME
        self.dbhost = DEFAULT_DBHOST
        self.dbport = DEFAULT_DBPORT
        self.dbpass = DEFAULT_DBPASS
        self.nscontext = DEFAULT_NSCONTEXT
        self.nshost = DEFAULT_NSHOST
        self.nsport = DEFAULT_NSPORT
        self.sendmail = DEFAULT_SENDMAIL
        self.modules = DEFAULT_MODULES

        for dist in attrs:
            for name in dist.commands:
                if re.match('bdist', name): #'bdist' or 'bdist_rpm'
                    self.is_bdist_mode = 1 #it is bdist mode - creating a package
                    break
            if self.is_bdist_mode:
                break

    def initialize_options(self):
        super(Install, self).initialize_options()
        self.prefix = None
        self.idldir   = None
        self.idlforce = False
        self.omniidl  = None
        self.omniidl_params = ["-bpython", "-Wbinline"]
        self.idlfiles = ["FileManager", "Mailer", "TechCheck", "ZoneGenerator"]
        self.sysconfdir = None
        self.libexecdir = None
        self.localstatedir = None

    def finalize_options(self):
        super(Install, self).finalize_options()
        if not self.omniidl:
            self.omniidl = "omniidl"
        if not self.prefix:
            # prefix is empty - set it to the default value
            self.prefix="/usr/local/"
        if not self.idldir:
            # set idl directory to prefix/share/idl/fred/
            self.idldir=os.path.join(self.prefix, "share", "idl", "fred")
        if not self.localstatedir:
            #if localstatedir not set then it will be prefix/opt/
            self.localstatedir=os.path.join(self.prefix, 'var')

        if not self.sysconfdir:
            #if sysconfdir param is not set then set it to prefix/etc/
            self.sysconfdir=os.path.join(self.prefix, "etc")
        else:
            #otherwise set it to input value plus 'fred'
            for i in self.distribution.data_files:
                if i[0] == 'etc/fred':
                    tup = (os.path.join(self.sysconfdir, 'fred'), i[1])
                    #replace old and new path
                    self.distribution.data_files.remove(i)
                    self.distribution.data_files.append(tup)
                    break

        if not self.libexecdir:
            #if not set then prefix/libexec
            self.libexecdir=os.path.join(self.prefix, "libexec")
        else:
            #else input value plus "pyfred"
            for i in self.distribution.data_files:
                if i[0] == 'libexec/pyfred':
                    tup = (os.path.join(
                        self.libexecdir, DEFAULT_TECHCHECKSCRIPTDIR), i[1])
                    self.distribution.data_files.remove(i)
                    self.distribution.data_files.append(tup)
                    break

    def find_sendmail(self):
        self.sendmail = DEFAULT_SENDMAIL
        paths = ['/usr/bin', '/usr/sbin']
        filename = 'sendmail'
        for i in paths:
            if os.path.exists(os.path.join(i, filename)):
                self.sendmail = os.path.join(i, filename)
                return
        # self.sendmail= ''
        # self.modules = self.modules.replace('mailer', '')


    def update_server_config(self):
        """
        Update config items and paths in pyfred.conf file.
        """
        #try to find sendmail binary
        self.find_sendmail()
        body = open('pyfred.conf.install').read()

        #change configuration options
        body = re.sub('MODULES', self.modules, body)
        body = re.sub('DBUSER', self.dbuser, body)
        body = re.sub('DBNAME', self.dbname, body)
        body = re.sub('DBHOST', self.dbhost, body)
        body = re.sub('DBPORT', self.dbport, body)
        body = re.sub('DBPASS', self.dbpass, body)
        body = re.sub('NSCONTEXT', self.nscontext, body)
        body = re.sub('NSHOST', self.nshost, body)
        body = re.sub('NSPORT', self.nsport, body)
        body = re.sub('SENDMAIL', self.sendmail, body)

        #change paths to filemanager files and techcheck scripts and pid
        #file location
        if self.get_actual_root():
            body = re.sub('FILEMANAGERFILES', os.path.join(self.root,
                self.localstatedir[1:], DEFAULT_FILEMANAGERFILES), body)
            body = re.sub('TECHCHECKSCRIPTDIR', os.path.join(self.root, 
                self.libexecdir[1:], DEFAULT_TECHCHECKSCRIPTDIR), body)
            body = re.sub('PIDFILE', os.path.join(self.root, 
                self.localstatedir[1:], DEFAULT_PIDFILE), body)
        else:
            body = re.sub('FILEMANAGERFILES', os.path.join(self.localstatedir, 
                DEFAULT_FILEMANAGERFILES), body)
            body = re.sub('TECHCHECKSCRIPTDIR', os.path.join(self.libexecdir, 
                DEFAULT_TECHCHECKSCRIPTDIR), body)
            body = re.sub('PIDFILE', os.path.join(self.localstatedir, 
                DEFAULT_PIDFILE), body)

        open('pyfred.conf', 'w').write(body)
        print "Configuration file has been updated"

    def update_pyfredctl(self):
        """
        Update paths in pyfredctl file (location of pid file and pyfred_server file)
        """
        body = open('scripts/pyfredctl').read()

        #search path for pid and fred server file and replace it with correct one
        if self.get_actual_root():
            body = re.sub(r'(pidfile = )\'[\w/_ \-\.]*\'', r'\1' + "'"  + 
                    os.path.join(self.root, self.localstatedir[1:], 
                        DEFAULT_PIDFILE) + "'", body)
            body = re.sub(r'(pyfred_server = )\'[\w/_ \-\.]*\'', r'\1' + "'" + 
                    os.path.join(self.root, self.prefix[1:], 
                        DEFAULT_PYFREDSERVER) + "'", body)
        else:
            body = re.sub(r'(pidfile = )\'[\w/_ \-\.]*\'', r'\1' + "'"  + 
                    os.path.join(self.localstatedir, DEFAULT_PIDFILE) + "'", body)
            body = re.sub(r'(pyfred_server = )\'[\w/_ \-\.]*\'', r'\1' + "'" + 
                    os.path.join(self.prefix, DEFAULT_PYFREDSERVER) + "'", body)

        open('scripts/pyfredctl', 'w').write(body)
        print "pyfredctl file has been updated"

    def update_pyfred_server(self):
        """
        Update paths in pyfred_server file (path to config file and search path for modules).
        """
        body = open('scripts/pyfred_server').read()

        # create path where python modules are located
        pythonLibPath = os.path.join('lib', 'python' +
                str(sys.version_info[0]) + '.' + 
                str(sys.version_info[1]), 'site-packages')

        if self.get_actual_root():
            body = re.sub(r'(configs = )\["[\w/_\- \.]*",', r'\1' + '["'  + 
                    os.path.join(self.root, self.sysconfdir[1:], 
                        DEFAULT_PYFREDSERVERCONF) + '",', body)
            body = re.sub(r'(sys\.path\.append)\(\'[\w/_\- \.]*\'\)', r'\1' + 
                    "('" + os.path.join(self.root, self.prefix[1:], pythonLibPath) + 
                    "')", body)
        else:
            body = re.sub(r'(configs = )\["[\w/_\- \.]*",', r'\1' + '["'  + 
                    os.path.join(self.sysconfdir, DEFAULT_PYFREDSERVERCONF) + 
                    '",', body)
            body = re.sub(r'(sys\.path\.append)\(\'[\w/_\- \.]*\'\)', r'\1' + 
                    "('" + os.path.join(self.prefix, pythonLibPath) + "')", body)

        open('scripts/pyfred_server', 'w').write(body)
        print "pyfred_server file has been updated"

    def copyIdlStubs(self):
        """
        Copy created idl stubs into build directory, so install then copy these
        files into proper location.
        """
        dest = os.path.join(os.getcwd(), 'build', 'lib')
        src = os.getcwd()
        sources = self.py_modules
        for source in sources:
            source = source.replace('.', os.path.sep)
            if isDir(os.path.join(src, source)):
                try:
                    os.makedirs(os.path.join(dest, source))
                    print "creating %s directory" % os.path.join(dest, source)
                except OSError, e:
                    print e
                for i in os.listdir(os.path.join(src, source)):
                    if isFile(os.path.join(src, source, i)):
                        try:
                            shutil.copyfile(
                                    os.path.join(src, source, i), 
                                    os.path.join(dest, source, i))
                            print "file %s copied" % os.path.join(src, source, i)
                        except OSError, e:
                            print e

    def get_actual_root(self):
        '''
        Return actual root only in case if the process is not in creation of the package
        '''
        return ((self.is_bdist_mode or self.preservepath) and [''] or 
                [type(self.root) is not None and self.root or ''])[0]

    def createDirectories(self):
        """
        this create required directories if need
        """
        if self.get_actual_root():
            fileManagerDir = os.path.join(self.root, self.localstatedir[1:], DEFAULT_FILEMANAGERFILES)
            pidDir = os.path.join(self.root, self.localstatedir[1:], 'run')
        else:
            fileManagerDir = os.path.join(self.localstatedir, DEFAULT_FILEMANAGERFILES)
            pidDir = os.path.join(self.localstatedir, 'run')

        if not os.path.exists(pidDir):
            os.makedirs(pidDir)

        if not os.path.exists(fileManagerDir):
            os.makedirs(fileManagerDir)

    def run(self):
        self.py_modules = self.distribution.py_modules
        self.data_files = self.distribution.data_files

        #create (if need) idl files
        self.omniidl_params.append("-Wbpackage=pyfred.idlstubs")
        if not self.idlforce and os.access("pyfred/idlstubs/ccReg", os.F_OK):
            log.info("IDL stubs found, skipping build_idl target. Use idlforce "
                    "option to compile idl stubs anyway or run clean target.")
        else:
            util.execute(compile_idl,
                (self.omniidl, self.omniidl_params,
                    [ gen_idl_name(self.idldir, module) for module in modules ]),
                    "Generating python stubs from IDL files")
        #lets copy just created idl stubs into build/lib directory
        self.copyIdlStubs()

        #update scripts, config files, etc.
        self.update_server_config()
        self.update_pyfredctl()
        self.update_pyfred_server()

        self.createDirectories()

        super(Install, self).run()

class Clean (clean.clean):
    """
    This is here just to add cleaning of idl stub directory.
    """

    user_options = [
            ('build-dir=', 'b',
             "base build directory (default: 'build')"),
            ('build-idl=', 'i',
             "idl stubs build directory (default: 'pyfred/idlstubs')")
    ]

    def initialize_options(self):
        self.build_dir = None
        self.build_idl = None
        self.idlfiles = ["FileManager", "Mailer", "TechCheck", "ZoneGenerator"]

    def finalize_options(self):
        if self.build_dir == None:
            self.build_dir = "build"
        if self.build_idl == None:
            self.build_idl = "pyfred/idlstubs"

    def run(self):
        if os.path.exists(self.build_dir):
            remove_tree(self.build_dir, self.verbose, self.dry_run)
        else:
            log.warn("'%s' does not exist -- can't clean it" % self.build_dir)

        # remove ccReg
        if os.path.exists(self.build_idl + "/ccReg"):
            remove_tree(self.build_idl + "/ccReg", self.verbose, self.dry_run)
        else:
            log.warn("'%s' does not exist -- can't clean it" %
                    (self.build_idl + "/ccReg"))
        # remove ccReg__POA
        if os.path.exists(self.build_idl + "/ccReg__POA"):
            remove_tree(self.build_idl + "/ccReg__POA", self.verbose, self.dry_run)
        else:
            log.warn("'%s' does not exist -- can't clean it" %
                    (self.build_idl + "/ccReg__POA"))
        # remove module idls
        for mod in self.idlfiles:
            if os.path.exists(self.build_idl + "/" + mod + "_idl.py"):
                log.info("Removing " + self.build_idl + "/" + mod + "_idl.py ")
                if not self.dry_run:
                    os.unlink(self.build_idl + "/" + mod + "_idl.py")
            else:
                log.warn("'%s' does not exist -- can't clean it" %
                        (self.build_idl + "/" + mod + "_idl.py"))



try:
    core.setup(name="fred-pyfred", version="1.8.0",
            description="Component of FRED (Fast Registry for Enum and Domains)",
            author   = "Jan Kryl",
            author_email="jan.kryl@nic.cz",
            url      = "http://enum.nic.cz/",
            license  = "GNU GPL",
            cmdclass = { "config":Config,
                         "clean":Clean,
                         "install":Install},
            packages = ["pyfred", "pyfred.modules"],
            py_modules = ['pyfred.idlstubs', 
                'pyfred.idlstubs.ccReg',
                'pyfred.idlstubs.ccReg__POA'],
            # XXX 'requires' option does not work allthough it is described in
            # official documentation.
            #
            #requires = ["omniORB", "pgdb>=3.6", "dns>=1.3", "neo_cgi"],
            scripts  = [
                "scripts/pyfred_server",
                "scripts/pyfredctl",
                "scripts/filemanager_admin_client",
                "scripts/filemanager_client",
                "scripts/genzone_client",
                "scripts/genzone_test",
                "scripts/mailer_admin_client",
                "scripts/mailer_client",
                "scripts/techcheck_admin_client",
                "scripts/techcheck_client",
                ],
            data_files = [
                ("libexec/pyfred",
                    [
                        "tc_scripts/authoritative.py",
                        "tc_scripts/autonomous.py",
                        "tc_scripts/existance.py",
                        "tc_scripts/heterogenous.py",
                        "tc_scripts/presence.py",
                        "tc_scripts/recursive4all.py",
                        "tc_scripts/recursive.py"
                    ]
                ),
                ("etc/fred", ["pyfred.conf","genzone.conf"])
                ]
            )

except Exception, e:
    log.error("Error: %s", e)

