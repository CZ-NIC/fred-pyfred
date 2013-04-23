#!/usr/bin/python
import ConfigParser
# pyfred
from pyfred.idlstubs import Registry, Registry__POA
# objects
from pyfred.registry.interface import ContactInterface, DomainInterface, NssetInterface, KeysetInterface
from pyfred.registry.utils.constants import OBJECT_REGISTRY_TYPES
from pyfred.registry.utils.decorators import log_not_corba_user_exceptions
from pyfred.registry.utils import regstr, \
                    normalize_and_check_handle, normalize_and_check_domain, \
                    normalize_and_check_langcode, normalize_and_check_regref



class DomainBrowserServerInterface(Registry__POA.DomainBrowser.Server):
    """
    This class implements DomainBrowser interface.
    """

    def __init__(self, logger, database, conf, joblist, corba_refs):
        """
        Initializer saves db (which is later used for opening database
        connection) and logger (used for logging).
        """
        self.logger = logger # syslog functionality

        # Defaults of limits when they missing in config:
        limits = dict(domains=5000, nssets=5000, keysets=5000)

        # config
        section = "DomainBrowser"
        if conf.has_section(section):
            for name in ("domains", "nssets", "keysets"):
                try:
                    value = conf.getint(section, "list_%s_limit" % name)
                    if value:
                        limits[name] = value
                except ConfigParser.NoOptionError, msg:
                    pass # use default defined above when the limit is not in the config

        # Object interfaces
        self.contact = ContactInterface(self, database, logger)
        self.domain = DomainInterface(self, database, logger, limits["domains"])
        self.nsset = NssetInterface(self, database, logger, limits["nssets"])
        self.keyset = KeysetInterface(self, database, logger, limits["keysets"])

        logger.log(logger.DEBUG, "Object DomainBrowser initialized.")


    def _norm(self, handle):
        "Normalize and check handle"
        return normalize_and_check_handle(self.logger, handle)

    def _dom(self, handle):
        "Normalize and check handle"
        return normalize_and_check_domain(self.logger, handle)

    def _normLang(self, lang):
        "Normalize and check handle"
        return normalize_and_check_langcode(self.logger, lang)

    def _norm_reg(self, handle_type, regref):
        "Normalize and check RegistryReference object"
        return normalize_and_check_regref(self.logger, handle_type, regref)

    def _norm_contact(self, regref):
        return self._norm_reg("contact", regref)

    def _norm_nsset(self, regref):
        return self._norm_reg("nsset", regref)

    def _norm_keyset(self, regref):
        return self._norm_reg("keyset", regref)

    def _norm_domain(self, regref):
        return self._norm_reg("domain", regref)


    @log_not_corba_user_exceptions
    def getObjectRegistryId(self, objtype, handle):
        """
        TID getObjectRegistryId(
            in string objtype,
            in string handle
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getObjectRegistryId(type="%s", handle="%s")' % (objtype, handle))
        if objtype not in OBJECT_REGISTRY_TYPES:
            raise Registry.DomainBrowser.INCORRECT_USAGE

        return self.contact.getObjectRegistryId(objtype, self._dom(handle) if objtype == "domain" else self._norm(handle))

    @log_not_corba_user_exceptions
    def getDomainList(self, contact, lang, offset):
        """
        RecordSet getDomainList(
            in RegistryReference contact,
            in string lang,
            in unsigned long offset,
            out boolean limit_exceeded
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getDomainList(contact="%s", lang="%s", offset=%d)' % (regstr(contact), lang, offset))
        return self.domain.getDomainList(self._norm_contact(contact), self._normLang(lang), offset)

    @log_not_corba_user_exceptions
    def getNssetList(self, contact, lang, offset):
        """
        RecordSet getNssetList(
            in RegistryReference contact,
            in string lang,
            in unsigned long offset,
            out boolean limit_exceeded
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getNssetList(contact="%s", lang="%s", offset=%d)' % (regstr(contact), lang, offset))
        return self.nsset.getNssetList(self._norm_contact(contact), self._normLang(lang), offset)

    @log_not_corba_user_exceptions
    def getKeysetList(self, contact, lang, offset):
        """
        RecordSet getKeysetList(
            in RegistryReference contact,
            in string lang,
            in unsigned long offset,
            out boolean limit_exceeded
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getKeysetList(contact="%s", lang="%s", offset=%d)' % (regstr(contact), lang, offset))
        return self.keyset.getKeysetList(self._norm_contact(contact), self._normLang(lang), offset)

    @log_not_corba_user_exceptions
    def getDomainsForKeyset(self, contact, keyset, lang, offset):
        """
        RecordSet getDomainsForKeyset(
            in RegistryReference contact,
            in RegistryReference keyset,
            in string lang,
            in unsigned long offset,
            out boolean limit_exceeded
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS, ACCESS_DENIED);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getDomainsForKeyset(contact="%s", keyset="%s", lang="%s", offset=%d)' % (regstr(contact), regstr(keyset), lang, offset))
        return self.domain.getDomainsForKeyset(self._norm_contact(contact), self._norm_keyset(keyset), self._normLang(lang), offset)

    @log_not_corba_user_exceptions
    def getDomainsForNsset(self, contact, nsset, lang, offset):
        """
        RecordSet getDomainsForNsset(
            in RegistryReference contact,
            in RegistryReference nsset,
            in string lang,
            in unsigned long offset,
            out boolean limit_exceeded
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS, ACCESS_DENIED);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getDomainsForNsset(contact="%s", nsset="%s", lang="%s", offset=%d)' % (regstr(contact), regstr(nsset), lang, offset))
        return self.domain.getDomainsForNsset(self._norm_contact(contact), self._norm_nsset(nsset), self._normLang(lang), offset)

    @log_not_corba_user_exceptions
    def getContactDetail(self, contact, detail, lang):
        """
        ContactDetail getContactDetail(
            in RegistryReference contact,
            in RegistryReference detail,
            in string lang,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getContactDetail(contact=%s, detail=%s)' % (regstr(contact), regstr(detail)))
        return self.contact.getContactDetail(self._norm_contact(contact), self._norm_contact(detail), self._normLang(lang))

    @log_not_corba_user_exceptions
    def getNssetDetail(self, contact, nsset, lang):
        """
        NSSetDetail getNssetDetail(
            in RegistryReference contact,
            in RegistryReference nsset,
            in string lang,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getNssetDetail(contact=%s, nsset=%s)' % (regstr(contact), regstr(nsset)))
        return self.nsset.getNssetDetail(self._norm_contact(contact), self._norm_nsset(nsset), self._normLang(lang))

    @log_not_corba_user_exceptions
    def getDomainDetail(self, contact, domain, lang):
        """
        DomainDetail getDomainDetail(
            in RegistryReference contact,
            in RegistryReference domain,
            in string lang,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getDomainDetail(contact=%s, domain=%s)' % (regstr(contact), regstr(domain)))
        return self.domain.getDomainDetail(self._norm_contact(contact), self._norm_domain(domain), self._normLang(lang))

    @log_not_corba_user_exceptions
    def getRegistrarDetail(self, contact, handle):
        """
        RegistrarDetail getRegistrarDetail(
                in RegistryReference contact,
                in RegistryObject handle
            ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getRegistrarDetail(contact=%s, handle="%s")' % (regstr(contact), handle))
        return self.domain.getRegistrarDetail(self._norm_contact(contact), self._norm(handle))

    @log_not_corba_user_exceptions
    def getKeysetDetail(self, contact, keyset, lang):
        """
        KeysetDetail getKeysetDetail(
            in RegistryReference contact,
            in RegistryReference keyset,
            in string lang,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getKeysetDetail(contact=%s, keyset=%s)' % (regstr(contact), regstr(keyset)))
        return self.keyset.getKeysetDetail(self._norm_contact(contact), self._norm_keyset(keyset), self._normLang(lang))

    @log_not_corba_user_exceptions
    def setContactDiscloseFlags(self, contact, flags, request_id):
        """
        boolean setContactDiscloseFlags(
                in RegistryReference contact,
                in UpdateContactDiscloseFlags flags,
                in TID request_id
            ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, ACCESS_DENIED, OBJECT_BLOCKED);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.setContactDiscloseFlags(contact=%s, flags=%s)' % (regstr(contact), flags))
        return self.contact.setContactDiscloseFlags(self._norm_contact(contact), flags, request_id)

    @log_not_corba_user_exceptions
    def setAuthInfo(self, contact, objtype, objref, auth_info, request_id):
        """
        boolean setAuthInfo(
                in RegistryReference contact,
                in RegistryObject objtype,
                in RegistryReference objref,
                in RegistryObject auth_info,
                in TID request_id
            ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS, ACCESS_DENIED, OBJECT_BLOCKED);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.setAuthInfo(contact=%s, objtype="%s", objref=%s, auth_info="*******")' % (regstr(contact), objtype, regstr(objref)))

        # only contact type can update auth info
        if objtype != "contact":
            raise Registry.DomainBrowser.INCORRECT_USAGE

        # update auth info only for user's contact
        if contact.handle != objref.handle:
            raise Registry.DomainBrowser.ACCESS_DENIED

        return getattr(self, objtype).setAuthInfo(self._norm_contact(contact), objtype, self._norm_reg(objtype, objref), auth_info, request_id)

    @log_not_corba_user_exceptions
    def setObjectBlockStatus(self, contact, objtype, objects, block):
        """
        boolean setObjectBlockStatus(
            in RegistryReference contact,
            in RegistryObject objtype,
            in RegistryReferenceSeq objects,
            in ObjectBlockType block,
            out RecordSequence blocked
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS, ACCESS_DENIED);

        enum ObjectBlockType {
            BLOCK_TRANSFER, UNBLOCK_TRANSFER,
            BLOCK_UPDATE, UNBLOCK_UPDATE,
            BLOCK_TRANSFER_AND_UPDATE, UNBLOCK_TRANSFER_AND_UPDATE
        };
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.setObjectBlockStatus(contact=%s, objtype="%s", objects=%s, block=%s)' % (regstr(contact), objtype, objects, block))

        if objtype not in OBJECT_REGISTRY_TYPES:
            raise Registry.DomainBrowser.INCORRECT_USAGE

        selections = []
        for objref in objects:
            selections.append(self._norm_reg(objtype, objref))
        self.logger.log(self.logger.DEBUG, "Normalized objects: %s" % selections)

        return getattr(self, objtype).setObjectBlockStatus(self._norm_contact(contact), objtype, selections, block)

    @log_not_corba_user_exceptions
    def getPublicStatusDesc(self, lang):
        """
        RecordSequence getPublicStatusDesc(
                in string lang
            ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getPublicStatusDesc(lang="%s")' % lang)
        return self.domain.getPublicStatusDesc(self._normLang(lang))



def init(logger, db, conf, joblist, corba_refs):
    """
    Function which creates, initializes and returns servant DomainBrowser.
    """
    servant = DomainBrowserServerInterface(logger, db, conf, joblist, corba_refs)
    return servant, "DomainBrowser"
