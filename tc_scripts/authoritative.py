#!/usr/bin/env python
# vim:set ts=4 sw=4:

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
	# dictionary of renegades
	renegades = {}
	error = False
	# process nameserver records
	for nsarg in sys.argv[1:]:
		ns = nsarg.split(',')[0]
		renegades[ns] = []
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
				error = True
			elif not ( message.flags & (2 ** (15-5)) ):
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
