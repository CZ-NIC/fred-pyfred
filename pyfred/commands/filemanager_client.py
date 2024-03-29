#!/usr/bin/python2
#
# Copyright (C) 2006-2021  CZ.NIC, z. s. p. o.
#
# This file is part of FRED.
#
# FRED is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# FRED is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FRED.  If not, see <https://www.gnu.org/licenses/>.

import ConfigParser
import getopt
import os
import sys

import CosNaming
from fred_idl import ccReg
from omniORB import CORBA

DEV_STDIN = '-'

def usage():
    """
    Print usage information.
    """
    sys.stderr.write("""filemanager_client [options]

Options:
    -f, --file                    Set configuration file.
    -h, --help                    Print this help message.
    -i, --input=FILE              Send FILE to FileManager.
    -l, --label=NAME              Overwrite name of the input file.
    -n, --nameservice=HOST[:PORT] Set host where CORBA nameservice runs.
    -c, --context=CONTEXT         Set CORBA nameservice context name.
    -m, --mime=MIMETYPE           MIME type of input file (use only with -i).
    -o, --output=FILE             Write file retrieved from FileManager to FILE.
    -s, --silent                  Output to stdout plain data without text.
    -t, --type=NUMBER             File type of input file (use only with -i).
    -x, --id=ID                   ID of file (greater then zero).

Input and output parameter decides wether a file will be saved or loaded.
If none of them is specified and id is specified, then meta-info about file
with given id is retrieved. If none of input, output, id is specified, then
the input is read from stdin.
""")


def getinfo(fm, id):
    """
    Get meta information about file.
    """
    #
    # Call filemanager's function
    try:
        info = fm.info(id)
    except ccReg.FileManager.InternalError, e:
        sys.stderr.write("Internal error on server: %s\n" % e.message)
        sys.exit(10)
    except ccReg.FileManager.IdNotFound, e:
        sys.stderr.write("Id %d is not in database.\n" % id)
        sys.exit(13)
    except Exception, e:
        sys.stderr.write("Corba call failed: %s\n" % e)
        sys.exit(3)
    print "Meta information about file with id %d:" % id
    print "  id:       %d" % info.id
    print "  label:    %s" % info.name
    print "  mimetype: %s" % info.mimetype
    print "  filetype: %d" % info.filetype
    print "  created:  %s" % info.crdate
    print "  size:     %d" % info.size
    print "  repository path: %s" % info.path

def savefile(fm, mimetype, filetype, input, overwrite_label='', silent=False):
    """
    Save file to filemanager.
    """
    if input == DEV_STDIN:
        fd = sys.stdin
        label = 'stdin'
    else:
        fd = open(input, "rb")
        label = os.path.basename(input)
    if overwrite_label:
        label = overwrite_label
    #
    # Call filemanager's functions
    try:
        saveobj = fm.save(label, mimetype, filetype)
        # we will upload file in 16K chunks
        chunk = fd.read(2 ** 14)
        while chunk:
            saveobj.upload(chunk)
            chunk = fd.read(2 ** 14)
        fd.close()
        id = saveobj.finalize_upload()
    except ccReg.FileManager.InternalError, e:
        sys.stderr.write("Internal error on server: %s.\n" % e.message)
        sys.exit(10)
    except Exception, e:
        sys.stderr.write("Corba call failed: %s.\n" % e)
        sys.exit(3)
    if silent:
        print id
    else:
        print "File was successfully saved and has id %d." % id

def loadfile(fm, id, output, silent):
    """
    Get file from filemanager.
    """
    #
    # Call filemanager's functions
    try:
        loadobj = fm.load(id)
        f = open(output, "wb")
        data = loadobj.download(2 ** 14)
        while data:
            f.write(data)
            data = loadobj.download(2 ** 14)
        f.close()
        loadobj.finalize_download()

    except ccReg.FileManager.InternalError, e:
        sys.stderr.write("Internal error on server: %s\n" % e.message)
        sys.exit(10)
    except ccReg.FileManager.IdNotFound, e:
        sys.stderr.write("Id '%d' is not in database.\n" % id)
        sys.exit(13)
    except ccReg.FileManager.FileNotFound, e:
        sys.stderr.write("File described by id %d is missing.\n" % id)
        sys.exit(14)
    except Exception, e:
        sys.stderr.write("Corba call failed: %s\n" % e)
        sys.exit(3)
    if silent:
        print output
    else:
        print "File was successfully loaded and saved under name '%s'." % output


def run_filemanager_client():
    try:
        opts, args = getopt.getopt(sys.argv[1:],
                "f:hi:l:n:c:m:o:st:x:",
                ["file=", "help", "input=", "label=", "nameservice=",
                 "context=", "mimetype=", "output=", "silent", "type=", "id="])
    except getopt.GetoptError:
        usage()
        sys.exit(1)

    configfile = '/etc/fred/pyfred.conf'

    for o, a in opts:
        if o in ('-f', '--file'):
            configfile = a

    conf = ConfigParser.SafeConfigParser({
        'nameservice':'localhost',
        'context':'fred',
        })
    conf.read(configfile)

    input = ""
    nameservice = conf.get('General', 'nshost')
    if conf.has_option('General', 'nsport'):
        nameservice = nameservice + ":" + conf.get("General", 'nsport')
    context = conf.get('General', 'context')
    mimetype = ""
    output = ""
    filetype = 0
    label = ""
    silent = False
    id = 0
    for o, a in opts:
        if o in ("-h", "--help"):
            usage()
            sys.exit()
        elif o in ("-i", "--input"):
            input = a
        elif o in ("-l", "--label"):
            label = a
        elif o in ("-n", "--nameservice"):
            nameservice = a
        elif o in ('-c', '--context'):
            context = a
        elif o in ("-m", "--mimetype"):
            mimetype = a
        elif o in ("-o", "--output"):
            output = a
        elif o in ("-s", "--silent"):
            silent = True
        elif o in ("-t", "--type"):
            filetype = int(a)
        elif o in ("-x", "--id"):
            id = int(a) # string ID
    # options check
    if input and output:
        sys.stderr.write("--input and --output options cannot be both "
                "specified.\n")
        usage()
        sys.exit(1)
    if not (input or output):
        # not input, not output and id = meta-info
        if not id:
            input = DEV_STDIN

    if not input and id == 0:
        # output or meta-info mode
        sys.stderr.write("ID must be specified.\n")
        usage()
        sys.exit(1)

    #
    # Initialise the ORB
    orb = CORBA.ORB_init(["-ORBnativeCharCodeSet", "UTF-8",
            "-ORBInitRef", "NameService=corbaname::" + nameservice],
            CORBA.ORB_ID)
    # Obtain a reference to the root naming context
    obj = orb.resolve_initial_references("NameService")
    rootContext = obj._narrow(CosNaming.NamingContext)
    if rootContext is None:
        sys.stderr.write("Failed to narrow the root naming context\n")
        sys.exit(2)
    # Resolve the name "fred.context/FileManager.Object"
    name = [CosNaming.NameComponent(context, "context"),
            CosNaming.NameComponent("FileManager", "Object")]
    try:
        obj = rootContext.resolve(name)
    except CosNaming.NamingContext.NotFound, e:
        sys.stderr.write("Could not get object's reference. Is object "
                "registered? (%s)\n" % e)
        sys.exit(2)
    # Narrow the object to an ccReg::FileManager
    filemanager_obj = obj._narrow(ccReg.FileManager)
    if (filemanager_obj is None):
        sys.stderr.write("Object reference is not a ccReg::FileManager\n")
        sys.exit(2)

    if not input and not output:
        getinfo(filemanager_obj, id)
    elif input:
        savefile(filemanager_obj, mimetype, filetype, input, label, silent)
    else:
        loadfile(filemanager_obj, id, output, silent)


if __name__ == "__main__":
    run_filemanager_client()
