#!/usr/bin/env python
# vim: set ts=4 sw=4:
#
# All changes in classes against standart distutils is marked with `DIST'
# string in comments above each change.

import sys, os, string, commands, re, shutil, stat, types
from glob import glob
from distutils import core
from distutils import cmd
from distutils import log
from distutils import util
from distutils import dep_util
from distutils import errors
from distutils import version
from distutils import sysconfig
from distutils import dir_util, dep_util, file_util, archive_util
from distutils.dir_util import remove_tree
from distutils.filelist import FileList
from distutils.text_file import TextFile
from distutils.command import config
from distutils.command import clean
from distutils.command.build import build
from distutils.command.build_py import build_py
from distutils.command.build_ext import build_ext
from distutils.command.build_scripts import build_scripts
from distutils.command.build_scripts import first_line_re
from distutils.command.install_data import install_data
from distutils.command.install_scripts import install_scripts
from distutils.command.sdist import sdist
from distutils.command.bdist import bdist
from distutils.command.bdist_rpm import bdist_rpm
from distutils.command import install
from distutils.core import Command

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
DEFAULT_PYFREDPORT = '2225'
DEFAULT_SENDMAIL = '/usr/sbin/sendmail'
#$localstatedir/lib/pyfred/filemanager
DEFAULT_FILEMANAGERFILES = 'lib/pyfred/filemanager/'
#whole path is by default $libexecdir/pyfred
DEFAULT_TECHCHECKSCRIPTDIR = 'pyfred' 
#whole is $localstatedir/run/pyfred.pid
DEFAULT_PIDFILE = 'run/pyfred.pid'
#$prefix/bin/pyfred_server
DEFAULT_PYFREDSERVER = 'bin/pyfred_server'
#$prefix/etc/fred/pyfred.conf
DEFAULT_PYFREDSERVERCONF = 'fred/pyfred.conf'
#whole is $localstatedir/zonebackup
DEFAULT_ZONEBACKUPDIR = 'zonebackup'

ETC_FRED_DIR = 'etc/fred'

core.DEBUG = False
modules = ["FileManager", "Mailer", "TechCheck", "ZoneGenerator"]

#directory containing setup.py script itself (and other sources as well)
g_srcdir = '.'
#store what return Install::get_actual_root method
g_actualRoot = ''
#variable to store content of --root install/build option
g_root = ''

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
#class Config

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
    for par in pars:
        if par.strip()[:2] == '-C':
            #param `-C' (Change directory do dir) was used, so test
            #and if need create directory build/lib
            if not os.path.exists(par.strip()[2:]):
                try:
                    os.makedirs(par.strip()[2:])
                    print "Create directory", par.strip()[2:]
                except OSError, e:
                    print e
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

class Build_py (build_py, object):
    """
    Standart distutils build_py does not support scrdir option. So Build_py class
    implements this funkcionality. This code is from 
    http://lists.mysql.com/ndb-connectors/617 
    """
    def get_package_dir(self, package):
        """
        Return the directory, relative to the top of the source
        distribution, where package 'package' should be found
        (at least according to the 'package_dir' option, if any).
        """
        #DIST line added
        self.srcdir = g_srcdir
        path = string.split(package, '.')

        if not self.package_dir:
            if path:
                #DIST line changed
                return os.path.join(self.srcdir, apply(os.path.join, path))
            else:
                #DIST line changed
                return self.srcdir
        else:
            tail = []
            while path:
                try:
                    pdir = self.package_dir[string.join(path, '.')]
                except KeyError:
                    tail.insert(0, path[-1])
                    del path[-1]
                else:
                    tail.insert(0, pdir)
                    #DIST line changed
                    return os.path.join(self.srcdir, apply(os.path.join, tail))
            else:
                # Oops, got all the way through 'path' without finding a
                # match in package_dir.  If package_dir defines a directory
                # for the root (nameless) package, then fallback on it;
                # otherwise, we might as well have not consulted
                # package_dir at all, as we just use the directory implied
                # by 'tail' (which should be the same as the original value
                # of 'path' at this point).
                pdir = self.package_dir.get('')
                if pdir is not None:
                    tail.insert(0, pdir)

                if tail:
                    #DIST line changed
                    return os.path.join(self.srcdir, apply(os.path.join, tail))
                else:
                    #DIST line changed
                    return self.srcdir
    #get_package_dir()
#class Build_py

class Build_scripts(build_scripts):
    def copy_scripts (self):
        """Copy each script listed in 'self.scripts'; if it's marked as a
        Python script in the Unix way (first line matches 'first_line_re',
        ie. starts with "\#!" and contains "python"), then adjust the first
        line to refer to the current Python interpreter as we copy.
        """
        #DIST line added
        self.srcdir = g_srcdir
        self.mkpath(self.build_dir)
        outfiles = []
        for script in self.scripts:
            adjust = 0
            #DIST line added
            script = os.path.join(self.srcdir, script)
            script = util.convert_path(script)
            outfile = os.path.join(self.build_dir, os.path.basename(script))
            outfiles.append(outfile)

            if not self.force and not dep_util.newer(script, outfile):
                log.debug("not copying %s (up-to-date)", script)
                continue

            # Always open the file, but ignore failures in dry-run mode --
            # that way, we'll get accurate feedback if we can read the
            # script.
            try:
                f = open(script, "r")
            except IOError:
                if not self.dry_run:
                    raise
                f = None
            else:
                first_line = f.readline()
                if not first_line:
                    self.warn("%s is an empty file (skipping)" % script)
                    continue

                match = first_line_re.match(first_line)
                if match:
                    adjust = 1
                    post_interp = match.group(1) or ''

            if adjust:
                log.info("copying and adjusting %s -> %s", script,
                         self.build_dir)
                if not self.dry_run:
                    outf = open(outfile, "w")
                    if not sysconfig.python_build:
                        outf.write("#!%s%s\n" %
                                   (self.executable,
                                    post_interp))
                    else:
                        outf.write("#!%s%s\n" %
                                   (os.path.join(
                            sysconfig.get_config_var("BINDIR"),
                            "python" + sysconfig.get_config_var("EXE")),
                                    post_interp))
                    outf.writelines(f.readlines())
                    outf.close()
                if f:
                    f.close()
            else:
                f.close()
                self.copy_file(script, outfile)

        if os.name == 'posix':
            for file in outfiles:
                if self.dry_run:
                    log.info("changing mode of %s", file)
                else:
                    oldmode = os.stat(file)[stat.ST_MODE] & 07777
                    newmode = (oldmode | 0555) & 07777
                    if newmode != oldmode:
                        log.info("changing mode of %s from %o to %o",
                                 file, oldmode, newmode)
                        os.chmod(file, newmode)
    # copy_scripts ()
#class Build_scripts

class Build_ext(build_ext):
    def build_extension(self, ext):
        #DIST line added
        self.srcdir = g_srcdir
        sources = ext.sources
        if sources is None or type(sources) not in (types.ListType, types.TupleType):
            raise DistutilsSetupError, \
                    ("in 'ext_modules' option (extension '%s'), " +
                            "'sources' must be present and must be " +
                            "a list of source filenames") % ext.name
        new_sources = []
        for source in sources: 
            #DIST line changed
            new_sources.append(os.path.join(self.srcdir,source))
        ext.sources = new_sources
        return build_ext.build_extension(self, ext)
    #build_extension()
#class Build_ext

class Install (install.install, object):
    user_options = []
    user_options.extend(install.install.user_options)
    user_options.append(('modules=', None, 'which pyfred modules will be loaded'
        ' [genzone mailer filemanager techcheck]'))
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
    user_options.append(('pyfredport=', None, '  [2225]'))
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
        global g_srcdir
        self.srcdir = g_srcdir

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
        self.pyfredport = DEFAULT_PYFREDPORT

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
        self.omniidl_params = ["-Cbuild/lib", "-bpython", "-Wbinline"]
        self.idlfiles = ["FileManager", "Mailer", "TechCheck", "ZoneGenerator"]
        self.sysconfdir = None
        self.libexecdir = None
        self.localstatedir = None

    def finalize_options(self):
        cmd_obj = self.distribution.get_command_obj('bdist', False)
        if cmd_obj:
            #this will be proceeded only if install command will be
            #invoked from bdist command
            self.idldir = cmd_obj.idldir
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
                if i[0] == ETC_FRED_DIR:
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
        super(Install, self).finalize_options()

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
        body = open(os.path.join(self.srcdir, 'conf', 'pyfred.conf.install')).read()

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
        body = re.sub('PYFREDPORT', self.pyfredport, body)

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

        #XXX it will be better to use some variable instead of bare `build'
        #(but simple) string. For example Install_scripts class has install_dir
        #variable (looks like: `build/scripts2.5') which can be used to find
        #out that build directory. But this class (equally as Install_data class)
        #hasn't got this variable.
        open(os.path.join('build', 'pyfred.conf'), 'w').write(body)
        print "Configuration file has been updated"

    def update_genzone_config(self):
        """
        Update paths in genzone.conf file.
        """
        body = open(os.path.join(self.srcdir, 'conf', 'genzone.conf.install')).read()

        body = re.sub('NSHOST', self.nshost, body)

        if self.get_actual_root():
            body = re.sub('ZONEBACKUPDIR', os.path.join(self.root,
                self.localstatedir[1:], DEFAULT_ZONEBACKUPDIR), body)
        else:
            body = re.sub('ZONEBACKUPDIR', os.path.join(self.localstatedir,
                DEFAULT_ZONEBACKUPDIR), body)

        open('build/genzone.conf', 'w').write(body)
        print "genzone configuration file has been updated"

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
        if self.root:
            fileManagerDir = os.path.join(self.root, self.localstatedir[1:], DEFAULT_FILEMANAGERFILES)
            pidDir = os.path.join(self.root, self.localstatedir[1:], 'run')
        else:
            fileManagerDir = os.path.join(self.localstatedir, DEFAULT_FILEMANAGERFILES)
            pidDir = os.path.join(self.localstatedir, 'run')

        if not os.path.exists(pidDir):
            try:
                os.makedirs(pidDir)
                print "Creating directory", pidDir
            except OSError, e:
                print e

        if not os.path.exists(fileManagerDir):
            try:
                os.makedirs(fileManagerDir)
                print "Creating directory", fileManagerDir
            except OSError, e:
                print e

    def update_record_file(self):
        """
        This methods purpose is to add some files (listed in `files' variable -
        see below) to record file - this list is used by rpmbuild to decide
        which files are part of rpm archive.
        """
        bodyNew = None
        #proceed only if i wish to record installed files
        if self.record:
            body = open(self.record).readlines()
            bodyNew = []
            for i in body:
                if self.get_actual_root():
                    iNew = os.path.join('/', i)
                else:
                    iNew = os.path.join(self.root, i)
                bodyNew.append(iNew)
            if self.get_actual_root():
                prefix = self.prefix
            else:
                prefix = os.path.join(self.root, self.prefix[1:])
                
            #this path is prepended to each record in files variable
            libdir = 'lib/python2.5/site-packages'

            #list of files which i want add to record list.
            #each directory is represended by tuple, first entry is directory,
            #second is list of files in this directory
            files = [
                ('pyfred', 
                    ('__init__.pyc')), 
                ('pyfred/idlstubs', ('__init__.py', '__init__.pyc',
                    'FileManager_idl.py', 'FileManager_idl.pyc',
                    'Mailer_idl.py', 'Mailer_idl.pyc',
                    'TechCheck_idl.py', 'TechCheck_idl.pyc',
                    'ZoneGenerator_idl.py', 'ZoneGenerator_idl.pyc')),
                ('pyfred/idlstubs/ccReg', ('__init__.py',
                    '__init__.pyc')),
                ('pyfred/idlstubs/ccReg__POA', ('__init__.py',
                    '__init__.pyc'))]

            for record in files:
                dir = record[0]
                files = record[1]
                if type(files) == types.TupleType:
                    for file in files:
                        fileline = os.path.join(prefix, libdir, dir, file) + '\n'
                        if fileline not in bodyNew:
                            bodyNew.append(fileline)
                else:
                    fileline = os.path.join(prefix, libdir, dir, files)+ '\n'
                    if fileline in bodyNew:
                        bodyNew.append(fileline)

            open(self.record, 'w').writelines(bodyNew)
            print "record file has been updated"

    def run(self):
        global g_actualRoot, g_root
        #set actual root for install_script class which has no opportunity
        #to reach get_actual_root method
        g_actualRoot = self.get_actual_root()
        g_root = self.root

        # self.py_modules = self.distribution.py_modules
        # self.data_files = self.distribution.data_files

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

        self.update_server_config()
        self.update_genzone_config()
        self.createDirectories()

        super(Install, self).run()

        #append idl stubs to record file - due to rpm creation
        self.update_record_file()

#class Install

class Install_scripts(install_scripts):
    """
    Copy of standart distutils install_scripts with some small
    addons (new options derived from install class)
    """
    user_options = install_scripts.user_options
    user_options.append(('prefix=', None,
        'installation prefix'))
    user_options.append(('libexecdir=', None,
        'Program executables [PREFIX/libexec]'))
    user_options.append(('localstatedir=', None,
        'Modifiable single machine data [PREFIX/var]'))

    def initialize_options(self):
        self.prefix = None
        self.sysconfdir = None
        self.localstatedir = None
        return install_scripts.initialize_options(self)

    def finalize_options(self):
        self.set_undefined_options('install',
                ('prefix', 'prefix'),
                ('sysconfdir', 'sysconfdir'),
                ('localstatedir', 'localstatedir'))
        if not self.prefix:
            # prefix is empty - set it to the default value
            self.prefix="/usr/local/"

        if not self.localstatedir:
            #if localstatedir not set then it will be prefix/opt/
            self.localstatedir=os.path.join(self.prefix, 'var')

        if not self.sysconfdir:
            #if sysconfdir param is not set then set it to prefix/etc/
            self.sysconfdir=os.path.join(self.prefix, "etc")
        else:
            #otherwise set it to input value plus 'fred'
            for i in self.distribution.data_files:
                if i[0] == ETC_FRED_DIR:
                    tup = (os.path.join(self.sysconfdir, 'fred'), i[1])
                    #replace old and new path
                    self.distribution.data_files.remove(i)
                    self.distribution.data_files.append(tup)
                    break
        return install_scripts.finalize_options(self)

    def get_actual_root(self):
        return self.actualRoot

    def update_pyfredctl(self):
        """
        Update paths in pyfredctl file (location of pid file and pyfred_server file)
        """
        body = open(os.path.join(self.build_dir, 'pyfredctl')).read()

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

        open(os.path.join(self.build_dir, 'pyfredctl'), 'w').write(body)
        print "pyfredctl file has been updated"

    def update_pyfred_server(self):
        """
        Update paths in pyfred_server file (path to config file and search path for modules).
        """
        body = open(os.path.join(self.build_dir, 'pyfred_server')).read()

        #create path where python modules are located
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

        open(os.path.join(self.build_dir, 'pyfred_server'), 'w').write(body)
        print "pyfred_server file has been updated"

    def run(self):
        global g_actualRoot, g_root
        self.actualRoot = g_actualRoot
        self.root = g_root
        self.update_pyfredctl()
        self.update_pyfred_server()
        return install_scripts.run(self)
#class Install_scripts

class Install_data(install_data):
    """
    This is copy of standart distutils install_data class,
    with some minor changes in run method, due to srcdir option add
    """
    def run(self):
        #DIST line added
        self.srcdir = g_srcdir
        self.mkpath(self.install_dir)
        for f in self.data_files:
            if type(f) is types.StringType:
                #DIST next four lines added
                if os.path.exists(os.path.join('build', f)):
                    f = os.path.join('build', f)
                else:
                    f = os.path.join(self.srcdir, f)
                f = util.convert_path(f)
                if self.warn_dir:
                    self.warn("setup script did not provide a directory for "
                              "'%s' -- installing right in '%s'" %
                              (f, self.install_dir))
                # it's a simple file, so copy it
                (out, _) = self.copy_file(f, self.install_dir)
                self.outfiles.append(out)
            else:
                # it's a tuple with path to install to and a list of files
                dir = util.convert_path(f[0])
                if not os.path.isabs(dir):
                    dir = os.path.join(self.install_dir, dir)
                elif self.root:
                    dir = util.change_root(self.root, dir)
                self.mkpath(dir)

                if f[1] == []:
                    # If there are no files listed, the user must be
                    # trying to create an empty directory, so add the
                    # directory to the list of output files.
                    self.outfiles.append(dir)
                else:
                    # Copy files, adding them to the list of output files.
                    for data in f[1]:
                        #first look into ./build directory for requested
                        #data file. If this exists in build dir then
                        #use it and copy it into proper destination,
                        #otherwise use file from srcdir/
                        #DIST next four lines added
                        if os.path.exists(os.path.join('build', data)):
                            data = os.path.join('build', data)
                        else:
                            data = os.path.join(self.srcdir, data)
                        data = util.convert_path(data)
                        (out, _) = self.copy_file(data, dir)
                        self.outfiles.append(out)
    #run()
#class Install_data

class Sdist(sdist):
    """
    blah blah boring commentary
    """
    def initialize_options(self):
        return sdist.initialize_options(self)

    def finalize_options(self):
        sdist.finalize_options(self)
        global g_srcdir
        self.srcdir = g_srcdir
        self.manifest = os.path.join(self.srcdir, self.manifest)
        self.template = os.path.join(self.srcdir, self.template)

    def get_file_list (self):
        """Figure out the list of files to include in the source
        distribution, and put it in 'self.filelist'.  This might involve
        reading the manifest template (and writing the manifest), or just
        reading the manifest, or just using the default file set -- it all
        depends on the user's options and the state of the filesystem.
        """

        # If we have a manifest template, see if it's newer than the
        # manifest; if so, we'll regenerate the manifest.
        template_exists = os.path.isfile(self.template)
        if template_exists:
            template_newer = dep_util.newer(self.template, self.manifest)

        # The contents of the manifest file almost certainly depend on the
        # setup script as well as the manifest template -- so if the setup
        # script is newer than the manifest, we'll regenerate the manifest
        # from the template.  (Well, not quite: if we already have a
        # manifest, but there's no template -- which will happen if the
        # developer elects to generate a manifest some other way -- then we
        # can't regenerate the manifest, so we don't.)
        #DIST next command changed
        self.distribution.script_name = os.path.join(
                self.srcdir, self.distribution.script_name)
        self.debug_print("checking if %s newer than %s" %
                         (self.distribution.script_name, self.manifest))
        setup_newer = dep_util.newer(self.distribution.script_name,
                                     self.manifest)

        # cases:
        #   1) no manifest, template exists: generate manifest
        #      (covered by 2a: no manifest == template newer)
        #   2) manifest & template exist:
        #      2a) template or setup script newer than manifest:
        #          regenerate manifest
        #      2b) manifest newer than both:
        #          do nothing (unless --force or --manifest-only)
        #   3) manifest exists, no template:
        #      do nothing (unless --force or --manifest-only)
        #   4) no manifest, no template: generate w/ warning ("defaults only")

        manifest_outofdate = (template_exists and
                              (template_newer or setup_newer))
        force_regen = self.force_manifest or self.manifest_only
        manifest_exists = os.path.isfile(self.manifest)
        neither_exists = (not template_exists and not manifest_exists)

        # Regenerate the manifest if necessary (or if explicitly told to)
        if manifest_outofdate or neither_exists or force_regen:
            if not template_exists:
                self.warn(("manifest template '%s' does not exist " +
                           "(using default file list)") %
                          self.template)
            #DIST changes in next six lines
            self.filelist.findall(self.srcdir)
            if self.srcdir == os.curdir:
                for i in range(len(self.filelist.allfiles)):
                    self.filelist.allfiles[i] = os.path.join(
                            self.srcdir, self.filelist.allfiles[i])

            if self.use_defaults:
                self.add_defaults()

            if template_exists:
                self.read_template()

            if self.prune:
                self.prune_file_list()

            self.filelist.sort()
            self.filelist.remove_duplicates()
            self.write_manifest()

        # Don't regenerate the manifest, just read it in.
        else:
            self.read_manifest()

    # get_file_list ()


    def add_defaults (self):
        """Add all the default files to self.filelist:
          - README or README.txt
          - setup.py
          - test/test*.py
          - all pure Python modules mentioned in setup script
          - all C sources listed as part of extensions or C libraries
            in the setup script (doesn't catch C headers!)
        Warns if (README or README.txt) or setup.py are missing; everything
        else is optional.
        """

        #DIST self.srcdir added
        standards = [(
            os.path.join(self.srcdir, 'README'),
            os.path.join(self.srcdir, 'README.txt')),
            self.distribution.script_name]

        for fn in standards:
            if type(fn) is types.TupleType:
                alts = fn
                got_it = 0
                for fn in alts:
                    if os.path.exists(fn):
                        got_it = 1
                        self.filelist.append(fn)
                        break

                if not got_it:
                    self.warn("standard file not found: should have one of " +
                              string.join(alts, ', '))
            else:
                if os.path.exists(fn):
                    self.filelist.append(fn)
                else:
                    self.warn("standard file '%s' not found" % fn)

        #DIST self.srcdir added
        optional = [
                os.path.join(self.srcdir, 'test/test*.py'),
                os.path.join(self.srcdir, 'setup.cfg')]
        for pattern in optional:
            files = filter(os.path.isfile, glob(pattern))
            if files:
                self.filelist.extend(files)

        if self.distribution.has_pure_modules():
            build_py = self.get_finalized_command('build_py')
            self.filelist.extend(build_py.get_source_files())

        if self.distribution.has_ext_modules():
            build_ext = self.get_finalized_command('build_ext')
            self.filelist.extend(build_ext.get_source_files())

        if self.distribution.has_c_libraries():
            build_clib = self.get_finalized_command('build_clib')
            self.filelist.extend(build_clib.get_source_files())

        if self.distribution.has_scripts():
            build_scripts = self.get_finalized_command('build_scripts')
            #it is a little bit interesting that other parts has got
            #proper paths (e.g. full paths), only build_scripts
            #hasn't. So we must expand filenames with srcdir
            scripts_sources = build_scripts.get_source_files()
            #DIST self.srcdir added
            for i in range(len(scripts_sources)):
                scripts_sources[i] = os.path.join(
                        self.srcdir, scripts_sources[i])
            self.filelist.extend(scripts_sources)

    # add_defaults ()


    def read_template (self):
        """Read and parse manifest template file named by self.template.

        (usually "MANIFEST.in") The parsing and processing is done by
        'self.filelist', which updates itself accordingly.
        """
        log.info("reading manifest template '%s'", self.template)
        template = TextFile(self.template,
                            strip_comments=1,
                            skip_blanks=1,
                            join_lines=1,
                            lstrip_ws=1,
                            rstrip_ws=1,
                            collapse_join=1)

        while 1:
            line = template.readline()
            if line is None:            # end of file
                break

            chopped = line.split()
            if chopped[0] in ('include', 'exclude', 'global-include',
                    'global-exclude'):
                for i in range(1, len(chopped)):
                    #DIST self.srcdir added
                    chopped[i] = os.path.join(self.srcdir, chopped[i])
                line = ' '.join(chopped)
            elif chopped[0] in ('resursive-include', 'recursive-exclude'):
                #DIST self.srcdir added
                chopped[1] = os.path.join(self.srcdir, chopped[1])
                line = ' '.join(chopped)
            elif chopped[0] in ('graft', 'prune'):
                #DIST self.srcdir added
                chopped[1] = os.path.join(self.srcdir, chopped[1])
                line = ' '.join(chopped)
            try:
                self.filelist.process_template_line(line)
            except DistutilsTemplateError, msg:
                self.warn("%s, line %d: %s" % (template.filename,
                                               template.current_line,
                                               msg))

    # read_template ()

    def make_release_tree (self, base_dir, files):
        """Create the directory tree that will become the source
        distribution archive.  All directories implied by the filenames in
        'files' are created under 'base_dir', and then we hard link or copy
        (if hard linking is unavailable) those files into place.
        Essentially, this duplicates the developer's source tree, but in a
        directory named after the distribution, containing only the files
        to be distributed.
        """
        #same as files but with striped full path
        files_wo_path = []
        for file in files:
            #DIST self.srcdir added
            files_wo_path.append(file[len(self.srcdir)+1:])
        # Create all the directories under 'base_dir' necessary to
        # put 'files' there; the 'mkpath()' is just so we don't die
        # if the manifest happens to be empty.
        self.mkpath(base_dir)
        dir_util.create_tree(base_dir, files_wo_path, dry_run=self.dry_run)

        # And walk over the list of files, either making a hard link (if
        # os.link exists) to each one that doesn't already exist in its
        # corresponding location under 'base_dir', or copying each file
        # that's out-of-date in 'base_dir'.  (Usually, all files will be
        # out-of-date, because by default we blow away 'base_dir' when
        # we're done making the distribution archives.)

        if hasattr(os, 'link'):        # can make hard links on this system
            link = 'hard'
            msg = "making hard links in %s..." % base_dir
        else:                           # nope, have to copy
            link = None
            msg = "copying files to %s..." % base_dir

        if not files:
            log.warn("no files to distribute -- empty manifest?")
        else:
            log.info(msg)
        for file in files:
            if not os.path.isfile(file):
                log.warn("'%s' not a regular file -- skipping" % file)
            else:
                #DIST self.srcdir added
                dest = os.path.join(base_dir, file[len(self.srcdir)+1:])
                self.copy_file(file, dest, link=link)

        self.distribution.metadata.write_pkg_info(base_dir)

    # make_release_tree ()


#class Sdist

class Bdist(bdist):
    """
    bdist class
    """
    user_options = bdist.user_options
    user_options.append(("idldir=",  "d", 
        "directory where IDL files reside [/usr/local/share/idl/fred/]"))

    def initialize_options(self):
        self.prefix = None
        self.idldir = None
        return bdist.initialize_options(self)

    def finalize_options(self):
        global g_srcdir
        self.srcdir = g_srcdir
        self.set_undefined_options('install',
                ('idldir', 'idldir'))
        if not self.idldir:
            self.idldir = os.path.join(self.prefix, 'share', 'idl', 'fred')
        return bdist.finalize_options(self)
    def run(self):
        bdist.run(self)
#class Bdist

class Bdist_rpm(bdist_rpm):
    """
    bdist_rpm class
    """
    user_options = bdist_rpm.user_options
    user_options.append(("idldir=",  "d", 
        "directory where IDL files reside [/usr/local/share/idl/fred/]"))

    def initialize_options(self):
        self.prefix = None
        self.idldir = None
        return bdist_rpm.initialize_options(self)

    def finalize_options(self):
        global g_srcdir
        self.srcdir = g_srcdir
        self.set_undefined_options('install',
                ('idldir', 'idldir'))
        if not self.idldir:
            self.idldir = os.path.join(self.prefix, 'share', 'idl', 'fred')

        #extra parameters for spec file
        self.install_extra_pars = "--idldir=%s" % self.idldir

        return bdist_rpm.finalize_options(self)

    def _make_spec_file(self):
        """Generate the text of an RPM spec file and return it as a
        list of strings (one per line).
        """
        # definitions and headers
        spec_file = [
            '%define name ' + self.distribution.get_name(),
            '%define version ' + self.distribution.get_version().replace('-','_'),
            '%define unmangled_version ' + self.distribution.get_version(),
            '%define release ' + self.release.replace('-','_'),
            '',
            'Summary: ' + self.distribution.get_description(),
            ]

        # put locale summaries into spec file
        # XXX not supported for now (hard to put a dictionary
        # in a config file -- arg!)
        #for locale in self.summaries.keys():
        #    spec_file.append('Summary(%s): %s' % (locale,
        #                                          self.summaries[locale]))

        spec_file.extend([
            'Name: %{name}',
            'Version: %{version}',
            'Release: %{release}',])

        # XXX yuck! this filename is available from the "sdist" command,
        # but only after it has run: and we create the spec file before
        # running "sdist", in case of --spec-only.
        if self.use_bzip2:
            spec_file.append('Source0: %{name}-%{unmangled_version}.tar.bz2')
        else:
            spec_file.append('Source0: %{name}-%{unmangled_version}.tar.gz')

        spec_file.extend([
            'License: ' + self.distribution.get_license(),
            'Group: ' + self.group,
            'BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot',
            'Prefix: %{_prefix}', ])

        if not self.force_arch:
            # noarch if no extension modules
            if not self.distribution.has_ext_modules():
                spec_file.append('BuildArch: noarch')
        else:
            spec_file.append( 'BuildArch: %s' % self.force_arch )

        for field in ('Vendor',
                      'Packager',
                      'Provides',
                      'Requires',
                      'Conflicts',
                      'Obsoletes',
                      ):
            val = getattr(self, string.lower(field))
            if type(val) is types.ListType:
                spec_file.append('%s: %s' % (field, string.join(val)))
            elif val is not None:
                spec_file.append('%s: %s' % (field, val))


        if self.distribution.get_url() != 'UNKNOWN':
            spec_file.append('Url: ' + self.distribution.get_url())

        if self.distribution_name:
            spec_file.append('Distribution: ' + self.distribution_name)

        if self.build_requires:
            spec_file.append('BuildRequires: ' +
                             string.join(self.build_requires))

        if self.icon:
            spec_file.append('Icon: ' + os.path.basename(self.icon))

        if self.no_autoreq:
            spec_file.append('AutoReq: 0')

        spec_file.extend([
            '',
            '%description',
            self.distribution.get_long_description()
            ])

        # put locale descriptions into spec file
        # XXX again, suppressed because config file syntax doesn't
        # easily support this ;-(
        #for locale in self.descriptions.keys():
        #    spec_file.extend([
        #        '',
        #        '%description -l ' + locale,
        #        self.descriptions[locale],
        #        ])

        # rpm scripts
        # figure out default build script
        def_setup_call = "%s %s" % (self.python,os.path.basename(sys.argv[0]))
        def_build = "%s build" % def_setup_call
        if self.use_rpm_opt_flags:
            def_build = 'env CFLAGS="$RPM_OPT_FLAGS" ' + def_build

        # insert contents of files

        # XXX this is kind of misleading: user-supplied options are files
        # that we open and interpolate into the spec file, but the defaults
        # are just text that we drop in as-is.  Hmmm.

        script_options = [
            ('prep', 'prep_script', "%setup -n %{name}-%{unmangled_version}"),
            ('build', 'build_script', def_build),
            ('install', 'install_script',
             ("%s install "
              "--root=$RPM_BUILD_ROOT "
              "--record=INSTALLED_FILES "
              #DIST next line is only one changed in _make_spec_file
              "%s") % (def_setup_call, self.install_extra_pars)),
            ('clean', 'clean_script', "rm -rf $RPM_BUILD_ROOT"),
            ('verifyscript', 'verify_script', None),
            ('pre', 'pre_install', None),
            ('post', 'post_install', None),
            ('preun', 'pre_uninstall', None),
            ('postun', 'post_uninstall', None),
        ]

        for (rpm_opt, attr, default) in script_options:
            # Insert contents of file referred to, if no file is referred to
            # use 'default' as contents of script
            val = getattr(self, attr)
            if val or default:
                spec_file.extend([
                    '',
                    '%' + rpm_opt,])
                if val:
                    spec_file.extend(string.split(open(val, 'r').read(), '\n'))
                else:
                    spec_file.append(default)


        # files section
        spec_file.extend([
            '',
            '%files -f INSTALLED_FILES',
            '%defattr(-,root,root)',
            ])

        if self.doc_files:
            spec_file.append('%doc ' + string.join(self.doc_files))

        if self.changelog:
            spec_file.extend([
                '',
                '%changelog',])
            spec_file.extend(self.changelog)

        return spec_file

    # _make_spec_file ()

    def run(self):
        bdist_rpm.run(self)
#class Bdist

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


def main():
    try:
        core.setup(name="fred-pyfred", version="1.8.0",
                description="Component of FRED (Fast Registry for Enum and Domains)",
                author   = "Jan Kryl",
                author_email="jan.kryl@nic.cz",
                url      = "http://enum.nic.cz/",
                license  = "GNU GPL",
                cmdclass = { "config":Config,
                             "clean":Clean,
                             "build_py":Build_py,
                             "build_ext":Build_ext,
                             "build_scripts":Build_scripts,
                             "install":Install,
                             "install_data":Install_data,
                             "install_scripts":Install_scripts,
                             "sdist":Sdist,
                             "bdist":Bdist,
                             "bdist_rpm":Bdist_rpm},
                packages = ["pyfred", "pyfred.modules"],
                py_modules = ['pyfred.idlstubs',
                    'pyfred.idlstubs.ccReg',
                    'pyfred.idlstubs.ccReg__POA'],
                #XXX 'requires' option does not work allthough it is described in
                #official documentation.

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
                    (ETC_FRED_DIR, ["pyfred.conf","genzone.conf"]),
                    ]
                )
        return True
    except Exception, e:
        log.error("Error: %s", e)
        return False

if __name__ == '__main__':
    g_srcdir = os.path.dirname(sys.argv[0])
    if not g_srcdir:
        g_srcdir = os.curdir
    if main():
        print "All done!"
