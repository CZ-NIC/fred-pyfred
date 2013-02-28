#!/usr/bin/python
import ConfigParser
from datetime import datetime, timedelta
# pyfred
from pyfred.idlstubs import Registry, Registry__POA
# objects
from pyfred.registry.interface import ContactInterface, DomainInterface, NssetInterface, KeysetInterface
from pyfred.registry.utils.constants import OBJECT_REGISTRY_TYPES
from pyfred.registry.utils import normalize_and_check_handle, normalize_and_check_domain, \
                                  normalize_and_check_langcode



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
        limits = dict(domains=1000, nssets=1000, keysets=1000)

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


    def getDomainList(self, contact_handle, lang, offset):
        """
        RecordSet getDomainList(
            in RegistryObject contact_handle,
            in string lang
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getDomainList(contact_handle="%s")' % contact_handle)
        return self.domain.getDomainList(self._norm(contact_handle), self._normLang(lang), offset)


    def getNssetList(self, contact_handle, lang, offset):
        """
        RecordSet getNssetList(
            in RegistryObject contact_handle,
            in string lang
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getNssetList(contact_handle="%s")' % contact_handle)
        return self.nsset.getNssetList(self._norm(contact_handle), self._normLang(lang), offset)


    def getKeysetList(self, contact_handle, lang, offset):
        """
        RecordSet getKeysetList(
            in RegistryObject contact_handle,
            in string lang
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getKeysetList(contact_handle="%s")' % contact_handle)
        return self.keyset.getKeysetList(self._norm(contact_handle), self._normLang(lang), offset)


    def getDomainsForKeyset(self, contact_handle, keyset, lang, offset):
        """
        RecordSet getDomainsForKeyset(
            in RegistryObject contact_handle,
            in RegistryObject keyset,
            in string lang
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS, ACCESS_DENIED);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getDomainsForKeyset(contact_handle="%s", keyset="%s")' % (contact_handle, keyset))
        return self.domain.getDomainsForKeyset(self._norm(contact_handle), self._norm(keyset), self._normLang(lang), offset)


    def getDomainsForNsset(self, contact_handle, nsset, lang, offset):
        """
        RecordSet getDomainsForNsset(
            in RegistryObject contact_handle,
            in RegistryObject nsset,
            in string lang
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS, ACCESS_DENIED);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getDomainsForNsset(contact_handle="%s", nsset="%s")' % (contact_handle, nsset))
        return self.domain.getDomainsForNsset(self._norm(contact_handle), self._norm(nsset), self._normLang(lang), offset)


    def getContactDetail(self, contact_handle, contact_handle_detail, lang):
        """
        ContactDetail getContactDetail(
            in RegistryObject contact_handle,
            in RegistryObject contact_handle_detail,
            in string lang,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getContactDetail(contact_handle="%s", contact_for_detail="%s")' % (contact_handle, contact_handle_detail))
        return self.contact.getContactDetail(self._norm(contact_handle), self._norm(contact_handle_detail), self._normLang(lang))

    def getNssetDetail(self, contact_handle, nsset, lang):
        """
        NSSetDetail getNssetDetail(
            in RegistryObject contact_handle,
            in RegistryObject nsset,
            in string lang,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getNssetDetail(contact_handle="%s", nsset="%s")' % (contact_handle, nsset))
        return self.nsset.getNssetDetail(self._norm(contact_handle), self._norm(nsset), self._normLang(lang))

    def getDomainDetail(self, contact_handle, domain, lang):
        """
        DomainDetail getDomainDetail(
            in RegistryObject contact_handle,
            in RegistryObject domain,
            in string lang,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getDomainDetail(contact_handle="%s", domain="%s")' % (contact_handle, domain))
        return self.domain.getDomainDetail(self._norm(contact_handle), self._dom(domain), self._normLang(lang))

    def getRegistrarDetail(self, contact_handle, handle):
        """
        RegistrarDetail getRegistrarDetail(
                in RegistryObject contact_handle,
                in RegistryObject handle,
                in string lang
            ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getRegistrarDetail(contact_handle="%s", handle="%s")' % (contact_handle, handle))
        return self.domain.getRegistrarDetail(self._norm(contact_handle), self._norm(handle))

    def getKeysetDetail(self, contact_handle, keyset, lang):
        """
        KeysetDetail getKeysetDetail(
            in RegistryObject contact_handle,
            in RegistryObject keyset,
            in string lang,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.getKeysetDetail(contact_handle="%s", keyset="%s")' % (contact_handle, keyset))
        return self.keyset.getKeysetDetail(self._norm(contact_handle), self._norm(keyset), self._normLang(lang))

    def setContactDiscloseFlags(self, contact_handle, flags):
        """
        void setDiscloseFlags(
                in RegistryObject contact_handle,
                in ContactDiscloseFlags flags
            ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS, ACCESS_DENIED, OBJECT_BLOCKED);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.setContactDiscloseFlags(contact_handle="%s", flags=%s)' % (contact_handle, flags))
        return self.contact.setContactDiscloseFlags(self._norm(contact_handle), flags)

    def setAuthInfo(self, contact_handle, object_handle, objtype, auth_info):
        """
        void setAuthInfo(
                in RegistryObject contact_handle,
                in RegistryObject object_handle,
                in RegistryObject objtype,
                in RegistryObject auth_info,
            ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS, ACCESS_DENIED, OBJECT_BLOCKED);
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.setAuthInfo(contact_handle="%s", object_handle="%s", objtype="%s", auth_info="*******")' % (contact_handle, object_handle, objtype))

        # only contact type can update auth info
        if objtype != "contact":
            raise Registry.DomainBrowser.INCORRECT_USAGE

        # update auth info only for user's contact
        if contact_handle != object_handle:
            raise Registry.DomainBrowser.ACCESS_DENIED

        normalize = normalize_and_check_domain if objtype == "domain" else normalize_and_check_handle
        return getattr(self, objtype).setAuthInfo(self._norm(contact_handle), normalize(self.logger, object_handle), objtype, auth_info)


    def setObjectBlockStatus(self, contact_handle, objtype, objects, block):
        """
        void setObjectBlockStatus(
            in RegistryObject contact_handle,
            in RegistryObject objtype,
            in RegistryObjectSeq objects,
            in ObjectBlockType block
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS, ACCESS_DENIED, OBJECT_BLOCKED);

        enum ObjectBlockType {
            BLOCK_TRANSFER, UNBLOCK_TRANSFER,
            BLOCK_UPDATE, UNBLOCK_UPDATE,
            BLOCK_TRANSFER_AND_UPDATE, UNBLOCK_TRANSFER_AND_UPDATE
        };
        """
        self.logger.log(self.logger.INFO, 'Call DomainBrowser.setObjectBlockStatus(contact_handle="%s", objtype="%s", objects=%s, block=%s)' % (contact_handle, objtype, objects, block))

        if objtype not in OBJECT_REGISTRY_TYPES:
            raise Registry.DomainBrowser.INCORRECT_USAGE

        normalize = normalize_and_check_domain if objtype == "domain" else normalize_and_check_handle
        selections = []
        for name in objects:
            selections.append(normalize(self.logger, name))
        self.logger.log(self.logger.DEBUG, "Normalized objects: %s" % selections)

        return getattr(self, objtype).setObjectBlockStatus(self._norm(contact_handle), objtype, selections, block)


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
