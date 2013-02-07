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


# SELECT type, name FROM object_registry WHERE type = %d
OBJECT_REGISTRY_TYPES = dict(contact=1, nsset=2, domain=3, keyset=4)


# \d object
#   Column   |            Type             | Modifiers
#------------+-----------------------------+-----------
# authinfopw | character varying(300)      |
AUTH_INFO_LENGTH = 300


ENUM_OBJECT_STATES = dict(serverTransferProhibited=3,
                          serverUpdateProhibited=4,
                          serverBlocked=7,
                          deleteCandidate=17,
                          identifiedContact=22,
                          validatedContact=23)
#fred=> SELECT * FROM enum_object_states ORDER BY id;
# id |               name               |   types   | manual | external
#----+----------------------------------+-----------+--------+----------
#  1 | serverDeleteProhibited           | {1,2,3,4} | t      | t
#  2 | serverRenewProhibited            | {3}       | t      | t
#  3 | serverTransferProhibited         | {1,2,3,4} | t      | t
#  4 | serverUpdateProhibited           | {1,2,3,4} | t      | t
#  5 | serverOutzoneManual              | {3}       | t      | t
#  6 | serverInzoneManual               | {3}       | t      | t
#  7 | serverBlocked                    | {3}       | t      | t
#  8 | expirationWarning                | {3}       | f      | f
#  9 | expired                          | {3}       | f      | t
# 10 | unguarded                        | {3}       | f      | f
# 11 | validationWarning1               | {3}       | f      | f
# 12 | validationWarning2               | {3}       | f      | f
# 13 | notValidated                     | {3}       | f      | t
# 14 | nssetMissing                     | {3}       | f      | f
# 15 | outzone                          | {3}       | f      | t
# 16 | linked                           | {1,2,4}   | f      | t
# 17 | deleteCandidate                  | {1,2,3,4} | f      | t
# 18 | serverRegistrantChangeProhibited | {3}       | t      | t
# 19 | deleteWarning                    | {3}       | f      | f
# 20 | outzoneUnguarded                 | {3}       | f      | f
# 21 | conditionallyIdentifiedContact   | {1}       | t      | t
# 22 | identifiedContact                | {1}       | t      | t
# 23 | validatedContact                 | {1}       | t      | t
# 24 | mojeidContact                    | {1}       | t      | t
#(24 rows)
