#!/usr/bin/python
# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import BaseInterface
from pyfred.registry.utils import normalize_and_check_handle
from pyfred.registry.utils.decorators import furnish_database_cursor_m


class ContactInterface(BaseInterface):
    "Contact corba interface."


    def getContactDetail(self, handle):
        """Return detail of contact."

        struct ContactDetail {
            TID id;
            string handle;
            string roid;
            string registrar;
            string create_date;
            string transfer_date;
            string update_date;
            string create_registrar;
            string update_registrar;
            string auth_info;
            string name;
            string organization;
            string street1;
            string street2;
            string street3;
            string province;
            string postalcode;
            string city;
            string country;
            string telephone;
            string fax;
            string email;
            string notify_email;
            string ssn;
            string ssn_type;
            string vat;
            ContactDiscloseFlags disclose_flags;
            ObjectStatusSeq status_list;
        };
        """
        self.logger.log(self.logger.DEBUG, 'Call ContactInterface.getContactDetail(handle="%s")' % handle)
        handle = normalize_and_check_handle(self.logger, handle) # Registry.DomainBrowser.INCORRECT_USAGE
        return Registry.DomainBrowser.ContactDetail(id=0)


    def setContactDiscloseFlags(self, contact, flags):
        "Dummy setContactDiscloseFlags"
        # TODO: ...
