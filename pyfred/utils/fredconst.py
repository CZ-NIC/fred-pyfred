#!/usr/bin/python
"Fred constants."

# DUPLICITY: server/src/fredlib/contact.cc
CONTACT_REGEX_RESTRICTED = "[cC][iI][dD]:[a-zA-Z0-9_:.-]{1,59}"
CONTACT_REGEX = "[a-zA-Z0-9_:.-]{1,63}"


# sql/ccreg.sql: Role INTEGER NOT NULL DEFAULT 1,
# ChangeLog: Adding role of contact - 1=admin, 2=temp and
DOMAIN_ROLE = dict(admin=1, temp=2)
