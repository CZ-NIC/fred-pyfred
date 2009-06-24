#!/usr/bin/env python

import sys
import subprocess

DEBUG = True
DFILE = open('dnssec_test_debug.log', 'a')

def debug(msg, newline=None):
    if newline == None:
        newline = True

    global DEBUG, DFILE
    if DEBUG:
        if newline:
            msg += '\n'
        #sys.stderr.write(msg)
        DFILE.write(msg)


def main():
    if len(sys.argv) < 2:
        sys.stderr.write('Usage error')
        return 2

    domains = sys.stdin.read().strip().split(' ')
    debug('domains: ' + str(domains))
    debug('args: ' + str(sys.argv[1:0]))

    failed = []

    for domain in domains:
        debug('Checking domain name %s ... ' % domain, False)
        # will check only SOA record signature - because some domains are in zone
        # and do not have any A record
        command = '/usr/local/bin/drill -S %s SOA -k /etc/trusted-key.key' % domain
        child = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE)
        child.wait()

        output = child.communicate()[0]
        if output.find('Existence is denied by') != -1 or child.returncode != 0:
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
        ret = main()

    except Exception, e:
        sys.stderr.write(str(e))
        sys.exit(2)

    sys.exit(ret)

