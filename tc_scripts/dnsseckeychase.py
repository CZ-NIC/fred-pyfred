#!/usr/bin/python2
#
# Copyright (C) 2009-2019  CZ.NIC, z. s. p. o.
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

"""
DNSSEC key chain of trust technical test
"""
import os
import subprocess
import sys

DEBUG = False

def debug(msg, newline=None):
    """
    debug messages, turn off on production usage
    """
    if newline == None:
        newline = True

    if DEBUG:
        if newline:
            msg += '\n'
        sys.stderr.write(msg)


def get_trustedkey_zone(filename):
    """
    get zone name for key in filename
    """
    try:
        file = open(filename, "r")
        lines = file.readlines()
        for line in lines:
            if line:
                zone = "." + line.split()[0].rstrip(".")
                return zone
    except:
        pass
    return


def main():
    """
    dnssec key chain of trust test procedure
    return values:
        0 if all domain names pass the test
        1 if any domain name fails
        2 if any other error occurs
    """
    if len(sys.argv) < 3:
        sys.stderr.write('Usage error')
        return 2

    drill = sys.argv[-2]
    trusted_key = sys.argv[-1]
    debug("drill: " + str(drill))
    debug("trusted key: " + str(trusted_key))
    # test at least existance and executability
    if not (os.path.exists(drill) or os.access(drill, os.X_OK)):
        sys.stderr.write("Usage error (wrong argument: drill); test aborted\n")
        return 2
    if not os.path.exists(trusted_key):
        sys.stderr.write("Usage error (wrong argument: trusted key); test aborted\n")
        return 2

    # get zone for trusted key for filtering stding
    zone = get_trustedkey_zone(trusted_key)
    if not zone:
        sys.stderr.write("Usage error (wrong trusted key file content '%s'); "
                "test aborted\n" % trusted_key)
        return 2

    domains = sys.stdin.read().strip().split(' ')
    failed = []

    for domain in domains:
        if zone != '.' and not domain.endswith(zone):
            continue

        debug('Checking domain name %s ... ' % domain, False)
        # will check only SOA record signature - because some domains
        # are in zone and do not have any A record
        command = '%s -k %s -S %s SOA' % (drill, trusted_key, domain)
        child = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE)
        child.wait()

        output = child.communicate()[0]
        if output.find('Existence is denied by') != -1 \
                or output.find('Bogus DNSSEC signature') != -1 \
                or child.returncode != 0:
            failed.append(domain)
            debug('FAIL')
            debug(output)

        elif child.returncode == 0:
            debug('OK')

        else:
            debug('UNKNOWN OUTPUT')
            debug(output)

    if failed:
        for domain in failed:
            sys.stdout.write('%s ' % domain)
        return 1

    return 0


if __name__ == '__main__':
    try:
        RET_VAL = main()
    except Exception, e:
        sys.stderr.write(str(e))
        sys.exit(2)

    sys.exit(RET_VAL)
