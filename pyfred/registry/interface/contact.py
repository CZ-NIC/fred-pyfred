#!/usr/bin/python
# -*- coding: utf-8 -*-

# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import BaseInterface
from pyfred.registry.utils.decorators import furnish_database_cursor_m, \
            normalize_contact_handle_m


class ContactInterface(BaseInterface):
    "Contact corba interface."

    @normalize_contact_handle_m
    @furnish_database_cursor_m
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

        # Dummy answer:
        return Registry.DomainBrowser.ContactDetail(
            id=100,
            handle=handle,

            name='Tester Testovič',
            organization='CZ.NIC s.p.z.o.',
            vat='CZ1234567890',

            street1='U práce 123',
            street2='U testu 789',
            street3='Za bránou 16',
            city='Praha',
            postalcode='12300',
            province='',
            country='CZ',

            telephone='+420.728123456',
            email='pepa.zdepa@nic.cz',
            notify_email='pepa.zdepa+notify@nic.cz',
            fax='+420.728123456',
            ssn='0123456789',
            ssn_type='op',

            roid='C0000000001-CZ',
            registrar='REG-TEST',
            create_registrar='REG-TEST-CREATOR',
            update_registrar='REG-TEST-UPDATER',
            create_date='2012-03-14 10:16:28.516926',
            update_date='2012-03-14 11:26:13.616443',
            transfer_date='2012-03-14 12:36:53.517955',
            status_list = ('testLinked', 'testValidated'), # Registry.DomainBrowser.ObjectStatusSeq

            auth_info='password',
            disclose_flags=Registry.DomainBrowser.ContactDiscloseFlags(
                name=True,
                organization=True,
                email=True,
                address=True,
                telephone=False,
                fax=False,
                ident=False,
                vat=False,
                notify_email=False
            )
        )


    @normalize_contact_handle_m
    @furnish_database_cursor_m
    def setContactDiscloseFlags(self, handle, flags):
        "Dummy setContactDiscloseFlags"
        self.logger.log(self.logger.DEBUG, 'Call ContactInterface.setContactDiscloseFlags(handle="%s", flags=%s)' % (handle, flags))
        # TODO: ...
