#!/usr/bin/python
"Fred constants."

# DUPLICITY: server/src/fredlib/contact.cc
CONTACT_REGEX_RESTRICTED = "[cC][iI][dD]:[a-zA-Z0-9_:.-]{1,59}"

# server/src/fredlib/contact.cc: #define CONTACT_REGEX "[a-zA-Z0-9_:.-]{1,63}"
# server/src/fredlib/nsset.cc: #define NSSET_REGEX "[a-zA-Z0-9_:.-]{1,63}"
# server/src/fredlib/keyset.cc: #define KEYSET_REGEX "[a-zA-Z0-9_:.-]{1,63}"
CONTACT_REGEX = "[a-zA-Z0-9_:.-]{1,63}"


DOMAIN_NAME_REGEX = "([a-z0-9-_]{1,63}\.cz|[0-9.]{1,63}\.e164\.arpa)"


# sql/ccreg.sql: Role INTEGER NOT NULL DEFAULT 1,
# ChangeLog: Adding role of contact - 1=admin, 2=temp and
DOMAIN_ROLE = dict(admin=1, temp=2)


## SELECT type, name FROM object_registry WHERE type = %d
#OBJECT_REGISTRY_TYPES = dict(contact=1, nsset=2, domain=3, keyset=4)

class EnunObjectStates(object):
    server_transfer_prohibited = "serverTransferProhibited"
    server_update_prohibited = "serverUpdateProhibited"
