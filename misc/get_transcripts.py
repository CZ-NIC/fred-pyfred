#!/usr/bin/env python
#
# vim: set ts=4 sw=4:

import sys, getopt, imaplib, tempfile, commands, os
from email.FeedParser import FeedParser

IMAPUSER = 'jan.kryl@nic.cz'
IMAPPASS = 'maey3Po8'
IMAPHOST = 'mail.nic.cz'
FROM1    = 'jan.kryl@nic.cz'
FROM2    = 'jaromir.talir@nic.cz'
FM_CMD   = 'filemanager_client'
NSHOST   = 'curlew.office.nic.cz'

verbose = False

def usage():
	print '%s [-H imaphost] [-n nameservice] [-p imappassword] [-u imapuser] [-v]' % sys.argv[0]

def debug(msg):
	global verbose

	if verbose:
		sys.stderr.write(msg + '\n')

def error(msg):
	sys.stderr.write('Exiting due to an error: %s\n' % msg)
	sys.exit(1)

def main():
	global verbose

	try:
		opts, args = getopt.getopt(sys.argv[1:], "h:p:u:v", [])
	except getopt.GetoptError:
		usage()
		sys.exit(2)

	imaphost = IMAPHOST
	imappass = IMAPPASS
	imapuser = IMAPUSER
	nshost   = NSHOST

	for o,a in opts:
		if o == '-h':
			imaphost = a
		elif o == '-n':
			nshost = a
		elif o == '-p':
			imappass = a
		elif o == '-u':
			imapuser = a
		elif o == '-v':
			verbose = True
		else:
			usage()
			sys.exit(2)

	server = imaplib.IMAP4(imaphost)
	debug('Connected to %s' % imaphost)
	server.login(imapuser, imappass)
	debug('Logged in as %s' % imapuser)
	server.select()
	r, data = server.search(None, '((UNSEEN) (OR FROM "%s" FROM "%s"))' %
			(FROM1, FROM2))
	msgids = data[0].replace(' ', ',')
	if not msgids:
		debug('No new messages in mailbox')
		sys.exit(0)
	r, data = server.fetch(msgids, '(RFC822)')
	# don't know why but we have to trim last message
	data = data[:-1]
	# since now, whatever bad happens, we must restore unseen flag
	# on downloaded messages
	try:
		debug('%d new messages' % len(data))
		for rawmsg in data:
			fp = FeedParser()
			fp.feed(rawmsg[1])
			mail = fp.close()
			# separate attachment in which we are interested
			if not mail.is_multipart():
				debug('Skipping email (it is not multipart)')
				continue
			# walk goes like this: whole message -> 1th part -> 2nd part
			i = 0
			for part in mail.walk():
				if i == 2: break
				i += 1
			if i != 2:
				debug('Skipping email (does not have 2nd part)')
				continue
			filename = part.get_filename()
			mimetype = part.get_content_type()
			octets = part.get_payload(decode = True)
			debug('filename: %s' % filename)
			debug('mimetype: %s' % mimetype)
			debug('content:')
			debug(octets[:300] + ' ...')
			fd = tempfile.NamedTemporaryFile()
			fd.write(octets)
			# save the attachment via filemanager client
			cmd = '%s --input="%s" --label="%s" --mime="%s" --type=4 '\
					'--nameservice="%s"'\
					% (FM_CMD, fd.name, filename, mimetype, nshost)
			(status, output) = commands.getstatusoutput(cmd)
			if os.WEXITSTATUS(status) != 0:
				raise Exception('Error when executing command: %s\n%s' %
						(cmd, output))
			else:
				debug('Filemanager\'s output:')
				debug(output)
			# cut off successfully saved message from list
			msgids = msgids[2:]
	except Exception,e:
		server.store(msgids, '-FLAGS', '\\Seen')
		debug('Flag \Seen reverted for messages with id %s' % msgids)
		server.close()
		server.logout()
		error(e.__str__())
		# - not reached -
	server.close()
	server.logout()


if __name__ == '__main__':
	main()

