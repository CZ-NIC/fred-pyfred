import sys
from twisted.python import log
from twisted.internet import protocol, reactor
from twisted.protocols import pop3
from twisted.cred import checkers, portal
from twisted.mail import maildir

"""
Don't ask me how does it work. I just put together peaces of examples from
twisted tutorial, digged little bit in twisted source code and the result
is wonderfull - simple POP3 server which holds accounts in memory and serves
emails from memory.
"""

POP3user = 'a'
POP3pass = 'a'

TO_HEADER_TEMPLATE = 'To: return-%d@nic.cz'

class MyStringListMailbox (maildir.StringListMailbox):

	def deleteMessage(self, i):
		#self.msgs[i] = ''
		pass

class DummyMailbox (maildir.AbstractMaildirDomain):

	def __init__(self, emails):
		self.emails = emails

	def requestAvatar(self, avatarId, mind, *interfaces):
		mbox = MyStringListMailbox(self.emails)
		return (pop3.IMailbox, mbox, lambda: None)

class POP3 (pop3.POP3):

	def connectionMade(self):
		if self.magic is None:
			self.magic = self.generateMagic()
		self.successResponse(self.magic)
		self.setTimeout(self.timeOut)
		checker = checkers.InMemoryUsernamePasswordDatabaseDontUse()
		checker.addUser(POP3user, POP3pass)
		realm = DummyMailbox(self.factory.emails)
		self.portal = portal.Portal(realm, [checker])
		log.msg("New connection from " + str(self.transport.getPeer()))

	def connectionLost(self, reason):
		if self._onLogout is not None:
			self._onLogout()
			self._onLogout = None
		self.factory.emails = []
		self.setTimeout(None)


class POP3Factory (protocol.ServerFactory):
	protocol = POP3

	def __init__(self, emails):
		self.emails = emails


def usage():
	print ''
	print 'This program simulates pop3 server for purposes of testing'
	print 'mailer module of pyfred. The messages served by pop3 server'
	print 'simulate notifications about undelivered emails.'
	print ''
	print 'pop3_server.py id [id ...]'
	print ''
	print 'For each ID will be created one email in mailbox. The "To"'
	print 'header of email will contain the ID and will have format'
	print 'required by mailer module of pyfred.'
	print ''


if __name__ == '__main__':
	if len(sys.argv) < 2:
		usage()
		sys.exit(2)

	emails = []
	for arg in sys.argv[1:]:
		mailid = int(arg)
		emails.append(TO_HEADER_TEMPLATE % mailid +
			'\n\nContent of email from twisted POP3 server.')
	# We bind non-priviledged port so that we don't have to run as root
	reactor.listenTCP(8110, POP3Factory(emails))
	reactor.run()

