#!/usr/bin/python
# -*- coding: utf-8 -*-

# pyfred
from pyfred.idlstubs import Registry
from pyfred.registry.interface.base import BaseInterface
from pyfred.registry.utils.decorators import furnish_database_cursor_m, \
            normalize_object_handle_m


class ContactInterface(BaseInterface):
    "Contact corba interface."

    @furnish_database_cursor_m
    def _create_array_agg(self):
        "Create array_agg() if missing in posgresql."
        results = self.source.fetchall("SELECT * FROM pg_proc WHERE proname = 'array_agg'")
        if not len(results):
            self.source.execute("""
                CREATE AGGREGATE array_agg(anyelement) (
                    SFUNC=array_append,
                    STYPE=anyarray,
                    INITCOND='{}'
                )""")
            self.logger.log(self.logger.INFO, 'Create missing function array_agg().')


    @normalize_object_handle_m
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
        results = self.source.fetchall("""
            SELECT
                oreg.id AS id,
                oreg.name AS handle,
                oreg.roid AS roid,

                current.handle AS registrar,

                oreg.crdate AS create_date,
                obj.trdate AS transfer_date,
                obj.update AS update_date,

                creator.handle AS create_registrar,
                updator.handle AS update_registrar,

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
                contact.disclosenotifyemail

            FROM object_registry oreg
                LEFT JOIN object obj ON obj.id = oreg.id

                LEFT JOIN registrar creator ON creator.id = oreg.crid
                LEFT JOIN registrar current ON current.id = obj.clid
                LEFT JOIN registrar updator ON updator.id = obj.upid

                LEFT JOIN contact ON contact.id = oreg.id
                LEFT JOIN enum_ssntype ssntype ON contact.ssntype = ssntype.id

            WHERE oreg.name = %(handle)s""", dict(handle=handle))

        if len(results) == 0:
            self.logger.log(self.logger.DEBUG, 'Contact of handle "%s" does not exist.' % handle)
            raise Registry.DomainBrowser.USER_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Contact detail of '%s' does not have one record: %s" % (handle, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        status_list = self._get_status_list(handle)

        TID, HANDLE, PASSWORD = 0, 1, 9
        contact_detail = results[0][:-9]
        disclose_flag_values = results[0][len(contact_detail):]

        if contact_detail[HANDLE] == handle:
            # owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PRIVATE_DATA)
        else:
            # not owner
            data_type = Registry.DomainBrowser.DataAccessLevel._item(self.PUBLIC_DATA)
            contact_detail[PASSWORD] = self.PASSWORD_SUBSTITUTION

        columns = ("name", "organization", "email", "address", "telephone", "fax", "ident", "vat", "notify_email")
        disclose_flags = Registry.DomainBrowser.ContactDiscloseFlags(**dict(zip(columns, disclose_flag_values)))

        contact_detail.append(disclose_flags)
        contact_detail.append(status_list)

        # replace None by empty string
        contact_detail = ['' if value is None else value for value in contact_detail]

        columns = ("id", "handle", "roid", "registrar", "create_date", "transfer_date", "update_date",
                   "create_registrar", "update_registrar", "auth_info", "name", "organization",
                   "street1", "street2", "street3", "province", "postalcode", "city", "country",
                   "telephone", "fax", "email", "notify_email", "ssn", "ssn_type", "vat",
                   "disclose_flags", "status_list")
        data = dict(zip(columns, contact_detail))

        return (Registry.DomainBrowser.ContactDetail(**data), data_type)


    @normalize_object_handle_m
    @furnish_database_cursor_m
    def setContactAuthInfoAndDiscloseFlags(self, handle, auth_info, flags):
        "Set contact disclose flags."

        results = self.source.fetchall("""
            SELECT
                contact.id,
                object.authinfopw,
                contact.disclosename,
                contact.discloseorganization,
                contact.discloseemail,
                contact.discloseaddress,
                contact.disclosetelephone,
                contact.disclosefax,
                contact.discloseident,
                contact.disclosevat,
                contact.disclosenotifyemail

            FROM object_registry oreg
                LEFT JOIN contact ON contact.id = oreg.id
                LEFT JOIN object ON oreg.id = object.id

            WHERE oreg.name = %(handle)s""", dict(handle=handle))

        if len(results) == 0:
            raise Registry.DomainBrowser.USER_NOT_EXISTS

        if len(results) != 1:
            self.logger.log(self.logger.CRITICAL, "Contact detail of '%s' does not have one record: %s" % (handle, results))
            raise Registry.DomainBrowser.INTERNAL_SERVER_ERROR

        contact_id = results[0][0]
        contact_auth_info = results[0][1]
        disclose_flag_values = results[0][2:]
        self.logger.log(self.logger.DEBUG, "Found contact ID %d of the handle '%s'." % (contact_id, handle))

        columns = ("name", "organization", "email", "address", "telephone", "fax", "ident", "vat", "notify_email")
        disclose_flags = dict(zip(columns, disclose_flag_values))
        discloses_original = Registry.DomainBrowser.ContactDiscloseFlags(**disclose_flags)
        changes = set(flags.__dict__.items()) - set(discloses_original.__dict__.items())

        sql_auth_info, sql_flags, params = "", "", dict(contact_id=contact_id)

        if contact_auth_info != auth_info:
            sql_auth_info = "UPDATE object SET authinfopw = %(auth_info)s WHERE id = %(contact_id)d"
            params["auth_info"] = auth_info

        if len(changes):
            sql_flags = """
                UPDATE contact SET
                    disclosename = %(name)s,
                    discloseorganization = %(organization)s,
                    discloseemail = %(email)s,
                    discloseaddress = %(address)s,
                    disclosetelephone = %(telephone)s,
                    disclosefax = %(fax)s,
                    discloseident = %(ident)s,
                    disclosevat = %(vat)s,
                    disclosenotifyemail = %(notify_email)s
                WHERE id = %(contact_id)d"""
            params.update(flags.__dict__)

        if sql_auth_info == "" and sql_flags == "":
            self.logger.log(self.logger.DEBUG, 'NO CHANGE of contact[%d] "%s" authinfopw nor disclose flags.' % (contact_id, handle))
            return

        if sql_auth_info:
            self.logger.log(self.logger.INFO, 'CHANGE contact[%d] "%s" auth info.' % (contact_id, handle))
        if sql_flags:
            self.logger.log(self.logger.INFO, 'CHANGE contact[%d] "%s" FROM disclose flags (%s) TO (%s).' % (
                    contact_id, handle,
                    ", ".join(["%s=%s" % item for item in disclose_flags.items()]),
                    ", ".join(["%s=%s" % item for item in changes]))
            )

        self.source.execute("BEGIN TRANSACTION; %s; %s; COMMIT" % (sql_auth_info, sql_flags), params)
        self.logger.log(self.logger.DEBUG, 'Contact[%d] "%s" changed (auth info and disclose flags).' % (contact_id, handle))
