#!/usr/bin/python
"Registry utils."
import re
# pyfred
from pyfred.registry.utils.constants import CONTACT_REGEX, CONTACT_REGEX_RESTRICTED, DOMAIN_NAME_REGEX
from pyfred.idlstubs import Registry


CONTACT_REGEX_PATT = re.compile(CONTACT_REGEX)
CONTACT_REGEX_RESTRICTED_PATT = re.compile(CONTACT_REGEX_RESTRICTED)
DOMAIN_NAME_REGEX_PATT = re.compile(DOMAIN_NAME_REGEX)


# DUPLICITY: server/src/fredlib/contact.cc: bool checkHandleFormat(const std::string& handle) const
def normalize_and_check_handle(logger, handle):
    "Check format of the handle."
    handle = handle.upper()
    match = CONTACT_REGEX_PATT.match(handle)
    if match is None:
        logger.log(logger.DEBUG, 'Invalid format of handle "%s".' % handle)
        raise Registry.DomainBrowser.INCORRECT_USAGE
    return handle


def normalize_and_check_domain(logger, domain_name):
    "Normalize domain name."
    domain_name = domain_name.lower()
    match = DOMAIN_NAME_REGEX_PATT.match(domain_name)
    if match is None:
        logger.log(logger.DEBUG, 'Invalid format of domain name "%s".' % domain_name)
        raise Registry.DomainBrowser.INCORRECT_USAGE
    return domain_name


def normalize_spaces(text):
    "Remove enters and redundant spaces."
    return re.sub("\s+", " ", text).strip()