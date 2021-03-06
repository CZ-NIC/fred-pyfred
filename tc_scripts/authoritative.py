#!/usr/bin/python2
#
# Copyright (C) 2007-2019  CZ.NIC, z. s. p. o.
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
This script returns:
    0 if all nameservers give authoritative answer.
    1 if any of nameservers does not give authoritative answer.
    2 if usage or other error occurs.

To stderr go error messages and to stdout go nameservers and domains which
caused a failure. From stdin is read a list of domains for which
the nameserver is tested for authoritativity.
"""
import sys

import dns.message
import dns.query
import dns.resolver


def get_ns_addrs(args):
    """
    BEWARE!!! If you change something in this function, don't forget to
    change copies of it in all other tests.
    """
    ns = args.split(',')[0]
    addrs = args.split(',')[1:]
    if not addrs:
        # get ip addresses of nameserver
        answer = dns.resolver.query(ns)
        for rr in answer:
            addrs.append(rr.__str__())
    return (ns, addrs)

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Usage error")
        return 2
    # get list of domains from stdin
    domains = sys.stdin.read().strip().split(' ')
    # dictionary of renegades
    renegades = {}
    error = False
    # process nameserver records
    for nsarg in sys.argv[1:]:
        # get ip addresses of nameserver
        (ns, addrs) = get_ns_addrs(nsarg)
        # iterate through all domains
        for domain in domains:
            # create query
            query = dns.message.make_query(domain, "SOA", use_edns=True)
            message = None
            for addr in addrs:
                try:
                    message = dns.query.udp(query, addr, 3)
                    break
                except dns.exception.Timeout, e:
                    pass
            # did we got response for any of ip addresses of nameserver ?
            if not message or not message.answer:
                error = True
            elif not (message.flags & (2 ** (15 - 5))):
                if not renegades.has_key(ns):
                    renegades[ns] = []
                renegades[ns].append(domain)
    if renegades:
        for ns in renegades:
            domain_list = renegades[ns]
            sys.stdout.write(ns)
            for fqdn in domain_list:
                sys.stdout.write(",%s" % fqdn)
            sys.stdout.write(" ")
        return 1
    if error:
        return 2
    return 0

if __name__ == "__main__":
    try:
        ret = main()
    # catch all clause
    except Exception, e:
        sys.stderr.write(e.__str__())
        sys.exit(2)
    sys.exit(ret)
