#!/usr/bin/env python

import socket
from omniORB import CORBA
import CosNaming, ccReg

MAX_MSG_LEN = 1024


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
(domain, timestamp) = whois_obj.getDomain("1.1.1.5.4.7.2.2.2.e164.arpa")
print domain.fqdn

#(timestamp, domain.fqdn, domain.created, domain.expired,
#		domain.registrarName, domain.registrarUrl)
#     		for tech in domain.tech:
#     		for ns in domain.ns:
#
#except ccReg.Whois.DomainError, e:
#	if e.type == ccReg.WE_NOTFOUND:
#		print "NOT FOUND"
#	if e.type in (ccReg.WE_INVALID, ccReg.WE_DOMAIN_LONG):
#		print "INVALID"
#	if e.type == ccReg.WE_DOMAIN_BAD_ZONE:
#		print "BAD ZONE"
#except ccReg.Whois.WhoisError, e:
#	print "WHOIS ERROR"
#except Exception, e:
#	print e
