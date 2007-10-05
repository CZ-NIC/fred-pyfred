#!/usr/bin/env python
#
# vim: set ts=4 sw=4:

import sys, getopt, imaplib, tempfile, commands, os
from email.FeedParser import FeedParser

IMAPUSER = 'testbank@nic.cz'
IMAPPASS = 'heslo345G'
#IMAPUSER = 'fred-banka@nic.cz'
#IMAPPASS = 'meCh3quu'
IMAPHOST = 'mail.nic.cz'
FROM1    = 'notifikace@ps.ipb.cz'
FROM2    = 'notifikace@ps.ipb.cz'
FM_CMD   = 'filemanager_client'
NSHOST   = 'localhost'

verbose = False

def usage():
	print '%s [-g gpc-processor] [-H imaphost] [-n nameservice] [-p imappassword] [-u imapuser] [-v]' % sys.argv[0]

def debug(msg):
	global verbose

	if verbose:
		sys.stderr.write(msg + '\n')

def error(msg):
	sys.stderr.write('Exiting due to an error: %s\n' % msg)

def main():
	global verbose

	try:
		opts, args = getopt.getopt(sys.argv[1:], "g:h:p:u:v", [])
	except getopt.GetoptError:
		usage()
		sys.exit(2)

	imaphost = IMAPHOST
	imappass = IMAPPASS
	imapuser = IMAPUSER
	nshost   = NSHOST
	gpc_prog = '' # GPCs are not processed by default

	for o,a in opts:
		if o == '-g':
			gpc_prog = a
		elif o == '-h':
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
	r, data = server.search(None, '((UNSEEN) (OR FROM "%s" FROM "%s"))'
			% (FROM1, FROM2))
	msgids = data[0].split(' ')
	if not msgids[0]:
		debug('No new messages in mailbox')
		sys.exit(0)
	messages = {}
	for msgid in msgids:
		(r, data) = server.fetch(msgid, '(RFC822)')
		messages[msgid] = data[0][1]
	debug('%d new messages' % len(messages))
	# since now, whatever bad happens, we must restore unseen flag
	# on downloaded messages
	processed_msgs = []
	try:
		for msgid in messages:
			rawmsg = messages[msgid]
			fp = FeedParser()
			fp.feed(rawmsg)
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
			fd = tempfile.NamedTemporaryFile()
			fd.write(octets)
			fd.flush()
			# process GPC format
			if gpc_prog and filename.endswith('.gpc'):
				cmd = '%s --bank-gpc "%s"' % (gpc_prog, fd.name)
				(status, output) = commands.getstatusoutput(cmd)
				if os.WEXITSTATUS(status) != 0:
					error('Error when executing command: %s\n%s' % (cmd,output))
					continue
				else:
					debug(cmd)
					debug('GPC processor\'s output:')
					debug(output)
			# save the attachment via filemanager client
			cmd = '%s --input="%s" --label="%s" --mime="%s" --type=4 '\
					'--nameservice="%s"'\
					% (FM_CMD, fd.name, filename, mimetype, nshost)
			(status, output) = commands.getstatusoutput(cmd)
			if os.WEXITSTATUS(status) != 0:
				error('Error when executing command: %s\n%s' % (cmd, output))
				error('!!! content of database desynchronized !!!')
				continue
			else:
				debug(cmd)
				debug('Filemanager\'s output:')
				debug(output)
			# update successfully saved messages
			processed_msgs.append(msgid)
	except Exception,e:
		error(e.__str__())
		# we have to revert seen flag yet

	for msgid in messages:
		if msgid not in processed_msgs:
			server.store(msgid, '-FLAGS', '\\Seen')
			debug('Flag \Seen reverted for message with id %s' % msgid)
	server.close()
	server.logout()
	# all messages processed?
	if len(processed_msgs) != len(messages):
		sys.exit(1)


if __name__ == '__main__':
	main()

