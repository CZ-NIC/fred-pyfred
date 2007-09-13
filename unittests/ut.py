#!/usr/bin/env python
#
# vim:ts=4 sw=4:

import commands, ConfigParser, sys, getopt
import pgdb
import unittest

def usage():
	print '%s [-v LEVEL | --verbose=LEVEL]' % sys.argv[0]

class TestGenzone(unittest.TestCase):

	def setUp(self):
		# read config of genzone client
		config = ConfigParser.ConfigParser()
		config.read('/etc/fred/genzone.conf')
		if config.has_option('general', 'zones'):
			self.zones = config.get('general', 'zones').split()
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
		# connect to database
		self.conn = pgdb.connect(host = dbhost +":"+ dbport, database = dbname,
				user = dbuser, password = dbpassword)
		#
		# get data needed to create test instance
		#
		self.dbdata = {}
		dbd = self.dbdata
		cur = self.conn.cursor()
		cur.execute("SELECT id FROM registrar WHERE handle = 'REG-UNITTEST1'")
		if cur.rowcount != 1:
			raise Exception('REG-UNITTEST1 registrar does not exist')
		dbd['registrar_id'] = cur.fetchone()[0]
		cur.execute("SELECT id FROM zone WHERE fqdn = 'cz'")
		if cur.rowcount != 1:
			raise Exception('Zone cz does not exist')
		dbd['zone_id'] = cur.fetchone()[0]
		cur.execute("SELECT nextval('object_registry_id_seq')")
		dbd['registrant_id'] = cur.fetchone()[0]
		cur.execute("SELECT nextval('object_registry_id_seq')")
		dbd['nsset_id'] = cur.fetchone()[0]
		cur.execute("SELECT nextval('object_registry_id_seq')")
		dbd['domain_id'] = cur.fetchone()[0]
		cur.execute("SELECT nextval('host_id_seq')")
		dbd['ns1_id'] = cur.fetchone()[0]
		cur.execute("SELECT nextval('host_id_seq')")
		dbd['ns2_id'] = cur.fetchone()[0]
		cur.execute("SELECT nextval('host_ipaddr_map_id_seq')")
		dbd['ip4addr_id'] = cur.fetchone()[0]
		cur.execute("SELECT nextval('host_ipaddr_map_id_seq')")
		dbd['ip6addr_id'] = cur.fetchone()[0]
		cur.execute("SELECT nextval('history_id_seq')")
		dbd['domain_history_id'] = cur.fetchone()[0]
		cur.execute("SELECT nextval('history_id_seq')")
		dbd['registrant_history_id'] = cur.fetchone()[0]
		cur.execute("SELECT nextval('history_id_seq')")
		dbd['nsset_history_id'] = cur.fetchone()[0]
		cur.execute("SELECT nextval('history_id_seq')")
		dbd['domain_history_id'] = cur.fetchone()[0]
		#
		# pour test data in db
		#
		# create object registrant
		cur.execute(
"INSERT INTO object_registry (id, roid, type, name, crid,crhistoryid,historyid)"
"   VALUES (%d, 'pyfredut-registrant', 1, 'PYFRED-UT-REGISTRANT', %d, %d, %d)" %
(dbd['registrant_id'], dbd['registrar_id'], dbd['registrant_history_id'],
	dbd['registrant_history_id']))
		cur.execute(
"INSERT INTO object (id, clid, authinfopw) VALUES (%d, %d, 'blabla')" %
(dbd['registrant_id'], dbd['registrar_id']))
		cur.execute(
"INSERT INTO contact (id, name, street1, city, postalcode, country, email)"
"   VALUES (%d, 'ut-registrant', 'Aha 12', 'Prd', '40011', 'CZ', 'ut@nic.cz')" %
(dbd['registrant_id']));
		# create object nsset
		cur.execute(
"INSERT INTO object_registry (id, roid, type, name, crid,crhistoryid,historyid)"
"   VALUES (%d, 'pyfredut-nsset', 2, 'PYFRED-UT-NSSET', %d, %d, %d)" %
(dbd['nsset_id'], dbd['registrar_id'], dbd['nsset_history_id'],
	dbd['nsset_history_id']))
		cur.execute(
"INSERT INTO object (id, clid, authinfopw) VALUES (%d, %d, 'blabla')" %
(dbd['nsset_id'], dbd['registrar_id']))
		cur.execute("INSERT INTO nsset (id) VALUES (%d)" % (nsset_id))
		cur.execute(
"INSERT INTO host (id, nssetid, fqdn) VALUES (%d, %d, 'ns1.unittest.com')" %
(dbd['ns1_id'], dbd['nsset_id']))
		cur.execute(
"INSERT INTO host (id, nssetid, fqdn) VALUES (%d, %d, 'ns2.unittest.cz')" %
(dbd['ns2_id'], dbd['nsset_id']))
		cur.execute(
"INSERT INTO host_ipaddr_map (id, hostid, nssetid, ipaddr)"
"VALUES (%d, %d, %d, '192.168.0.1')" %
(dbd['ip4addr_id'], dbd['ns2_id'], dbd['nsset_id']))
		cur.execute(
"INSERT INTO host_ipaddr_map (id, hostid, nssetid, ipaddr)"
"VALUES (%d, %d, %d, '2001:0db8:3c4d:0015:0000:0000:abcd:ef12')" %
(dbd['ip6addr_id'], dbd['ns2_id'], dbd['nsset_id']))
		# create object domain
		cur.execute(
"INSERT INTO object_registry (id, roid, type, name, crid,crhistoryid,historyid)"
"   VALUES (%d, 'unittest.cz', 2, 'PYFRED-UT-DOMAIN', %d, %d, %d)" %
(dbd['domain_id'], dbd['registrar_id'], dbd['domain_history_id'],
	dbd['domain_history_id']))
		cur.execute(
"INSERT INTO object (id, clid, authinfopw) VALUES (%d, %d, 'blabla')" %
(dbd['domain_id'], dbd['registrar_id']))
		cur.execute(
"INSERT INTO domain (id, zone, registrant, nsset, exdate) "
"VALUES (%d, %d, %d, %d, now() + interval '2 years')" %
(dbd['domain_id'], dbd['zone_id'], dbd['registrant_id'], dbd['nsset_id']))
		cur.close()
		self.conn.commit()

	def tearDown(self):
		#
		# remove test data from db
		#
		dbd = self.dbdata
		cur = self.conn.cursor()
		# clean up domain
		cur.execute("DELETE FROM domain WHERE id = %d" % bdb['domain_id'])
		cur.execute("DELETE FROM object WHERE id = %d" % bdb['domain_id'])
		cur.execute("DELETE FROM object_registry WHERE id = %d" % bdb['domain_id'])
		# clean up nsset
		cur.execute("DELETE FROM host_ipaddr_map WHERE id = %d" % bdb['ip6addr_id'])
		cur.execute("DELETE FROM host_ipaddr_map WHERE id = %d" % bdb['ip4addr_id'])
		cur.execute("DELETE FROM host WHERE id = %d" % bdb['ns2_id'])
		cur.execute("DELETE FROM host WHERE id = %d" % bdb['ns1_id'])
		cur.execute("DELETE FROM nsset WHERE id = %d" % bdb['nsset_id'])
		cur.execute("DELETE FROM object WHERE id = %d" % bdb['nsset_id'])
		cur.execute("DELETE FROM object_registry WHERE id = %d" % bdb['nsset_id'])
		# clean up contact
		cur.execute("DELETE FROM contact WHERE id = %d" % bdb['registrant_id'])
		cur.execute("DELETE FROM object WHERE id = %d" % bdb['registrant_id'])
		cur.execute("DELETE FROM object_registry WHERE id = %d" % bdb['registrant_id'])
		cur.close()
		self.conn.commit()
		self.conn.close()

	def testsoa(self):
		'''
		Test for presence of SOA record.
		'''
		for zone in self.zones:
			(status,output) = commands.getstatusoutput('genzone_test %s' % zone)
			self.assertEqual(status, 0, 'Could not get SOA of %s zone' % zone)
			# status code is crucial, output test is just a safety-catch
			self.assert_((output == 'GENZONE OK'), 'genzone_test malfunction')


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

	suite = unittest.TestLoader().loadTestsFromTestCase(TestGenzone)
	unittest.TextTestRunner(verbosity = level).run(suite)

