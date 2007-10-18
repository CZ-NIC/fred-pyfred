#!/bin/sh

fred_client -xd 'create_contact CID:PFUT-CONTACT "Jan Ban" info@mail.com Street Brno 123000 CZ'
fred_client -xd 'create_nsset NSSID:PFUT-NSSET ((a.ns.nic.cz (217.31.205.180)), (c.ns.nic.cz (193.29.206.1))) CID:PFUT-CONTACT'
fred_client -xd 'create_domain nic.cz CID:PFUT-CONTACT NSSID:PFUT-NSSET'
