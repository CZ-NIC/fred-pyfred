from distutils.command.install_lib import install_lib as _install_lib

class install_lib(_install_lib):
    def run(self):
        _install_lib.run(self)
