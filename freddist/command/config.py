from distutils.command.config import config as _config

class config(_config):
    def run(self):
        print "nicdist config"
        _config.run(self)
