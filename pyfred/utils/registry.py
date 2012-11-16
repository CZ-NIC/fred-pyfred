#!/usr/bin/python
"Registry utils."
import re
# pyfred
from pyfred.utils.fredconst import CONTACT_REGEX, CONTACT_REGEX_RESTRICTED
from pyfred.idlstubs import Registry


CONTACT_REGEX_PATT = re.compile(CONTACT_REGEX)
CONTACT_REGEX_RESTRICTED_PATT = re.compile(CONTACT_REGEX_RESTRICTED)


# DUPLICITY: server/src/fredlib/contact.cc: bool checkHandleFormat(const std::string& handle) const
def check_handle_format(logger, handle):
    "Check format of the handle."
    match = CONTACT_REGEX_PATT.match(handle)
    if match is None:
        logger.log(logger.DEBUG, 'Invalid format of handle "%s".' % handle)
        raise Registry.DomainBrowser.INCORRECT_USAGE
