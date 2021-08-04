#!/usr/bin/python2
#
# Copyright (C) 2007-2021  CZ.NIC, z. s. p. o.
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

import commands
import ConfigParser
import os
import signal
import sys
import time

# value of variables pidfile and pyfred_server are replaced by setup.py
# during install phase
pidfile = os.environ.get('PYFRED_PIDFILE', '/var/run/pyfred.pid')
pyfred_server = os.environ.get('PYFRED_BIN', 'fred-pyfred')

def usage():
    sys.stderr.write("Usage: pyfredctl [ start | stop | status ]\n")
    sys.stderr.write("\n")

def getpid(pidfile):
    """
    Read pid from pidfile.
    """
    try:
        fd = open(pidfile, "r")
    except Exception, e:
        return None

    pidline = fd.readline()
    fd.close()
    if pidline[-1] == '\n':
        return int(pidline[:-1])
    else:
        return int(pidline)

def isrunning(pid):
    """
    Return true if process with pid is running, otherwise false.
    """
    stat, output = commands.getstatusoutput("ps -p %d" % pid)
    if len(output.splitlines()) == 2:
        return True
    return False


def run_pyfredctl(argv=None):
    """
    The main.
    """
    global pidfile
    global pyfred_server

    argv = argv or sys.argv

    if len(argv) != 2:
        sys.stderr.write("Invalid parameter count\n")
        usage()
        sys.exit(2)
    command = argv[1]

    # assume default pid file location - this may not work always!
    pid = getpid(pidfile)

    if command == "start":
        if pid:
            if isrunning(pid):
                sys.stdout.write(pyfred_server + " is already running. Exiting.\n")
                sys.exit(1)
            sys.stdout.write("Found pidfile - perhaps unclean previous "
                    "shutdown?\n")
            os.unlink(pidfile)

        args = [pyfred_server]
        env = {}
        if 'PYTHONPATH' in os.environ:
            env['PYTHONPATH'] = os.environ['PYTHONPATH']
        if 'PYFRED_CONFIG' in os.environ:
            args.append(os.environ['PYFRED_CONFIG'])
        pid = os.spawnve(os.P_WAIT, pyfred_server, args, env)
        sys.stdout.write(pyfred_server + " was started\n")

    elif command == "stop":
        if not pid:
            sys.stdout.write(pyfred_server + " is not running. Exiting.\n")
            sys.exit(1)
        sys.stdout.write("Killing pid %d.\n" % pid)
        os.kill(pid, signal.SIGTERM)
        sys.stdout.write("Waiting 3 seconds for proces to terminate\n")
        time.sleep(3)
        if isrunning(pid):
            sys.stdout.write(pyfred_server + " doesn't want to exit\n")
            os.kill(pid, signal.SIGKILL)

    elif command == "status":
        if pid:
            sys.stdout.write(pyfred_server + " is running with pid %d.\n" % pid)
        else:
            sys.stdout.write(pyfred_server + " is not running.\n")

    else:
        sys.stderr.write("Invalid command specified\n")
        usage()
        sys.exit(2)

    sys.exit()


if __name__ == "__main__":
    run_pyfredctl(sys.argv)
