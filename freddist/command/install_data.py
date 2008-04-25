import types, os
from distutils import util
from distutils.command.install_data import install_data as _install_data

class install_data(_install_data):
    def finalize_options(self):
        self.srcdir = self.distribution.srcdir
        _install_data.finalize_options(self)

    def run(self):
        self.debug_print("running freddist install_data")
        #DIST line added
        self.mkpath(self.install_dir)
        for f in self.data_files:
            if type(f) is types.StringType:
                #NICDIST next line changed
                if not os.path.exists(f):
                    f = util.convert_path(os.path.join(self.srcdir, f))
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
                        #NICDIST next line changed
                        if not os.path.exists(data):
                            data = util.convert_path(os.path.join(self.srcdir, data))
                        (out, _) = self.copy_file(data, dir)
                        self.outfiles.append(out)

