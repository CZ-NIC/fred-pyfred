#!/usr/bin/env python

import socket
from omniORB import CORBA
import CosNaming, ccReg

MAX_MSG_LEN = 1024

def read_request(sock):
	line = ''
	while True:
		chunk = sock.recv(MAX_MSG_LEN)
		if chunk == '':
			raise RuntimeError, "socket connection broken"
		list = chunk.split("\r\n")
		line = line + list[0]
		if len(list) > 1:
			break;
	return line


def send_response(sock, msg):
	sock.sendall(msg + "\r\n")

# create an INET, STREAMing socket
serversocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
# bind the socket to a public host, and a well-known port
serversocket.bind(('', 8043))
# become a server socket
serversocket.listen(5)

while 1:
	#accept connections from outside
	(clientsocket, address) = serversocket.accept()
	#now do something with the clientsocket
	domainName = read_request(clientsocket)
	#
	#
	# Initialise the ORB
	orb = CORBA.ORB_init(["-ORBInitRef", "NameService=corbaname::localhost"],
			CORBA.ORB_ID)
	# Obtain a reference to the root naming context
	obj = orb.resolve_initial_references("NameService")
	rootContext = obj._narrow(CosNaming.NamingContext)
	if rootContext is None:
		raise ZoneException("Failed to narrow the root naming context")
	# Resolve the name "ccReg.context/ZoneGenerator.Object"
	name = [CosNaming.NameComponent("ccReg", "context"),
			CosNaming.NameComponent("PyWhois", "Object")]
	obj = rootContext.resolve(name)
	# Narrow the object to an ccReg::Whois
	whois_obj = obj._narrow(ccReg.Whois)
	if (whois_obj is None):
		raise ZoneException("Object reference is not an ccReg::Whois")
	#
	#
	#response
	resp = \
"""% 
% (c) 2006 (http://www.nic.cz)
% 
% Intended use of supplied data and information
% 
% Data contained in the domain name register, as well as information
% supplied through public information services of CZ.NIC association, are
% appointed only for purposes connected with Internet network
% administration and operation, or for the purpose of legal or other
% similar proceedings, in process as regards a matter connected
% particularly with holding and using a concrete domain name.
% 
% The domain name register is protected by the law according to
% appropriate legalities about database protection. Data, information
% should not be collected, reproduced, stored or moved beyond this scope
% in any form without preceding agreement from CZ.NIC association. The use
% of data, information or any part of them contrary to this purpose could
% be considered as a breach of the rights of CZ.NIC association, or of
% persons whose data are stored in the domain name register or as a
% violation of the rights of executors of the property rights. Gathering
% of the data or any part of them and /or providing of them for
% unrequested message distribution, abuse of network services operation
% and breaking the privacy of the other users is particularly considered
% as a violation of these rights. Using them contrary to the stated
% purpose can also lead to the user being considered as criminally
% responsible.
% 
% Attention: Requirements for the provision of data or information are
% recorded. If a request or a series of requests is evaluated as an attack
% which may cause damage to network services or as an effort to gather
% data in conflict with the original purpose, this may lead to a blocking
% of the access to information services of CZ.NIC or further action as may
% be deemed necessary.
% 
% The restrictions indicated above do not refer to statistical data
% provided by CZ.NIC on condition that the use of such information will
% not result in any change of the content or context thereof, and also on
% condition that a reference is provided along with any such use to the
% CZ.NIC Association or the domain name register as a source of such
% information.
% 
% By using the WHOIS service or the service of searching in the domain
% names register database, the user agrees to the stated conditions and
% purposes of data use.
% 
"""
	try:
		(domain, timestamp) = whois_obj.getDomain(domainName)
		resp += \
"""%% Timestamp: %s

Domain:       %s
Status:       REGISTERED
Registered:   %s
Expiration:   %s
Registrant:
    Please visit webbased whois at http://www.nic.cz/ for more information.

Registrar:
     Name:    %s
     Website: %s

Technical Contact:
""" % (timestamp, domain.fqdn, domain.created, domain.expired,
		domain.registrarName, domain.registrarUrl)
     		for tech in domain.tech:
			resp += "     %s\n" % tech
		resp += \
"""
Nameservers:
"""
     		for ns in domain.ns:
			resp += "     %s\n" % ns
		send_response(clientsocket, resp)
		clientsocket.close()
	# not found
	except ccReg.Whois.DomainError, e:
		if e.type == ccReg.WE_NOTFOUND:
			resp += \
"""%% Timestamp: %s

Domain:      %s
Status:      FREE
""" % (e.timestamp, domainName)
		if e.type in (ccReg.WE_INVALID, ccReg.WE_DOMAIN_LONG):
			resp += \
"""%% Timestamp: %s

Domain name is invalid.
""" % e.timestamp
		if e.type == ccReg.WE_DOMAIN_BAD_ZONE:
			resp += \
"""%% Timestamp: %s

The domain is not managed by this registry.
""" % e.timestamp
		send_response(clientsocket, resp)
		clientsocket.close()
	# internal error
	except ccReg.Whois.WhoisError, e:
		resp +="Internal server error occured. Please try again later.\n"
		send_response(clientsocket, resp)
		clientsocket.close()
	except Exception, e:
		resp +="Internal server error occured. Please try again later.\n"
		print "Corba call failed:", e
		send_response(clientsocket, resp)
		clientsocket.close()
