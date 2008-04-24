from distutils.dist import Distribution as _Distribution
from distutils.dist import DistributionMetadata

try:
    from freddist.command.build import build 
except ImportError:
    from command.build import build

try:
    from freddist.command.build_scripts import build_scripts
except ImportError:
    from command.build_scripts import build_scripts

try:
    from freddist.command.build_py import build_py
except ImportError:
    from command.build_py import build_py

try:
    from freddist.command.install import install
except ImportError:
    from command.install import install

try:
    from freddist.command.install_data import install_data
except ImportError:
    from command.install_data import install_data

try:
    from freddist.command.install_scripts import install_scripts
except ImportError:
    from command.install_scripts import install_scripts

class Distribution(_Distribution):
    def __init__(self, attrs=None):
        print "freddist distribution ctor"
        self.srcdir = None
        self.cmdclass = {}
        _Distribution.__init__(self, attrs)
        if not self.cmdclass.get('build'):
            self.cmdclass['build'] = build
        if not self.cmdclass.get('build_scripts'):
            self.cmdclass['build_scripts'] = build_scripts
        if not self.cmdclass.get('build_py'):
            self.cmdclass['build_py'] = build_py
        if not self.cmdclass.get('install'):
            self.cmdclass['install'] = install
        if not self.cmdclass.get('install_data'):
            self.cmdclass['install_data'] = install_data
        if not self.cmdclass.get('install_scripts'):
            self.cmdclass['install_scripts'] = install_scripts

    def has_srcdir (self):
        return self.srcdir and len(self.srcdir) > 0

