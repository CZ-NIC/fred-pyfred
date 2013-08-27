#!/usr/bin/python
# -*- coding: utf-8 -*-

# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import BaseInterface
from pyfred.registry.utils import none2str
from pyfred.registry.utils.decorators import furnish_database_cursor_m
from pyfred.registry.utils.constants import ENUM_OBJECT_STATES, OBJECT_REGISTRY_TYPES
from pyfred.registry.utils.cursors import TransactionLevelRead


class ContactInterface(BaseInterface):
    "Contact corba interface."

    @furnish_database_cursor_m
    def getObjectRegistryId(self, objtype, handle, source=None):
        "Return ID of object."
        return self._get_handle_id(source, objtype, handle)

    @furnish_database_cursor_m
    def getContactDetail(self, contact, detail, lang, source=None):
        """Return detail of contact.

        struct ContactDetail {
            TID id;
            string handle;
            string roid;
            RegistryReference registrar;
            string create_date;
            string transfer_date;
            string update_date;
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
            string states;
            string state_codes;
        };
        """
        self._verify_user_contact(source, contact)

        detail.lang = lang
        results = source.fetchall("""
            SELECT
                oreg.id AS id,
                oreg.name AS handle,
                oreg.roid AS roid,

                oreg.crdate AS create_date,
                obj.trdate AS transfer_date,
                obj.update AS update_date,

                obj.authinfopw AS auth_info,

                contact.name,
                contact.organization,
                contact.street1,
                contact.street2,
                contact.street3,
                contact.stateorprovince,
                contact.postalcode,
                contact.city,
                contact.country,
                contact.telephone,
                contact.fax,
                contact.email,
                contact.notifyemail,
                contact.ssn,
                ssntype.type AS ssntype,
                contact.vat,

                contact.disclosename,
                contact.discloseorganization,
                contact.discloseemail,
                contact.discloseaddress,
                contact.disclosetelephone,
                contact.disclosefax,
                contact.discloseident,
                contact.disclosevat,
                contact.disclosenotifyemail,

                get_state_descriptions(oreg.id, %(lang)s) AS states,
                current.id AS registrar_id,
                current.handle AS registrar_handle,
                current.name AS registrar_name

            FROM object_registry oreg
                JOIN object obj ON obj.id = oreg.id
                JOIN registrar current ON current.id = obj.clid
                JOIN contact ON contact.id = oreg.id
                LEFT JOIN enum_ssntype ssntype ON contact.ssntype = ssntype.id

            WHERE
                oreg.id = %(object_id)d
                AND oreg.name = %(handle)s
                AND oreg.type = %(type_id)d
                AND oreg.erdate IS NULL
            """, detail.__dict__)

        if len(results) == 0:
            self.logger.log(self.logger.INFO, 'Contact of handle "%s" does not exist.' % detail.handle)
            raise Registry.DomainBrowser.OBJECT_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Contact detail of '%s' does not have one record: %s" % (detail.handle, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        row = results[0]
        registrar_name = none2str(row.pop())
        registrar_handle = none2str(row.pop())
        registrar_id = none2str(row.pop())
        state_codes, state_importance, state_descriptions = self.parse_states(source, row.pop())

        TID, HANDLE, PASSWORD = 0, 1, 6
        contact_detail = row[:-9]
        disclose_flag_values = results[0][len(contact_detail):]

        if contact_detail[HANDLE] == contact.handle:
            # owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PRIVATE_DATA)
        else:
            # not owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PUBLIC_DATA)
            contact_detail[PASSWORD] = self.PASSWORD_SUBSTITUTION

        columns = ("name", "organization", "email", "address", "telephone", "fax", "ident", "vat", "notify_email")
        disclose_flags = Registry.DomainBrowser.ContactDiscloseFlags(**dict(zip(columns, disclose_flag_values)))

        contact_detail.append(state_codes)
        contact_detail.append(state_descriptions)
        contact_detail.append(Registry.DomainBrowser.RegistryReference(registrar_id, registrar_handle, registrar_name))
        contact_detail.append(disclose_flags)

        # replace None by empty string
        contact_detail = ['' if value is None else value for value in contact_detail]

        columns = ("id", "handle", "roid", "create_date", "transfer_date", "update_date",
                   "auth_info", "name", "organization",
                   "street1", "street2", "street3", "province", "postalcode", "city", "country",
                   "telephone", "fax", "email", "notify_email", "ssn", "ssn_type", "vat",
                   "state_codes", "states", "registrar", "disclose_flags")
        data = dict(zip(columns, contact_detail))

        return (Registry.DomainBrowser.ContactDetail(**data), data_type)


    @furnish_database_cursor_m
    def setContactDiscloseFlags(self, contact, flags, request_id, source=None):
        "Set contact disclose flags."
        self._verify_user_contact(source, contact)
        self.owner_has_required_status(source, contact.id, ["validatedContact", "identifiedContact"])
        self.check_if_object_is_blocked(source, contact.id)

        # "name" and "organization" cannot change
        columns = ("email", "address", "telephone", "fax", "ident", "vat", "notify_email")
        for name in flags.__dict__.keys():
            if name not in columns:
                self.logger.log(self.logger.ERROR, "Invalid flag name: '%s'." % name)
                raise Registry.DomainBrowser.INCORRECT_USAGE

        # cannot change flags: contact.disclosename, contact.discloseorganization,
        results = source.fetchall("""
            SELECT
                contact.discloseemail,
                contact.discloseaddress,
                contact.disclosetelephone,
                contact.disclosefax,
                contact.discloseident,
                contact.disclosevat,
                contact.disclosenotifyemail
            FROM contact
            JOIN object_registry oreg ON oreg.id = contact.id
            WHERE contact.id = %(contact_id)d
            FOR UPDATE OF oreg, contact
            """, dict(contact_id=contact.id))

        if len(results) == 0:
            raise Registry.DomainBrowser.USER_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Contact detail %s does not have one record: %s" % (contact, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        disclose_flag_values = results[0]
        disclose_flags = dict(zip(columns, disclose_flag_values))
        discloses_original = Registry.DomainBrowser.UpdateContactDiscloseFlags(**disclose_flags)
        changes = set(flags.__dict__.items()) - set(discloses_original.__dict__.items())

        if not len(changes):
            self.logger.log(self.logger.INFO, 'NO CHANGE of contact[%d] "%s" disclose flags.' % (contact.id, contact.handle))
            return False

        # update contact inside TRANSACTION ISOLATION LEVEL READ COMMITTED
        with TransactionLevelRead(source, self.logger) as transaction:
            self.logger.log(self.logger.INFO, 'CHANGE contact[%d] "%s" FROM disclose flags (%s) TO (%s).' % (
                    contact.id, contact.handle,
                    ", ".join(["%s=%s" % item for item in disclose_flags.items()]),
                    ", ".join(["%s=%s" % item for item in changes]))
            )
            params = dict(contact_id=contact.id)
            params.update(flags.__dict__)
            # "name" and "organization" cannot change:
            # disclosename = %(name)s,
            # discloseorganization = %(organization)s,
            source.execute("""
                UPDATE contact SET
                    discloseemail = %(email)s,
                    discloseaddress = %(address)s,
                    disclosetelephone = %(telephone)s,
                    disclosefax = %(fax)s,
                    discloseident = %(ident)s,
                    disclosevat = %(vat)s,
                    disclosenotifyemail = %(notify_email)s
                WHERE id = %(contact_id)d""", params)
            self._update_history(source, contact.id, contact.handle, "contact", request_id)

        self.logger.log(self.logger.INFO, 'Contact[%d] "%s" changed (disclose flags).' % (contact.id, contact.handle))
        return True


    def setObjectBlockStatus(self, contact_handle, objtype, selections, action):
        "Set object block status."
        return self._setObjectBlockStatus(contact_handle, objtype, selections, action,
            """
            SELECT
                objreg.id,
                objreg.name
            FROM object_registry objreg
            WHERE objreg.id = %(contact_id)d
            """)


    def _object_belongs_to_contact(self, source, contact_id, contact_handle, object_id):
        "Check if object belongs to the contact."
        if contact_id != object_id:
            self.logger.log(self.logger.INFO, "Contact ID %d does not belong to the handle '%s' with ID %d." % (object_id, contact_handle, contact_id))
            raise Registry.DomainBrowser.ACCESS_DENIED


    def _get_history_query(self):
        "Prepare SQL query for copying contact into history."
        return """
        INSERT INTO contact_history (
            historyid,
            id,
            name,
            organization,
            street1,
            street2,
            street3,
            city,
            stateorprovince,
            postalcode,
            country,
            telephone,
            fax,
            email,
            disclosename,
            discloseorganization,
            discloseaddress,
            disclosetelephone,
            disclosefax,
            discloseemail,
            notifyemail,
            vat,
            ssn,
            ssntype,
            disclosevat,
            discloseident,
            disclosenotifyemail
        )
        SELECT
            %(history_id)d,
            id,
            name,
            organization,
            street1,
            street2,
            street3,
            city,
            stateorprovince,
            postalcode,
            country,
            telephone,
            fax,
            email,
            disclosename,
            discloseorganization,
            discloseaddress,
            disclosetelephone,
            disclosefax,
            discloseemail,
            notifyemail,
            vat,
            ssn,
            ssntype,
            disclosevat,
            discloseident,
            disclosenotifyemail
        FROM contact WHERE id = %(object_id)d
        """
