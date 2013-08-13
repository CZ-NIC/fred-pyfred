#!/usr/bin/python
"Registry utils."
import re
import sys
import traceback
from StringIO import StringIO
# pyfred
from pyfred.registry.utils.constants import CONTACT_REGEX, CONTACT_REGEX_RESTRICTED, \
                                DOMAIN_NAME_REGEX, LANGUAGES, OBJECT_REGISTRY_TYPES
from pyfred.idlstubs import Registry


CONTACT_REGEX_PATT = re.compile(CONTACT_REGEX)
CONTACT_REGEX_RESTRICTED_PATT = re.compile(CONTACT_REGEX_RESTRICTED)
DOMAIN_NAME_REGEX_PATT = re.compile(DOMAIN_NAME_REGEX)



def normalize_and_check_regref(logger, handle_type, regref):
    "Check format of the handle."
    if handle_type == "domain":
        handle = regref.handle.lower()
        pattern = DOMAIN_NAME_REGEX_PATT
        message = 'Invalid format of domain name "%s".'
    else:
        handle = regref.handle.upper()
        pattern = CONTACT_REGEX_PATT
        message = 'Invalid format of handle "%s".'

    match = pattern.match(handle)
    if match is None:
        logger.log(logger.INFO, message % handle)
        raise Registry.DomainBrowser.INCORRECT_USAGE

    object_id = regref.id
    if not isinstance(object_id, long):
        logger.log(logger.INFO, "Invalid format of ID %s." % regref)
        raise Registry.DomainBrowser.INCORRECT_USAGE

    regref.object_id = regref.id
    regref.handle = handle
    regref.type_id = OBJECT_REGISTRY_TYPES[handle_type]

    return regref


def regstr(regref):
    "Make string from RegistryReference instance."
    return "(%d,'%s')" % (regref.id, regref.handle)

def regstrseq(regrefs):
    "Repr sequence of RegistryReference."
    retval = []
    for reg in regrefs:
        retval.append("(%d,'%s')" % (reg.id, reg.handle))
    return "(%s)" % ", ".join(retval)


# DUPLICITY: server/src/fredlib/contact.cc: bool checkHandleFormat(const std::string& handle) const
def normalize_and_check_handle(logger, handle):
    "Check format of the handle."
    handle = handle.upper()
    match = CONTACT_REGEX_PATT.match(handle)
    if match is None:
        logger.log(logger.INFO, 'Invalid format of handle "%s".' % handle)
        raise Registry.DomainBrowser.INCORRECT_USAGE
    return handle

def normalize_and_check_domain(logger, domain_name):
    "Normalize domain name."
    # TODO: server/src/fredlib/zone.cc: parseDomainName()
    domain_name = domain_name.lower()
    match = DOMAIN_NAME_REGEX_PATT.match(domain_name)
    if match is None:
        logger.log(logger.INFO, 'Invalid format of domain name "%s".' % domain_name)
        raise Registry.DomainBrowser.INCORRECT_USAGE
    return domain_name


def normalize_and_check_langcode(logger, lang_code):
    "Normalize language code."
    lang_code = lang_code.upper()
    if lang_code not in LANGUAGES:
        raise Registry.DomainBrowser.INCORRECT_USAGE
    return lang_code


def normalize_spaces(text):
    "Remove enters and redundant spaces."
    return re.sub("\s+", " ", text).strip()


def parse_array_agg(value):
    "Parse postgresql array_agg (array_accum)"
    # "{outzone,nssetMissing}" or "{NULL}" -> ["outzone", "nssetMissing"] or []
    return [name for name in value[1:-1].split(",") if name not in ("NULL", "")]

def parse_array_agg_int(value):
    "Parse postgresql array_agg (array_accum). It must be integers only!"
    return [int(item) for item in parse_array_agg(value)]


def make_params_private(params):
    "Make params private"
    if params is None:
        return ""
    private_params = params.copy()
    if "auth_info" in private_params:
        private_params["auth_info"] = "********"
    return private_params

def none2str(value):
    "Convert None (NULL) to the empty string."
    return "" if value is None else value


def get_exception():
    'Fetch exception for debugging.'
    msg = ['Traceback (most recent call last):']
    ex = sys.exc_info()
    #sys.exc_clear()
    for trace in traceback.extract_tb(ex[2]):
        msg.append(' File "%s", line %d, in %s' % (trace[0], trace[1], trace[2]))
        msg.append('    %s' % trace[3])
    msg.append('%s: %s' % (ex[0], ex[1]))
    return '\n'.join(msg)


class StateItem(object):
    "Represent number of State imporance"

    def __init__(self, item):
        # state = (importance, description)
        self.state = [item]

    def add(self, item):
        "Add state"
        self.state.append(item)

    def strImportance(self):
        importance = 0
        for num, desc in self.state:
            importance |= num
        return str(importance)

    def strDescription(self):
        return "|".join([item[1] for item in sorted(self.state)])

    def __repr__(self):
        return "<%s %s>" % (self.__class__.__name__, self.state)
