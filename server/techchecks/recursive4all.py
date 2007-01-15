#!/usr/bin/env python
# vim:set ts=4 sw=4:

"""
This script returns:
	0 if none of query for domain which 
	1 if any of nameservers has recursive flag set.
	2 if usage or other error occurs.

To stderr go debug and error messages and to stdout goes nameserver which
caused error or not fulfilled condition.
"""

import sys
import dns.resolver
import dns.message
import dns.query

debug = True
testdomain = "enum.nic.cz"

def dbg_print(msg):
	"""
Routine which outputs msg to stdout only if global debug is True, otherwise
does nothing.
	"""
	if debug:
		sys.stderr.write(msg + '\n')

def main():
	if len(sys.argv) < 2:
		sys.stderr.write("Usage error")
		return 2
	# create resolver object
	resolver = dns.resolver.Resolver()
	# create common query for all nameservers
	query = dns.message.make_query(testdomain, "A")
	# process nameserver records
	for nsarg in sys.argv[1:]:
		ns = nsarg.split(',')[0]
		# get ip addresses of nameserver
		answer = dns.resolver.query(ns)
		message = None
		for rr in answer:
			try:
				dbg_print("Query nameserver %s (%s) for A rr %s" %
						(ns, rr, testdomain))
				message = dns.query.udp(query, rr.__str__(), 3)
				break
			except dns.exception.Timeout, e:
				pass
		# did we got response for any of ip addresses of nameserver ?
		if not message:
			sys.stdout.write(ns)
			return 2
		# if there is any answer it means that recursive query was done
		if len(message.answer):
			dbg_print("Length of answer is non zero: %s" % message.answer)
			sys.stdout.write(ns)
			return 1
	# no nameserver gave recursive answer
	return 0

if __name__ == "__main__":
	try:
		ret = main()
	# catch all clause
	except Exception, e:
		sys.stderr.write(e.__str__())
		sys.exit(2)
	sys.exit(ret)
