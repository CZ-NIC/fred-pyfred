#!/usr/bin/python
import ConfigParser
from datetime import datetime, timedelta
# pyfred
from pyfred.idlstubs import Registry, Registry__POA
# objects
from pyfred.registry.interface import ContactInterface, DomainInterface, NssetInterface, KeysetInterface
from pyfred.registry.utils.constants import OBJECT_REGISTRY_TYPES



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

        self.contact._create_array_agg() # create array_agg if missing in posgresql.

        logger.log(logger.DEBUG, "Object DomainBrowser initialized.")


    def getDomainList(self, handle):
        """
        RecordSet getDomainList(
            in RegistryObject handle
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getDomainList(handle="%s")' % handle)
        return self.domain.getDomainList(handle)

    def getDomainListMeta(self):
        """
        RecordSetMeta getDomainListMeta()
            raises (INTERNAL_SERVER_ERROR);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getDomainListMeta()')
        return self.domain.getDomainListMeta()

    def getNssetList(self, handle):
        """
        RecordSet getNssetList(
            in RegistryObject handle
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getNssetList(handle="%s")' % handle)
        return self.nsset.getNssetList(handle)

    def getNssetListMeta(self):
        """
        RecordSetMeta getNssetListMeta()
            raises (INTERNAL_SERVER_ERROR);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getNssetListMeta()')
        return self.nsset.getNssetListMeta()

    def getKeysetList(self, handle):
        """
        RecordSet getKeysetList(
            in RegistryObject handle
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getKeysetList(handle="%s")' % handle)
        return self.keyset.getKeysetList(handle)

    def getKeysetListMeta(self):
        """
        RecordSetMeta getKeysetListMeta()
            raises (INTERNAL_SERVER_ERROR);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getKeysetListMeta()')
        return self.keyset.getKeysetListMeta()

    def getDomainsForKeyset(self, handle, keyset):
        """
        RecordSet getDomainsForKeyset(
            in RegistryObject handle,
            in RegistryObject keyset
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, OBJECT_NOT_EXISTS, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getDomainsForKeyset(handle="%s", keyset="%s")' % (handle, keyset))
        return self.domain.getDomainsForKeyset(handle, keyset)

    def getDomainsForKeysetMeta(self):
        """
        RecordSetMeta getDomainsForKeysetMeta()
            raises (INTERNAL_SERVER_ERROR);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getDomainsForKeysetMeta()')
        return self.domain.getDomainsForKeysetMeta()

    def getDomainsForNsset(self, handle, nsset):
        """
        RecordSet getDomainsForNsset(
            in RegistryObject handle,
            in RegistryObject nsset
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, OBJECT_NOT_EXISTS, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getDomainsForNsset(handle="%s", nsset="%s")' % (handle, nsset))
        return self.domain.getDomainsForNsset(handle, nsset)

    def getDomainsForNssetMeta(self):
        """
        RecordSetMeta getDomainsForNssetMeta()
            raises (INTERNAL_SERVER_ERROR);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getDomainsForNssetMeta()')
        return self.domain.getDomainsForNssetMeta()

    def getContactDetail(self, handle):
        """
        ContactDetail getContactDetail(
            in RegistryObject handle,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getContactDetail(handle="%s")' % handle)
        return self.contact.getContactDetail(handle)

    def getNssetDetail(self, handle, nsset):
        """
        NSSetDetail getNssetDetail(
            in RegistryObject handle,
            in RegistryObject nsset,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, OBJECT_NOT_EXISTS, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getNssetDetail(handle="%s", nsset="%s")' % (handle, nsset))
        return self.nsset.getNssetDetail(handle, nsset)

    def getDomainDetail(self, handle, domain):
        """
        DomainDetail getDomainDetail(
            in RegistryObject handle,
            in RegistryObject domain,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, OBJECT_NOT_EXISTS, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getDomainDetail(handle="%s", domain="%s")' % (handle, domain))
        return self.domain.getDomainDetail(handle, domain)

    def getKeysetDetail(self, handle, keyset):
        """
        KeysetDetail getKeysetDetail(
            in RegistryObject handle,
            in RegistryObject keyset,
            out DataAccessLevel auth_result
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, OBJECT_NOT_EXISTS, USER_NOT_EXISTS);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.getKeysetDetail(handle="%s", keyset="%s")' % (handle, keyset))
        return self.keyset.getKeysetDetail(handle, keyset)

    def setContactAuthInfoAndDiscloseFlags(self, handle, auth_info, flags):
        """
        void setContactAuthInfoAndDiscloseFlags(
                in RegistryObject handle,
                in RegistryObject auth_info,
                in ContactDiscloseFlags flags
            ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, ACCESS_DENIED);
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.setContactDiscloseFlags(handle="%s", auth_info="*******", flags=%s)' % (handle, flags))
        return self.contact.setContactAuthInfoAndDiscloseFlags(handle, auth_info, flags)

    def setObjectBlockStatus(self, handle, objtype, objects, block):
        """
        void setObjectBlockStatus(
            in RegistryObject handle,
            in RegistryObject objtype,
            in RegistryObjectSeq objects,
            in ObjectBlockType block
        ) raises (INTERNAL_SERVER_ERROR, INCORRECT_USAGE, USER_NOT_EXISTS, OBJECT_NOT_EXISTS, ACCESS_DENIED);

        enum ObjectBlockType {
            BLOCK_TRANSFER, UNBLOCK_TRANSFER,
            BLOCK_UPDATE, UNBLOCK_UPDATE,
            BLOCK_TRANSFER_AND_UPDATE, UNBLOCK_TRANSFER_AND_UPDATE
        };
        """
        self.logger.log(self.logger.DEBUG, 'Call DomainBrowser.setObjectBlockStatus(handle="%s", objtype="%s", objects=%s, block=%s)' % (handle, objtype, objects, block))

        if objtype not in OBJECT_REGISTRY_TYPES:
            raise Registry.DomainBrowser.INCORRECT_USAGE

        return getattr(self, objtype).setObjectBlockStatus(handle, objtype, objects, block)



def init(logger, db, conf, joblist, corba_refs):
    """
    Function which creates, initializes and returns servant DomainBrowser.
    """
    servant = DomainBrowserServerInterface(logger, db, conf, joblist, corba_refs)
    return servant, "DomainBrowser"
