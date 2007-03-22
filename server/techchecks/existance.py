#!/usr/bin/env python
# vim:set ts=4 sw=4:

"""
This script returns:
	0 if all nameservers exist.
	1 if any of nameservers does not exist.
	2 if usage or other error occurs.

To stderr go error messages and to stdout go space separated fqdns of
nameservers which do not exist.
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
	# create common query for all nameservers (we don't care about type of query)
	query = dns.message.make_query(testdomain, "ANY")
	# list of faulty nameservers
	renegades = []
	# process nameserver records
	for nsarg in sys.argv[1:]:
		ns = nsarg.split(',')[0]
		# get ip addresses of nameserver
		try:
			answer = dns.resolver.query(ns)
		except dns.resolver.NXDOMAIN, e:
			renegades.append(ns)
			continue
		# query nameserver
		message = None
		for rr in answer:
			try:
				message = dns.query.udp(query, rr.__str__(), 3)
				break
			except dns.exception.Timeout, e:
				pass
		# did we got response for any of ip addresses of nameserver ?
		if not message:
			renegades.append(ns)
	# print faulty nameservers to stdout if there are any
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
