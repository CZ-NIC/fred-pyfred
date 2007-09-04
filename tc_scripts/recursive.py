#!/usr/bin/env python
# vim:set ts=4 sw=4:

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

testdomain = "test-of-nameserver.cz"

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
	# create common query for all nameservers
	query = dns.message.make_query(testdomain, "SOA")
	# list of faulty nameservers
	renegades = []
	error = False
	# process nameserver records
	for nsarg in sys.argv[1:]:
		# get ip addresses of nameserver
		(ns, addrs) = get_ns_addrs(nsarg)
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
		elif message.flags & (2 ** (15-8)):
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
