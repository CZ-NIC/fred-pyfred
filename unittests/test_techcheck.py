#!/usr/bin/env python
#
# vim:ts=4 sw=4:

'''
This file tests techcheck component of pyfred server.

Here is a hierarchy of test suites and test cases:

techcheck_suite
	|-- DigFlag
	|-- Glue_existance
	|-- Presence
	|-- Authoritative
	|-- Recursive_4all
	|-- Autonomous
	|-- Heterogenous

See comments in appropriate classes and methods for more information
about their operation. General description follows. For inserting, altering
and deleting test data from central register we use to interfaces:
epp_client (communicates through EPP protocol) and techcheck_client program.
The changes made by this unittest are not reversible! Because the EPP
operations remain in a history and may influence result of some operations in
future. So it must be run on test instance of central register. The tests
are specific for '.cz' zone and won't work with other zones.
'''

import commands, ConfigParser, sys, getopt, os, re, random
import pgdb
import unittest

# Random salt which is part of name of created objects in order to avoid
# safe period restriction.
SALT = random.randint(1, 9999)

def usage():
	print '%s [-v LEVEL | --verbose=LEVEL]' % sys.argv[0]
	print
	print 'verbose level number is handed over to unittest function as it is.'
	print

def epp_cmd_exec(cmd):
	'''
	Execute EPP command by fred_client. XML validation is turned off.
	The EPP response must have return code 1000, otherwise exception is
	raised.
	'''
	(status, output) = commands.getstatusoutput('fred_client -xd \'%s\'' % cmd)
	status = os.WEXITSTATUS(status) # translate status
	if status != 0:
		raise Exception('fred_client error (status=%d): %s' % (status, output))
	pattern = re.compile('^Return code:\s+(\d+)$', re.MULTILINE)
	m = pattern.search(output)
	rcode = 0
	if m:
		rcode = int(m.groups()[0])
	if rcode == 0:
		raise Exception('Return code of EPP command not matched\n%s' % output)
	if rcode != 1000:
		raise Exception('EPP command failure (code %d)\n%s' % (rcode, output))

class TechCheck(object):
	def __init__(self, str):
		self.tests = {}
		p_name = re.compile('^Test\'s name:\s+(\w+)$', re.MULTILINE)
		p_status = re.compile('^\s+Status:\s+(\w+)$', re.MULTILINE)
		m_name = p_name.search(str)
		m_status = p_status.search(str)
		if not m_name or not m_status:
			return
		names = m_name.groups()
		statuses = m_status.groups()
		for i in range(len(names)):
			self.tests[names[i]] = statuses[i]

def techcheck_exec(nsset, level=0, dig=True, extra=None):
	'''
	Execute technical check by techcheck_client and return object representing
	results of the test.
	'''
	options = ''
	if dig:
		options += ' --dig'
	options += ' --level=%d' % level
	if extra:
		options += ' --fqdn="%s"' % extra
	(status, output) = commands.getstatusoutput('techcheck_client %s %s' %
			(options, nsset))
	status = os.WEXITSTATUS(status) # translate status
	if status != 0:
		raise Exception('techcheck_client error (status=%d): %s' %
				(status, output))
	return TechCheck(output)


class DigFlag(unittest.TestCase):
	'''
	This is a simple test case, which tests functionality of dig flag.
	If dig flag is turned on, the domains bound to nsset are tested as well
	as possible extra domain names. If dig flag is turned off, the domains
	bound to nameserver are not taken into account.
	'''

	def runTest(self):
		res = techcheck_exec('NSSID:PFU-NSSET-%s' % SALT, 1, True)
		self.assertEqual(len(res.tests), 2, 'Flag dig not working')
		res = techcheck_exec('NSSID:PFU-NSSET-%s' % SALT, 1, False)
		self.assertEqual(len(res.tests), 0, 'Flag dig not working')
		#if test == 'existence':
		#self.assertEqual(res.tests[test], 'Failed', ''
		# status code is crucial, output test is just a safety-catch
		#self.assert_((output == 'GENZONE OK'), 'genzone_test malfunction')



if __name__ == '__main__':
	# parse command line parameters
	try:
		(opts, args) = getopt.getopt(sys.argv[1:], 'v:', ['verbose='])
	except getopt.GetoptError:
		usage()
		sys.exit(2)
	level = 2 # default verbose level
	for o,a in opts:
		if o in ('-v', '--verbose'):
			level = int(a)
	# put together test suite
	#zone_suite1 = unittest.TestLoader().loadTestsFromTestCase(DelegationTest)
	genzone_suite = unittest.TestSuite()
	genzone_suite.addTest(DigFlag())

	# create test environment:
	#     create object contact, nsset, domain
	epp_cmd_exec('create_contact CID:PFU-CONTACT-%s '
			'"Jan Ban" info@mail.com Street Brno 123000 CZ' % SALT)
	epp_cmd_exec('create_nsset NSSID:PFU-NSSET-%s '
			'((ns.pfu-domain-%s.cz (217.31.206.129, 2001:db8::1428:57ab)),'
			'(ns.pfu-domain-%s.net)) CID:PFU-CONTACT-%s' %
			(SALT, SALT, SALT, SALT))
	epp_cmd_exec('create_domain pfu-domain-%s.cz '
			'CID:PFU-CONTACT-%s nsset=NSSID:PFU-NSSET-%s' %
			(SALT, SALT, SALT))

	# Run unittests
	unittest.TextTestRunner(verbosity = level).run(genzone_suite)

	# destroy test environment:
	#     delete object domain, nsset and contact
	epp_cmd_exec('delete_domain  pfu-domain-%s.cz' % SALT)
	epp_cmd_exec('delete_nsset   NSSID:PFU-NSSET-%s' % SALT)
	epp_cmd_exec('delete_contact CID:PFU-CONTACT-%s' % SALT)
