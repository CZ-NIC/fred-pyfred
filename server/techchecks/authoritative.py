#!/usr/bin/env python
# vim:set ts=4 sw=4:

"""
This script returns:
	0 if all nameservers give authoritative answer.
	1 if any of nameservers does not give authoritative answer.
	2 if usage or other error occurs.

To stderr go error messages and to stdout goes nameserver and domain which
caused a failure or error. From stdin is read a list of domains for which
the nameserver is tested for authoritativity.
"""

import sys
import dns.resolver
import dns.message
import dns.query


def main():
	if len(sys.argv) < 2:
		sys.stderr.write("Usage error")
		return 2
	# get list of domains from stdin
	domains = sys.stdin.read().strip().split(' ')
	# create resolver object
	resolver = dns.resolver.Resolver()
	# process nameserver records
	for nsarg in sys.argv[1:]:
		ns = nsarg.split(',')[0]
		# get ip addresses of nameserver
		ipaddrs = dns.resolver.query(ns)
		# iterate through all domains
		for domain in domains:
			# create query
			query = dns.message.make_query(domain, "SOA")
			message = None
			for rr in ipaddrs:
				try:
					message = dns.query.udp(query, rr.__str__(), 3)
					break
				except dns.exception.Timeout, e:
					pass
			# did we got response for any of ip addresses of nameserver ?
			if not message or not message.answer:
				sys.stdout.write("%s:%s " % (ns, domain))
				return 2
			if not ( message.flags & (2 ** (15-5)) ):
				sys.stdout.write("%s:%s " % (ns, domain))
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
