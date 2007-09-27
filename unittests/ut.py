#!/usr/bin/env python
#
# vim:ts=4 sw=4:

import commands, ConfigParser, sys, getopt, os, re, random
import pgdb
import unittest

# Random salt which is part of name of created objects in order to avoid
# safe period restriction
SALT = random.randint(1, 9999)
dbconn = None

def usage():
	print '%s [-v LEVEL | --verbose=LEVEL]' % sys.argv[0]

def epp_cmd_exec(cmd):
	'''
	Execute EPP command by fred_client.
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

def open_db_connection():
	'''
	Return db connection based on information in /etc/fred/pyfred.conf.
	'''
	global dbconn

	# read config of genzone client
	config = ConfigParser.ConfigParser()
	config.read('/etc/fred/genzone.conf')
	# read config of pyfred server
	dbhost = ''
	dbname = 'fred'
	dbport = '5432'
	dbuser = 'fred'
	dbpassword = ''
	config = ConfigParser.ConfigParser()
	config.read('/etc/fred/pyfred.conf')
	if config.has_option('General', 'dbhost'):
		dbhost = config.get('General', 'dbhost')
	if config.has_option('General', 'dbname'):
		dbname = config.get('General', 'dbname')
	if config.has_option('General', 'dbport'):
		dbport = config.get('General', 'dbport')
	if config.has_option('General', 'dbuser'):
		dbuser = config.get('General', 'dbuser')
	if config.has_option('General', 'dbpassword'):
		dbpassword = config.get('General', 'dbpassword')

	# create connection to database
	dbconn = pgdb.connect(host = dbhost +":"+ dbport, database = dbname,
			user = dbuser, password = dbpassword)

def get_zone_lines(greps):
	'''
	Generate zone and grep strings in 'greps' list.
	'''
	# generate zone
	(status, output) = commands.getstatusoutput(
			'genzone_client --nobackups --zonedir=/tmp cz')
	status = os.WEXITSTATUS(status) # translate status
	if status != 0:
		raise Exception('genzone_client error (status=%d): %s' %
				(status, output))
	# grep interesting lines
	cmdline = 'grep "\('
	for str in greps:
		cmdline = cmdline + str + '\|'
	cmdline = cmdline[:-1] + ')" /tmp/db.cz'
	(status, zonelines) = commands.getstatusoutput(cmdline)
	status = os.WEXITSTATUS(status) # translate status
	if status != 0:
		raise Exception('grep error (status=%d): %s' % (status, output))
	# delete generated zone file
	(status, output) = commands.getstatusoutput('rm -f /tmp/db.cz')
	status = os.WEXITSTATUS(status) # translate status
	if status != 0:
		raise Exception('rm error (status=%d): %s' % (status, output))
	# return result
	return [ line.strip() for line in zonelines.split('\n') ]


class SoaTest(unittest.TestCase):

	def setUp(self):
		# read config of genzone client
		config = ConfigParser.ConfigParser()
		config.read('/etc/fred/genzone.conf')
		if config.has_option('general', 'zones'):
			self.zones = config.get('general', 'zones').split()

	def runTest(self):
		'''
		Test for presence of SOA record.
		'''
		for zone in self.zones:
			(status,output) = commands.getstatusoutput('genzone_test %s' % zone)
			self.assertEqual(status, 0, 'Could not get SOA of %s zone' % zone)
			# status code is crucial, output test is just a safety-catch
			self.assert_((output == 'GENZONE OK'), 'genzone_test malfunction')


class BasicZoneTest(unittest.TestCase):
	'''
	This unittest generates zone and tests correct presence of newly inserted
	domain.
	'''

	def setUp(self):
		# generate zone
		self.zone_lines = get_zone_lines(['pfu-domain-%s.cz' % SALT,
				'ns.pfu-domain-%s.cz' % SALT, 'ns.pfu-domain-%s.net' % SALT])
		self.rr_lines = ''
		for line in self.zone_lines:
			self.rr_lines += line + '\n'

	def test_nameserver_rr(self):
		'''
		Test for presence of domain ns records in zone.
		'''
		# compile record patterns
		patt_ns1 = re.compile('pfu-domain-%s\.cz\.\s+IN\s+NS\s+'
				'ns\.pfu-domain-%s\.cz\.' % (SALT, SALT))
		patt_ns2 = re.compile('pfu-domain-%s\.cz\.\s+IN\s+NS\s+'
				'ns\.pfu-domain-%s\.net\.' % (SALT, SALT))
		# test presence of domain in zone
		found = False
		for line in self.zone_lines:
			if patt_ns1.match(line):
				found = True
				break
		self.assert_(found, 'Record for nameserver ns.pfu-domain-%s.cz not '
				'generated.\n%s' % (SALT, self.rr_lines))
		found = False
		for line in self.zone_lines:
			if patt_ns2.match(line):
				found = True
				break
		self.assert_(found, 'Record for nameserver ns.pfu-domain-%s.net not '
				'generated.\n%s' % (SALT, self.rr_lines))

	def test_glue_rr(self):
		'''
		Test for presence of GLUE (ipv4 and ipv6) records.
		'''
		# compile record patterns
		patt_glue4 = re.compile('ns\.pfu-domain-%s\.cz\.\s+IN\s+A\s+'
				'217\.31\.206\.129' % SALT)
		patt_glue6 = re.compile('ns\.pfu-domain-%s\.cz\.\s+IN\s+AAAA\s+'
				'2001:db8::1428:57ab' % SALT)
		# test GLUE record presence
		found = False
		for line in self.zone_lines:
			if patt_glue4.match(line):
				found = True
				break
		self.assert_(found, 'IPv4 GLUE record for nameserver '
				'ns.pfu-domain-%s.cz not generated.\n%s' % (SALT, self.rr_lines))
		found = False
		for line in self.zone_lines:
			if patt_glue6.match(line):
				found = True
				break
		self.assert_(found, 'IPv6 GLUE record for nameserver '
				'ns.pfu-domain-%s.cz not generated.\n%s' % (SALT, self.rr_lines))

class FaultyGlueTest(unittest.TestCase):

	def setUp(self):
		'''
		Move ip addresses from the ns which should have them to the ns which
		should not have them.
		'''
		global dbconn

		cur = dbconn.cursor()
		cur.execute("SELECT id FROM host WHERE fqdn = 'ns.pfu-domain-%s.cz'" % SALT)
		self.ns_cz_id = cur.fetchone()[0]
		cur.execute("SELECT id FROM host WHERE fqdn = 'ns.pfu-domain-%s.net'" % SALT)
		self.ns_net_id = cur.fetchone()[0]
		cur.execute("UPDATE host_ipaddr_map SET hostid = %d WHERE hostid = %d"
				% (self.ns_net_id, self.ns_cz_id))
		cur.close()
		dbconn.commit()

		# generate zone
		self.zone_lines = get_zone_lines(['pfu-domain-%s.cz' % SALT,
				'ns.pfu-domain-%s.cz' % SALT, 'ns.pfu-domain-%s.net' % SALT])
		self.rr_lines = ''
		for line in self.zone_lines:
			self.rr_lines += line + '\n'

	def tearDown(self):
		global dbconn

		cur = dbconn.cursor()
		cur.execute("UPDATE host_ipaddr_map SET hostid = %d WHERE hostid = %d"
				% (self.ns_cz_id, self.ns_net_id))
		cur.close()
		dbconn.commit()

	def test_missingGlue(self):
		'''
		In case when GLUE is missing, the nameserver should not be generated
		in zone.
		'''
		# compile record patterns
		patt_ns1 = re.compile('pfu-domain-%s\.cz\.\s+IN\s+NS\s+'
				'ns\.pfu-domain-%s\.cz\.' % (SALT, SALT))
		# test presence of domain delegation in zone
		for line in self.zone_lines:
			self.assert_(not patt_ns1.match(line),
					'Nameserver ns.pfu-domain-%s.cz with missing GLUE was '
					'generated.\n%s' % (SALT, self.rr_lines))

	def test_extraGlue(self):
		'''
		In case when there is extra GLUE, it should be ignored.
		'''
		patt_glue4 = re.compile('ns\.pfu-domain-%s\.net\.\s+IN\s+A\s+'
				'217\.31\.206\.129' % SALT)
		patt_glue6 = re.compile('ns\.pfu-domain-%s\.net\.\s+IN\s+AAAA\s+'
				'2001:db8::1428:57ab' % SALT)
		# test GLUE record presence
		for line in self.zone_lines:
			self.assert_(not patt_glue4.match(line),
					'Not needed glue for nameserver ns.pfu-domain-%s.net was '
					'generated.\n%s' % (SALT, self.rr_lines))
		for line in self.zone_lines:
			self.assert_(not patt_glue6.match(line),
					'Not needed glue for nameserver ns.pfu-domain-%s.net was '
					'generated.\n%s' % (SALT, self.rr_lines))



if __name__ == '__main__':
	try:
		(opts, args) = getopt.getopt(sys.argv[1:], 'v:', ['verbose='])
	except getopt.GetoptError:
		usage()
		sys.exit(2)

	level = 2 # default verbose level

	for o,a in opts:
		if o in ('-v', '--verbose'):
			level = int(a)

	genzone_zone_suite1 = unittest.TestLoader().loadTestsFromTestCase(BasicZoneTest)
	genzone_zone_suite2 = unittest.TestLoader().loadTestsFromTestCase(FaultyGlueTest)
	genzone_suite = unittest.TestSuite()
	genzone_suite.addTest(SoaTest())
	genzone_suite.addTest(genzone_zone_suite1)
	genzone_suite.addTest(genzone_zone_suite2)

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
	open_db_connection()

	# Run unittests
	unittest.TextTestRunner(verbosity = level).run(genzone_suite)

	# destroy test environment:
	#     delete object domain, nsset and contact
	epp_cmd_exec('delete_domain  pfu-domain-%s.cz' % SALT)
	epp_cmd_exec('delete_nsset   NSSID:PFU-NSSET-%s' % SALT)
	epp_cmd_exec('delete_contact CID:PFU-CONTACT-%s' % SALT)

	dbconn.close()
