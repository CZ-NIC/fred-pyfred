#!/usr/bin/env python
#
# Copyright (C) 2007-2018  CZ.NIC, z. s. p. o.
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
    0 if none of nameservers has recursive flag set in response.
    1 if any of nameservers has recursive flag set.
    2 if usage or other error occurs.

To stderr go debug and error messages and to stdout go space separated
nameservers which are recursive.
"""

import sys
import dns.resolver
import dns.message
import dns.query

default_domain = "neexistuje.v.domene.nic.cz"

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
    global default_domain

    if len(sys.argv) < 2:
        sys.stderr.write("Usage error")
        return 2
    domain = sys.stdin.read().strip().split(' ')[0] # try first domain only
    if not domain:
        domain = default_domain
    # list of faulty nameservers
    renegades = []
    error = False
    # process nameserver records
    for nsarg in sys.argv[1:]:
        # get ip addresses of nameserver
        (ns, addrs) = get_ns_addrs(nsarg)
        # create common query for all nameservers
        query = dns.message.make_query(domain, "SOA", use_edns=True)
        message = None
        for addr in addrs:
            try:
                message = dns.query.udp(query, addr, 3)
                break
            except dns.exception.Timeout, e:
                pass
        # did we got response for any of ip addresses of nameserver ?
        if not message:
            error = True
        elif message.flags & (2 ** (15 - 8)):
            renegades.append(ns)
    # epilog
    if renegades:
        for ns in renegades:
            sys.stdout.write("%s " % ns)
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
