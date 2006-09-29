#!/usr/bin/env python

from omniORB import CORBA, importIDL
from ConfigParser import ConfigParser
import sys
import CosNaming, ccReg
from pprint import pprint
import corbaparser

conf = ConfigParser()
conf.read("./simple_test.conf")

idl = conf.get('corba', 'idl')
ior = conf.get('corba', 'ior')

ccReg = sys.modules[importIDL(idl)[0]]

orb = CORBA.ORB_init(["-ORBInitRef", "NameService=%s" % ior], CORBA.ORB_ID)

rootContext = orb.string_to_object(ior)._narrow(CosNaming.NamingContext)

epp = rootContext.resolve([CosNaming.NameComponent("ccReg", "context"), CosNaming.NameComponent('EPP', "Object")])._narrow(ccReg.EPP)

parser = corbaparser.CorbaParser('utf-8')

handle = 'CID:SURY-CZ.NIC'

(response,value) = parser.parse(epp.ContactInfo(handle, 0, "dummy-0", ''))

pprint(response['errCode'])

sys.exit(0)
