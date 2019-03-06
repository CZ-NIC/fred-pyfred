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
    0 if none of query for domain, which is certainly not in zone maintained
      by nameserver, returns resolved address.
    1 if any of nameservers answers recursive query.
    2 if usage or other error occurs.

To stderr go debug and error messages and to stdout goes nameserver which
caused error or not fulfilled condition.
"""

import sys
import dns.resolver
import dns.message
import dns.query

debug = False
testdomain = "nikde-nic-ani-sic.ble"

def dbg_print(msg):
    """
Routine which outputs msg to stdout only if global debug is True, otherwise
does nothing.
    """
    if debug:
        sys.stderr.write(msg + '\n')

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
    global testdomain

    if len(sys.argv) < 2:
        sys.stderr.write("Usage error")
        return 2
    # create resolver object
    resolver = dns.resolver.Resolver()
    # create common query for all nameservers
    query = dns.message.make_query(testdomain, "A", use_edns=True)
    # list of faulty nameservers
    renegades = []
    # process nameserver records
    for nsarg in sys.argv[1:]:
        # get ip addresses of nameserver
        (ns, addrs) = get_ns_addrs(nsarg)
        message = None
        for addr in addrs:
            try:
                dbg_print("Query nameserver %s (%s) for A rr %s" %
                        (ns, addr, testdomain))
                message = dns.query.udp(query, addr, 3)
                break
            except dns.exception.Timeout, e:
                # timeout means that it is good - some nameservers do not
                # send answers for domain which are not delegated on them
                break
        # if there is any answer it means that recursive query was done
        if message and message.rcode() == dns.rcode.NXDOMAIN:
            dbg_print("Answer with result received")
            renegades.append(ns)
    # epilog
    if renegades:
        for ns in renegades:
            sys.stdout.write("%s " % ns)
        return 1
    return 0

if __name__ == "__main__":
    try:
        ret = main()
    # catch all clause
    except Exception, e:
        sys.stderr.write(e.__str__())
        sys.exit(2)
    sys.exit(ret)
