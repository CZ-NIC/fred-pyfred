#!/usr/bin/env python
# vim:ts=4 sw=4:
import pgdb

def main():
	conn = pgdb.connect(host = 'curlew', database = 'ccreg', user = 'ccreg')
	cur = conn.cursor()
	print 'Vypis sablon pro mailer'
	print 'Oddelovac zprav je radek ze znaku "*"'
	cur.execute('SELECT id, name, subject FROM mail_type')
	for row in cur.fetchall():
		(id, name, subject) = row
		print '*' * 80
		print
		print 'Identifikator emailu: %s' % name
		print '---------------------'
		print 'Subject emailu: %s' % subject
		print '---------------'
		print 'Sablona emailu:'
		print '---------------'
		cur.execute('SELECT template '
				'FROM mail_templates mt, mail_type_template_map mttm '
				'WHERE mt.id = mttm.templateid AND mttm.typeid = %d' % id)
		for templ in cur.fetchall():
			print templ[0]
		print '*' * 80
	cur.close()
	conn.close()

if __name__ == '__main__':
	main()
