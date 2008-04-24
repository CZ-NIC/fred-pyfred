import os, re
from distutils.command.install import install as _install
from distutils.debug import DEBUG

class install(_install):
    user_options = _install.user_options
    user_options.append(('sysconfdir=', None, 
        'System configuration directory [PREFIX/etc]'))
    user_options.append(('libexecdir=', None,
        'Program executables [PREFIX/libexec]'))
    user_options.append(('localstatedir=', None,
        'Modifiable single machine data [PREFIX/var]'))
    user_options.append(('preservepath', None, 
        'Preserve path(s) in configuration file(s).'))

    boolean_options = _install.boolean_options
    boolean_options.append('preservepath')

    def __init__(self, *attrs):
        _install.__init__(self, *attrs)

        self.is_bdist_mode = None

        for dist in attrs:
            for name in dist.commands:
                if re.match('bdist', name): #'bdist' or 'bdist_rpm'
                    self.is_bdist_mode = 1 #it is bdist mode - creating a package
                    break
            if self.is_bdist_mode:
                break
    def get_actual_root(self):
        '''
        Return actual root only in case if the process is not in creation of the package
        '''
        return ((self.is_bdist_mode or self.preservepath) and [''] or 
                [type(self.root) is not None and self.root or ''])[0]

    def initialize_options(self):
        _install.initialize_options(self)
        self.sysconfdir = None
        self.localstatedir = None
        self.libexecdir = None
        self.preservepath = None

    def finalize_options(self):
        self.srcdir = self.distribution.srcdir
        if not self.prefix:
            # prefix is empty - set it to the default value
            self.prefix = os.path.join('/', 'usr', 'local')
        if not self.sysconfdir:
            self.sysconfdir = os.path.join(self.prefix, 'etc')
        if not self.localstatedir:
            self.localstatedir = os.path.join(self.prefix, 'var')
        if not self.libexecdir:
            self.libexecdir = os.path.join(self.prefix, 'libexec')

        _install.finalize_options(self)

    def run(self):
        print "nicdist install"
        _install.run(self)
