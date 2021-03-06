#!/usr/bin/python2
#
# Copyright (C) 2008-2019  CZ.NIC, z. s. p. o.
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
Code of techcheck daemon.
"""
import dns.message
import dns.resolver


def countKeyTag(k):
    """
    Count keytag from RRdata of DNSKEY RR according to appendix B of RFC 4034
    """
    sum = k.flags + (k.protocol << 8) + k.algorithm
    for i in range(0, len(k.key)):
        if (i & 1):
            sum += ord(k.key[i])
        else:
            sum += ord(k.key[i]) << 8
    sum += (sum >> 16) & 0xFFFF
    return sum & 0xFFFF

def getAllKeys(domain, ip):
    msg_q = dns.message.make_query(domain, "DNSKEY")
    msg_r = dns.query.tcp(msg_q, ip, 3)
    return msg_r.answer[0]
