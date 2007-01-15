#!/usr/bin/env python
# vim:set ts=4 sw=4:

"""
This script returns:
	0 if none of nameservers has recursive flag set in response.
	1 if any of nameservers has recursive flag set.
	2 if usage or other error occurs.

To stderr go debug and error messages and to stdout goes nameserver which
caused error or not fulfilled condition.
"""

import sys
import dns.resolver
import dns.message
import dns.query

testdomain = "test-of-nameserver.cz"

def main():
	if len(sys.argv) < 2:
		sys.stderr.write("Usage error")
		return 2
	# create resolver object
	resolver = dns.resolver.Resolver()
	# create common query for all nameservers
	query = dns.message.make_query(testdomain, "SOA")
	# process nameserver records
	for nsarg in sys.argv[1:]:
		ns = nsarg.split(',')[0]
		# get ip addresses of nameserver
		answer = dns.resolver.query(ns)
		message = None
		for rr in answer:
			try:
				message = dns.query.udp(query, rr.__str__(), 3)
				break
			except dns.exception.Timeout, e:
				pass
		# did we got response for any of ip addresses of nameserver ?
		if not message:
			sys.stdout.write(ns)
			return 2
		if message.flags & (2 ** (15-8)):
			sys.stdout.write(ns)
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
