from distutils.command.build import build as _build

class build(_build):
    def run(self):
        print "nicdist build"
        _build.run(self)
