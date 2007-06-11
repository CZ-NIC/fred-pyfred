#!/usr/bin/env python
# vim:set ts=4 sw=4:

"""
This script returns:
	0 if at least two nameservers are in autonomous systems,
	1 if the previous condition does not hold,
	2 if usage or other error occurs.

To stderr go debug and error messages, to stdout goes nothing.

Autonomous system
    is synonymum for routing domain. The purpose of this test is to ensure,
that if a routing domain including nameserver goes down, another nameserver
can still be reached.
"""

import sys, commands, re
import dns.resolver

debug = False
whoisbin = "whois"

def dbg_print(msg):
	"""
Routine which outputs msg to stdout only if global debug is True, otherwise
does nothing.
	"""
	if debug:
		sys.stderr.write(msg + '\n')

def whois_AS(ip):
	"""
Performs basic whois query on ip address and returns Autonomous system of that
ip address.
	"""
	status, output = commands.getstatusoutput("%s %s" % (whoisbin, ip))
	if status != 0:
		raise Exception("whois program failed (rc=%d)" % status)
	pattern = re.compile(r"^origin:\s*(\S+)$", re.M)
	asys = pattern.search(output)
	# if pattern was not found
	if not asys:
		return None
	return asys.groups()[0]

def main():
	if len(sys.argv) < 2:
		sys.stderr.write("Usage error")
		return 2
	# create resolver object
	resolver = dns.resolver.Resolver()
	# autonomous systems of first nameserver
	as_first = None
	# process nameserver records
	for nsarg in sys.argv[1:]:
		ns = nsarg.split(',')[0]
		# get ip addresses of nameserver
		dbg_print("Resolving nameserver %s" % ns)
		answer = resolver.query(ns)
		# get AS from whois
		for rr in answer:
			dbg_print("Whois on ip address %s" % rr)
			as_curr = whois_AS(rr.__str__())
			# if it is not RIPE, we cannot say anything about autonomity,
			#    we will return success therefore
			if not as_curr:
				dbg_print("Autonomous system is not known")
				return 0
			dbg_print("IP %s is from autonomous system %s" % (rr, as_curr))
			# if it is first entry, then put it in as_base ...
			if not as_first:
				as_first = as_curr
			# ... otherwise if it is from different routing domain return passed
			elif as_curr != as_first:
				dbg_print("Two different autonomous systems found")
				return 0
	# no two different routing domains were found
	dbg_print("All nameservers are from the same autonomous system")
	return 1


if __name__ == "__main__":
	try:
		ret = main()
	# catch all clause
	except Exception, e:
		sys.stderr.write(e.__str__())
		sys.exit(2)
	sys.exit(ret)
