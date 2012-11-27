#!/usr/bin/python
import ConfigParser
from datetime import datetime, timedelta
# pyfred
from pyfred.idlstubs import Registry, Registry__POA
# objects
from pyfred.registry.interface import ContactInterface, DomainInterface, NssetInterface, KeysetInterface



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
        list_domains_limit, list_nssets_limit, list_keysets_limit = 1000, 1000, 1000

        # config
        section = "DomainBrowser"
        if conf.has_section(section):
            for key in ("domains", "nssets", "keysets"):
                try:
                    setattr(self, key, conf.getint(section, key))
                except ConfigParser.NoOptionError, msg:
                    pass # use default defined above when the limit is not in the config

        # Object interfaces
        self.contact = ContactInterface(database, logger)
        self.domain = DomainInterface(database, logger, list_domains_limit)
        self.nsset = NssetInterface(database, logger, list_nssets_limit)
        self.keyset = KeysetInterface(database, logger, list_keysets_limit)

        logger.log(logger.DEBUG, "Object DomainBrowser initialized.")


    def getDomainList(self, handle):
        """
        RecordSet getDomainList(
            in RegistryObject handle
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        return self.domain.getDomainList(handle)

    def getDomainListMeta(self):
        """
        RecordSetMeta getDomainListMeta()
            raises (INTERNAL_SERVER_ERROR);
        """
        return self.domain.getDomainListMeta()

    def getNssetList(self, handle):
        """
        RecordSet getNssetList(
            in RegistryObject handle
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        return self.nsset.getNssetList(handle)

    def getNssetListMeta(self):
        """
        RecordSetMeta getNssetListMeta()
            raises (INTERNAL_SERVER_ERROR);
        """
        return self.nsset.getNssetListMeta()

    def getKeysetList(self, handle):
        """
        RecordSet getKeysetList(
            in RegistryObject handle
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        return self.keyset.getKeysetList(handle)

    def getKeysetListMeta(self):
        """
        RecordSetMeta getKeysetListMeta()
            raises (INTERNAL_SERVER_ERROR);
        """
        return self.keyset.getKeysetListMeta()

    def getDomainsForKeyset(self, handle, keyset):
        """
        RecordSet getDomainsForKeyset(
            in RegistryObject handle,
            in RegistryObject keyset
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, OBJECT_NOT_EXISTS, USER_NOT_EXISTS);
        """
        return self.domain.getDomainsForKeyset(handle, keyset)

    def getDomainsForKeysetMeta(self):
        """
        RecordSetMeta getDomainsForKeysetMeta()
            raises (INTERNAL_SERVER_ERROR);
        """
        return self.domain.getDomainsForKeysetMeta()

    def getDomainsForNsset(self, handle, nsset):
        """
        RecordSet getDomainsForNsset(
            in RegistryObject handle,
            in RegistryObject nsset
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, OBJECT_NOT_EXISTS, USER_NOT_EXISTS);
        """
        return self.domain.getDomainsForNsset(handle, nsset)

    def getDomainsForNssetMeta(self):
        """
        RecordSetMeta getDomainsForNssetMeta()
            raises (INTERNAL_SERVER_ERROR);
        """
        return self.domain.getDomainsForNssetMeta()

    def getContactDetail(self, handle):
        """
        ContactDetail getContactDetail(
            in RegistryObject handle,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        return self.contact.getContactDetail(handle)

    def getNssetDetail(self, handle, nsset):
        """
        NSSetDetail getNssetDetail(
            in RegistryObject handle,
            in RegistryObject nsset,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, OBJECT_NOT_EXISTS, USER_NOT_EXISTS);
        """
        return self.nsset.getNssetDetail(handle, nsset)

    def getDomainDetail(self, handle, domain):
        """
        DomainDetail getDomainDetail(
            in RegistryObject handle,
            in RegistryObject domain,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, OBJECT_NOT_EXISTS, USER_NOT_EXISTS);
        """
        return self.domain.getDomainDetail(handle, domain)

    def getKeysetDetail(self, handle, keyset):
        """
        KeysetDetail getKeysetDetail(
            in RegistryObject handle,
            in RegistryObject keyset,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, OBJECT_NOT_EXISTS, USER_NOT_EXISTS);
        """
        return self.keyset.getKeysetDetail(handle, keyset)

    def setContactDiscloseFlags(self, handle, flags):
        """
        void setContactDiscloseFlags(
            in RegistryObject handle,
            in ContactDiscloseFlags flags
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, ACCESS_DENIED);
        """
        return self.contact.setContactDiscloseFlags(handle, flags)

    def setObjectBlockStatus(self, handle, objects, block):
        """
        void setObjectBlockStatus(
            in RegistryObject handle,
            in RegistryObjectSeq objects,
            in ObjectBlockType block
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS, ACCESS_DENIED);
        """
        return self.domain.setObjectBlockStatus(handle, objects, block)



def init(logger, db, conf, joblist, corba_refs):
    """
    Function which creates, initializes and returns servant DomainBrowser.
    """
    servant = DomainBrowserServerInterface(logger, db, conf, joblist, corba_refs)
    return servant, "DomainBrowser"
