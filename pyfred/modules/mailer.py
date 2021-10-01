#!/usr/bin/python2
#
# Copyright (C) 2006-2021  CZ.NIC, z. s. p. o.
#
# This file is part of FRED.
#
# FRED is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# FRED is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FRED.  If not, see <https://www.gnu.org/licenses/>.

"""
Code of mailer daemon.
"""
import base64
import ConfigParser
import email
import email.Charset
import imaplib
import os
import Queue
import random
import re
import sys
import tempfile
import time
from collections import namedtuple
from email import Encoders
from email.MIMEBase import MIMEBase
from email.MIMEMultipart import MIMEMultipart
from email.MIMEText import MIMEText
from email.Utils import formatdate
from exceptions import Exception

import CosNaming
import neo_cgi  # must be included before neo_cs and neo_util
import neo_cs
import neo_util
import pgdb
from fred_idl import ccReg, ccReg__POA

from pyfred.hdf_transform import hdf_to_pyobj, pyobj_to_hdf
from pyfred.utils import decode_utf8, encode_utf8, isInfinite, runCommand

try:
    # certificate info
    import M2Crypto.X509
    import M2Crypto.m2
except ImportError:
    # optional - it is not required when signing is off
    M2Crypto = None


EMAIL_HEADER_CORBA_TO_DICT_MAPPING = {
    "h_to": "To",
    "h_from": "From",
    "h_cc": "Cc",
    "h_bcc": "Bcc",
    "h_reply_to": "Reply-to",
    "h_errors_to": "Errors-to",
    "h_organization": "Organization"
}

IdNamePair = namedtuple('IdNamePair', ['id', 'name'])

EmailData = namedtuple('EmailData', ['id', 'mail_type', 'template_version',
    'header_params', 'template_params', 'attach_file_ids'])

EmailTemplate = namedtuple('EmailTemplate', ['subject', 'body_template', 'body_template_content_type',
    'footer_template', 'template_default_params', 'header_default_params'])

RenderedEmail = namedtuple('RenderedEmail', ['subject', 'body', 'footer'])


class EmailHeadersBuilder(object):

    def __init__(self, header_params, header_defaults=None):
        self._params = header_params
        self._defaults = header_defaults
        self._headers = {}

    def add(self, key, value, func=None):
        value = func(value) if value and func else value
        if value:
            self._headers[key] = value
            return True
        return False

    def add_mandatory(self, key, func=None):
        if not self.add(key, self._params[key], func):
            raise ValueError(key)

    def add_optional(self, key, func=None):
        return self.add(key, self._params.get(key), func)

    def add_optional_or_default(self, key, func=None):
        if not self.add_optional(key, func):
            self.add(key, self._defaults[key], func)

    def to_dict(self):
        return self._headers


class UndeliveredParseError(Exception):
    pass


def contentfilter(mail, ismultipart):
    """
    This routine slightly modifies email in order to prevent unexpected results
    of email signing.
    """
    # tabs might not be preserved during mail transfer
    mail = mail.replace('\t', '        ')
    # add newline at the end if email is not multipart to make outlook
    # - shitty client - happy
    if not ismultipart:
        mail += '\n'
    return mail

def qp_str(string):
    """
    Function checks if the string contains characters, which need to be "quoted
    printable" and if there are any, it will encode the string. This function
    is used for headers of email.
    """
    need = False
    for c in string:
        if email.quopriMIME.header_quopri_check(c):
            need = True
    if need:
        string = email.quopriMIME.header_encode(string, charset="utf-8",
                maxlinelen=None)
    return string


def email_addr_to_idna(addr):
    user, domain = addr.split("@")
    if isinstance(domain, str):
        domain = domain.decode("utf-8").encode("idna")
    elif isinstance(domain, unicode):
        domain = domain.encode("idna")
    else:
        raise TypeError("email_addr_to_idna: expected string or unicode got %s" % type(addr))
    return "%s@%s" % (user, domain)


def filter_email_addrs(str):
    """
    addresses are separated by comma or whitespace, delete any address which
    does not contain at-sign.
    """
    str = str.replace(',', ' ')
    result = ""
    for addr in str.split():
        if addr.find('@') > 0 and not addr.endswith('@'):
            if result: result += ", "
            result += email_addr_to_idna(addr)
    return result

re_mail = re.compile("[-._a-zA-Z0-9]+@[-._a-zA-Z0-9]+")

def smime_sender(certfile):
    """
    from certificate get email addresses of senders that can use the certificate
    for email signing
    """
    sender = set()
    try:
        cert = M2Crypto.X509.load_cert(certfile)
    except:
        return sender
    if not cert.check_purpose(M2Crypto.m2.X509_PURPOSE_SMIME_SIGN, 0):
        return sender

    # searches the subject name ...
    try:
        subj = cert.get_subject()
        mails = subj.get_entries_by_nid(subj.nid['Email'])
        for mail in mails:
            sender.add(mail.get_data().as_text().lower())
    except:
        pass

    # ... and the subject alternative name extension
    try:
        alt_name = cert.get_ext("subjectAltName").get_value()
        mails = re_mail.findall(alt_name)
        for mail in mails:
            sender.add(mail.lower())
    except:
        pass

    return sender


def get_cert_key_pairs(conf, section, logger):
    """
    return array of cert/key pairs
    """
    cert = {}
    for opt in conf.options(section):
        if opt[:8]=="certfile":
            name = opt[8:]
            if not conf.has_option(section, "keyfile" + name):
                logger.log(logger.ERR, "Configuration error: certfile%s has not matching keyfile%s." % (name, name))
                raise Exception("certfile%s has not matching keyfile%s." % (name, name))
            val = cert.get(name, {})
            val['cert'] = conf.get(section, opt)
            if not os.path.isfile(val['cert']):
                logger.log(logger.ERR, "Configuration error: %s=%s does not exist." % (opt, val['cert']))
                raise Exception("%s=%s does not exist." % (opt, val['cert']))
            cert[name] = val
        elif opt[:7]=="keyfile":
            name = opt[7:]
            if not conf.has_option(section, "certfile" + name):
                logger.log(logger.ERR, "Configuration error: keyfile%s has not matching certfile%s." % (name, name))
                raise Exception("keyfile%s has not matching certfile%s." % (name, name))
            val = cert.get(name, {})
            val['key'] = conf.get(section, opt)
            if not os.path.isfile(val['key']):
                logger.log(logger.ERR, "Configuration error: %s=%s does not exist." % (opt, val['key']))
                raise Exception("%s=%s does not exist." % (opt, val['key']))
            cert[name] = val

    pairs = []
    for name in cert:
        val = cert[name]
        pairs.append({'cert':val['cert'], 'key':val['key']})
        logger.log(logger.DEBUG, "Path to certfile%s is %s." % (name, val['cert']))
        logger.log(logger.DEBUG, "Path to keyfile%s is %s." % (name, val['key']))
    return pairs


def get_sender_cert(conf, section, logger):
    """
    return dictionary where key is sender and value is array of cert/key pairs
    that can be used for signing emails
    """
    sender_cert = {}
    cert_key_pairs = get_cert_key_pairs(conf, section, logger)
    for item in cert_key_pairs:
        senders = smime_sender(item['cert'])
        while 0<len(senders):
            sender = senders.pop()
            if sender_cert.has_key(sender):
                sender_cert[sender].append(item)
            else:
                sender_cert[sender] = [item]
            logger.log(logger.DEBUG, "Sender %s use certificate %s and key %s." % (sender, item['cert'], item['key']))
    return sender_cert


class Mailer_i (ccReg__POA.Mailer):
    """
    This class implements Mailer interface.
    """

    class MailerException(Exception):
        """
        Exception used for error signalization in periodic sendmail routine.
        """
        def __init__(self, msg):
            Exception.__init__(self, msg)

    def __init__(self, logger, db, conf, joblist, corba_refs):
        """
        Initializer saves db_pars (which is later used for opening database
        connection) and logger (used for logging).
        """
        # ccReg__POA.Mailer doesn't have constructor
        self.db = db # db object for accessing database
        self.l = logger # syslog functionality
        self.search_objects = Queue.Queue(-1) # list of created search objects
        self.corba_refs = corba_refs # root poa and nameservice reference

        # this avoids base64 encoding for utf-8 messages
        email.Charset.add_charset('utf-8', email.Charset.SHORTEST, None, None)

        # default configuration
        self.testmode = False
        self.tester = ""
        self.sendmail = "/usr/sbin/sendmail"
        self.openssl = "/usr/bin/openssl"
        self.fm_context = "fred"
        self.fm_object = "FileManager"
        self.idletreshold = 3600
        self.checkperiod = 60
        self.signing = False
        self.sender_cert = {}
        self.vcard = ""
        self.sendperiod = 300
        self.sendlimit = 100
        self.archstatus = 1
        self.maxattempts = 3
        self.undeliveredperiod = 0
        self.IMAPuser = "pyfred"
        self.IMAPpass = ""
        self.IMAPserver = "localhost"
        self.IMAPport = 143
        self.IMAPssl = False
        self.signing_cmd_retry_rounds = 8
        # Parse Mailer-specific configuration
        if conf.has_section("Mailer"):
            # testmode
            try:
                self.testmode = conf.getboolean("Mailer", "testmode")
                if self.testmode:
                    self.l.log(self.l.DEBUG, "Test mode is turned on.")
            except ConfigParser.NoOptionError, e:
                pass
            # tester email address
            try:
                tester = conf.get("Mailer", "tester")
                if tester:
                    self.l.log(self.l.DEBUG, "Tester's address is %s." % tester)
                    self.tester = tester
            except ConfigParser.NoOptionError, e:
                pass
            # sendmail path
            try:
                sendmail = conf.get("Mailer", "sendmail")
                if sendmail:
                    self.l.log(self.l.DEBUG, "Path to sendmail is %s." %
                            sendmail)
                    self.sendmail = sendmail
            except ConfigParser.NoOptionError, e:
                pass
            # openssl path
            try:
                openssl = conf.get("Mailer", "openssl")
                if openssl:
                    self.l.log(self.l.DEBUG, "Path to openssl is %s." % openssl)
                    self.openssl = openssl
            except ConfigParser.NoOptionError, e:
                pass
            # filemanager object's name
            try:
                fm_object = conf.get("Mailer", "filemanager_object")
                if fm_object:
                    self.l.log(self.l.DEBUG, "Name under which to look for "
                            "filemanager is %s." % fm_object)
                    fm_object = fm_object.split(".")
                    if len(fm_object) == 2:
                        self.fm_context = fm_object[0]
                        self.fm_object = fm_object[1]
                    else:
                        self.fm_object = fm_object[0]
            except ConfigParser.NoOptionError, e:
                pass
            # check period
            try:
                self.checkperiod = conf.getint("Mailer", "checkperiod")
                self.l.log(self.l.DEBUG, "checkperiod is set to %d." %
                        self.checkperiod)
            except ConfigParser.NoOptionError, e:
                pass
            # idle treshold
            try:
                self.idletreshold = conf.getint("Mailer", "idletreshold")
                self.l.log(self.l.DEBUG, "idletreshold is set to %d." %
                        self.idletreshold)
            except ConfigParser.NoOptionError, e:
                pass
            # signing
            try:
                self.signing = conf.getboolean("Mailer", "signing")
                if self.signing:
                    self.l.log(self.l.DEBUG, "Signing of emails is turned on.")
                    if M2Crypto is None:
                        self.l.log(self.l.ERR, "Signing of emails is turned on, but M2Crypto module was not imported.")
                        raise Exception("M2Crypto module was not found.")
                    # S/MIME certificates
                    try:
                        self.sender_cert = get_sender_cert(conf, "Mailer", self.l)
                    except Exception, e:
                        self.l.log(self.l.ERR, "get_sender_cert failure: %s" % e)
            except ConfigParser.NoOptionError, e:
                pass
            # vcard switch
            try:
                vcard = conf.getboolean("Mailer", "vcard")
                if vcard:
                    self.l.log(self.l.DEBUG, "Vcard attachment enabled.")
                    conn = self.db.getConn()
                    self.vcard = self.__dbGetVcard(conn).strip() + '\n'
                    self.db.releaseConn(conn)
            except ConfigParser.NoOptionError, e:
                pass
            # sendperiod
            try:
                self.sendperiod = conf.getint("Mailer", "sendperiod")
                self.l.log(self.l.DEBUG, "Sendperiod is %d seconds." %
                            self.sendperiod)
            except ConfigParser.NoOptionError, e:
                pass
            # sendlimit
            try:
                self.sendlimit = conf.getint("Mailer", "sendlimit")
                self.l.log(self.l.DEBUG, "Sendlimit is %d emails." %
                            self.sendlimit)
            except ConfigParser.NoOptionError, e:
                pass
            # archstatus alias manualconfirm
            try:
                manconfirm = conf.getboolean("Mailer", "manconfirm")
                if manconfirm:
                    self.l.log(self.l.DEBUG, "Manual confirmation of email "
                                "submission is enabled.")
                    self.archstatus = 2
            except ConfigParser.NoOptionError, e:
                pass
            # maxattempts
            try:
                self.maxattempts = conf.getint("Mailer", "maxattempts")
                self.l.log(self.l.DEBUG, "Maxattempts is set to %d." %
                        self.maxattempts)
            except ConfigParser.NoOptionError, e:
                pass
            # undeliveredperiod
            try:
                self.undeliveredperiod = conf.getint("Mailer",
                        "undeliveredperiod")
                self.l.log(self.l.DEBUG, "Undeliveredperiod is set to %d." %
                        self.undeliveredperiod)
            except ConfigParser.NoOptionError, e:
                pass
            # IMAPuser
            try:
                IMAPuser = conf.get("Mailer", "IMAPuser")
                if IMAPuser:
                    self.l.log(self.l.DEBUG, "IMAPuser is %s" % IMAPuser)
                    self.IMAPuser = IMAPuser
            except ConfigParser.NoOptionError, e:
                pass
            # IMAPpass
            try:
                IMAPpass = conf.get("Mailer", "IMAPpass")
                if IMAPpass:
                    self.l.log(self.l.DEBUG, "IMAPpass is %s" % IMAPpass)
                    self.IMAPpass = IMAPpass
            except ConfigParser.NoOptionError, e:
                pass
            # IMAPserver
            try:
                IMAPserver = conf.get("Mailer", "IMAPserver")
                if IMAPserver:
                    temp = IMAPserver.split(':')
                    if len(temp) == 1:
                        self.IMAPserver = temp[0]
                    else:
                        self.IMAPserver = temp[0]
                        self.IMAPport = int(temp[1])
                        self.l.log(self.l.DEBUG, "IMAPport is %d" %
                                self.IMAPport)
                    self.l.log(self.l.DEBUG, "IMAPserver is %s" %
                            self.IMAPserver)
            except ConfigParser.NoOptionError, e:
                pass
            # IMAPssl
            try:
                self.IMAPssl = conf.getboolean("Mailer", "IMAPssl")
                if self.IMAPssl:
                    self.l.log(self.l.DEBUG, "IMAPssl is turned on.")
            except ConfigParser.NoOptionError, e:
                pass
            try:
                self.signing_cmd_retry_rounds = conf.getint("Mailer", "signing_cmd_retry_rounds")
                self.l.log(self.l.DEBUG, "Signing mail command retry rounds are set to %d." %
                        self.signing_cmd_retry_rounds)
            except ConfigParser.NoOptionError, e:
                pass

        # check configuration consistency
        if self.tester and not self.testmode:
            self.l.log(self.l.WARNING, "Tester configuration directive will "
                    "be ignored because testmode is not turned on.")
        if self.signing and not self.sender_cert:
            raise Exception("Certificate and key file(s) must be set for mailer.")
        # do quick check that all files exist
        if not os.path.isfile(self.sendmail):
            raise Exception("sendmail binary (%s) does not exist." %
                    self.sendmail)
        if self.signing:
            if not os.path.isfile(self.openssl):
                raise Exception("openssl binary (%s) does not exist." %
                        self.openssl)
        # schedule regular cleanup
        joblist.append({ "callback":self.__search_cleaner, "context":None,
            "period":self.checkperiod, "ticks":1 })
        # schedule regular submission of ready emails
        self.mail_type_penalization = {}
        if self.sendperiod > 0:
            joblist.append({ "callback":self.__sendEmails, "context":None,
                "period":self.sendperiod, "ticks":1 })
        # schedule checks for unsuccessfull delivery of emails
        if self.undeliveredperiod > 0:
            joblist.append({ "callback":self.__checkUndelivered, "context":None,
                "period":self.undeliveredperiod, "ticks":1 })
        self.l.log(self.l.INFO, "Object initialized")

    def __search_cleaner(self, ctx):
        """
        Method deletes closed or idle search objects.
        """
        self.l.log(self.l.DEBUG, "Regular maintance procedure.")
        remove = []
        # the queue may change and the number of items in the queue may grow
        # but we can be sure that there will be never less items than nitems
        # therefore we can use blocking call get() on queue
        nitems = self.search_objects.qsize()
        for i in range(nitems):
            item = self.search_objects.get()
            # test idleness of object
            if time.time() - item.lastuse > self.idletreshold:
                item.status = item.IDLE

            # schedule objects to be deleted
            if item.status == item.CLOSED:
                self.l.log(self.l.DEBUG, "Closed search-object with id %d "
                        "destroyed." % item.id)
                remove.append(item)
            elif item.status == item.IDLE:
                self.l.log(self.l.DEBUG, "Idle search-object with id %d "
                        "destroyed." % item.id)
                remove.append(item)
            # if object is active - reinsert the object in queue
            else:
                self.l.log(self.l.DEBUG, "search-object with id %d and type %s "
                            "left in queue." % (item.id, item.__class__.__name__))
                self.search_objects.put(item)

        queue = self.search_objects
        self.l.log(self.l.DEBUG, '%d objects are scheduled to deletion and %d left in queue' % (len(remove), queue.qsize()))

        # delete objects scheduled for deletion
        rootpoa = self.corba_refs.rootpoa
        for item in remove:
            id = rootpoa.servant_to_id(item)
            rootpoa.deactivate_object(id)

    def __sendEmails(self, ctx):
        """
        Method sends all emails stored in database and ready to be sent.
        """
        self.l.log(self.l.DEBUG, "Regular send-emails procedure.")
        conn = self.db.getConn()
        # iterate over all emails from database ready to be sent
        for email_data in self.__dbGetReadyEmailsTypePriority(conn):
            try:
                email_id = email_data.id
                email_text = self.__prepareEmail(conn, email_data)
                # run email through completion procedure
                (mail, efrom) = self.__completeEmail(email_id, email_text, email_data.attach_file_ids)
                # sign email if signing is enabled
                if self.signing:
                    mail = self.__sign_email(email_id, mail)
                # send email
                status = self.__sendEmail(email_id, mail, efrom)
                # check sendmail status
                if status == 0:
                    self.l.log(self.l.DEBUG, "<%d> Email with id %d was successfully sent." % (email_id, email_id))
                    # archive email and status
                    self.__dbUpdateStatus(conn, email_id, 0)
                else:
                    self.l.log(self.l.ERR, "<%d> Sendmail exited with failure for "
                        "email with id %d (rc = %d)" % (email_id, email_id, status))
                    self.__dbSendFailed(conn, email_id)
            except Mailer_i.MailerException, me:
                self.l.log(self.l.ERR, "<%d> Error when sending email with "
                        "mailid %d: %s" % (email_id, email_id, me))
                self.__dbSendFailed(conn, email_id)
            conn.commit()
        self.db.releaseConn(conn)

    def __checkUndelivered(self, ctx):
        """
        Method sends all emails stored in database and ready to be sent.
        """
        self.l.log(self.l.DEBUG, "Regular check-undelivered procedure.")
        # get emails from mailbox
        try:
            if self.IMAPssl:
                server = imaplib.IMAP4_SSL(self.IMAPserver, self.IMAPport)
            else:
                server = imaplib.IMAP4(self.IMAPserver, self.IMAPport)
            server.login(self.IMAPuser, self.IMAPpass)
            server.select()
            # XXX potencial source of error - hardcoded return.nic.cz
            (r, data) = server.search(None, '((UNSEEN) (TO return.nic.cz))')
            mailids = data[0].split(' ')
            if not mailids[0]:
                self.l.log(self.l.DEBUG, "No new undelivered messages.")
                server.close()
                server.logout()
                return
            pattern = re.compile("^[Tt][Oo]:\s+<?(\d+)@return\.nic\.cz.*$")
            self.l.log(self.l.DEBUG, "%d new undelivered messages" % len(mailids))
            conn = None
            for mailid in mailids:
                if not conn:
                    conn = self.db.getConn()
                temp = server.fetch(mailid, "(BODY[HEADER.FIELDS (TO)])")
                to_header = temp[1][0][1].strip()
                m = pattern.match(to_header)
                if m:
                    msgid = int(m.groups()[0])
                    msgbody = server.fetch(mailid, "(RFC822)")[1][0][1]
                    self.l.log(self.l.DEBUG, "Email with ID %d undelivered." %
                            msgid)
                    try:
                        self.__dbSetUndelivered(conn, msgid, msgbody)
                        server.store(mailid, 'FLAGS', '(\Deleted)')
                    except UndeliveredParseError, e:
                        self.l.log(self.l.WARNING, str(e))
                    except ccReg.Mailer.UnknownMailid, e:
                        self.l.log(self.l.WARNING, "Mail with id %s not sent." % e)
                else:
                    self.l.log(self.l.WARNING, "Invalid email identifier found.")
            if conn:
                conn.commit()
                self.db.releaseConn(conn)
            server.expunge()
            server.close()
            server.logout()
        except pgdb.DatabaseError, e:
            self.l.log(self.l.ERR, "Database error: %s" % e)
        except imaplib.IMAP4.error, e:
            self.l.log(self.l.ERR, "IMAP protocol error: %s" % e)

    def __getFileManagerObject(self):
        """
        Method retrieves FileManager object from nameservice.
        """
        # Resolve the name "fred.context/FileManager.Object"
        name = [CosNaming.NameComponent(self.fm_context, "context"),
                CosNaming.NameComponent(self.fm_object, "Object")]
        obj = self.corba_refs.nsref.resolve(name)
        # Narrow the object to an ccReg::FileManager
        filemanager_obj = obj._narrow(ccReg.FileManager)
        return filemanager_obj

    def __dbGetVcard(self, conn):
        """
        Get vcard attachment from database.
        """
        cur = conn.cursor()
        cur.execute("SELECT vcard FROM mail_vcard")
        vcard = cur.fetchone()[0]
        cur.close()
        return vcard

    def __generateHeaders(self, email_data, email_tmpl, subject):
        """
        Generate e-mail headers - text headers unquoted
        """
        try:
            headers = EmailHeadersBuilder(email_data.header_params, email_tmpl.header_default_params)
            headers.add_mandatory("Message-ID")
            headers.add_mandatory("To", func=filter_email_addrs)
            headers.add_optional("Cc", func=filter_email_addrs)
            headers.add_optional("Bcc", func=filter_email_addrs)
            headers.add_optional_or_default("From")
            headers.add_optional_or_default("Reply-to")
            headers.add_optional_or_default("Errors-to")
            headers.add_optional_or_default("Organization")
            headers.add("Subject", subject)

            self.l.log(self.l.DEBUG, "Generated headers: {}".format(headers.to_dict()))
            return headers.to_dict()
        except (ValueError, KeyError) as e:
            raise Mailer_i.MailerException("Invalid header - {}".format(str(e.args[0])))

    def __dbNewEmailId(self, conn):
        """
        Get next available ID of email. This ID is used in message-id header and
        when archiving email.
        """
        cur = conn.cursor()
        cur.execute("SELECT nextval('mail_archive_id_seq')")
        id = cur.fetchone()[0]
        cur.close()
        return int(id)

    def __dbArchiveEmail(self, conn, mailid, mailtype, header, data, handles,
            attachs=[]):
        """
        Method archives email in database.
        """
        cur = conn.cursor()
        cur.execute(
            "SELECT mhd.h_messageidserver"
             " FROM mail_template mtmpl"
             " JOIN mail_type mt ON mt.id = mtmpl.mail_type_id"
             " JOIN mail_header_default mhd on mhd.id = mtmpl.mail_header_default_id"
            " WHERE mt.name = %s AND version = get_current_mail_template_version(mt.id)"
            " FOR SHARE OF mtmpl",
            (mailtype,)
        )
        if cur.rowcount != 1:
            raise ccReg.Mailer.InternalError("cannot fetch 'messageidserver' from database")

        messageidserver = cur.fetchone()[0]
        message_id = "<%d.%d@%s>" % (mailid, int(time.time()), messageidserver)
        header["Message-ID"] = message_id
        params_dict = {'header': header, 'body': data}

        cur = conn.cursor()
        # save the generated email
        cur.execute("INSERT INTO mail_archive (id, status, mail_type_id, message_params) "
                "VALUES (%d, %d, (SELECT id FROM mail_type WHERE name = %s), %s)",
                [mailid, self.archstatus, mailtype, pgdb.Json(params_dict)])
        for handle in handles:
            cur.execute("INSERT INTO mail_handles (mailid, associd) VALUES "
                    "(%d, %s)", [mailid, handle])
        for attachid in attachs:
            cur.execute("INSERT INTO mail_attachments (mailid, attachid) VALUES"
                    " (%d, %s)", [mailid, attachid])
        cur.close()

    def __dbGetReadyEmailsTypePriority(self, conn):
        """
        Get all emails from database which are ready to be sent.
        """
        self.l.log(self.l.DEBUG, "search for ready messages using mail type priority")

        cur = conn.cursor()
        cur.execute(
            "SELECT mar.id, mt.id, mt.name, mar.mail_template_version,"
                  " mar.message_params->'header', COALESCE(mar.message_params->'body', '{}'::JSONB),"
                  " array_filter_null(array_agg(mat.attachid)), mtp.priority"
             " FROM mail_archive mar"
             " JOIN mail_type mt ON mt.id = mar.mail_type_id"
             " LEFT JOIN mail_attachments mat ON (mar.id = mat.mailid)"
             " LEFT JOIN mail_type_priority mtp ON mtp.mail_type_id = mar.mail_type_id"
            " WHERE mar.status = 1 AND mar.attempt < %d"
            " GROUP BY mar.id, mt.id, mt.name, mtp.priority"
            " ORDER BY mtp.priority ASC NULLS LAST"
            " LIMIT %d",
            [self.maxattempts, self.sendlimit])
        rows = cur.fetchall()
        cur.close()
        prio_stats = {}
        result = []
        for msg_id, msg_type_id, msg_type_name, tmpl_version, header_params, tmpl_params, attach_ids, prio in rows:
            mail_type = IdNamePair(msg_type_id, msg_type_name)
            result.append(
                EmailData(msg_id, mail_type, tmpl_version, header_params, tmpl_params, attach_ids)
            )
            prio_stats[prio] = prio_stats.get(prio, 0) + 1

        self.l.log(self.l.DEBUG, "mail type priority distribution: %s" % str(prio_stats))
        return result

    def __dbUpdateStatus(self, conn, mailid, status, reset_counter=False):
        """
        Set status value in mail archive. Meaning of status values are:

          0: Mail was successfully sent.
          1: Mail is ready to be sent.
          2: Mail waits for manual confirmation.
          3: This email will not be sent or touched by mailer.
          4: Delivery of email failed.

        If reset_counter is true, then counter of unsuccessfull sendmail
        attempts is set to 0.
        """
        cur = conn.cursor()
        if reset_counter:
            cur.execute("UPDATE mail_archive "
                    "SET status = %d, moddate = now(), attempt = 0 "
                    "WHERE id = %d", [status, mailid])
        else:
            cur.execute("UPDATE mail_archive "
                    "SET status = %d, moddate = now() "
                    "WHERE id = %d", [status, mailid])
        if cur.rowcount != 1:
            raise ccReg.Mailer.UnknownMailid(mailid)
        cur.close()

    def __dbSetUndelivered(self, conn, mailid, mail):
        """
        Set status value and save interesting keys from response header
        """
        RESPONSE_HEADER_KEYS = ("To", "Date", "Action", "Status", "Subject", "Remote-MTA",
            "Reporting-MTA", "Diagnostic-Code", "Final-Recipient")

        response_header = {}
        for key in RESPONSE_HEADER_KEYS:
            match = re.search("\n{}: (.*?)\n".format(key), mail)
            if match and len(match.groups()) == 1:
                response_header[key] = match.groups()[0].strip()

        self.l.log(self.l.DEBUG, "Undelivered e-mail id={} collected response header={}".format(
            mailid, response_header
        ))
        if not response_header:
            raise UndeliveredParseError("Undelivered response parse error, header empty?! (id={})".format(mailid))

        cur = conn.cursor()
        cur.execute("UPDATE mail_archive "
                "SET status = 4, moddate = now(), response_header = %s "
                "WHERE id = %d", [pgdb.Json(response_header), mailid])
        if cur.rowcount != 1:
            raise ccReg.Mailer.UnknownMailid(mailid)
        cur.close()

    def __dbSendFailed(self, conn, mailid):
        """
        Increment counter of failed attempts to send email.
        """
        cur = conn.cursor()
        cur.execute("UPDATE mail_archive "
                "SET attempt = attempt + 1, moddate = now() "
                "WHERE id = %d", [mailid])
        cur.close()

    def __dbGetEmailTemplate(self, conn, mail_type_id, version):
        """
        Retrieve email template and it's defaults for specified version
        """
        cur = conn.cursor()
        cur.execute(
            "SELECT mt.subject, mt.body_template, mt.body_template_content_type, mtf.footer, mtd.params,"
                  " json_build_object("
                        "'From', mhd.h_from,"
                       " 'Reply-to', mhd.h_replyto,"
                       " 'Errors-to', mhd.h_errorsto,"
                       " 'Organization', mhd.h_organization,"
                       " 'messageidserver', mhd.h_messageidserver)"
             " FROM mail_template mt"
             " JOIN mail_template_footer mtf ON mtf.id = mt.mail_template_footer_id"
             " JOIN mail_template_default mtd ON mtd.id = mt.mail_template_default_id"
             " JOIN mail_header_default mhd ON mhd.id = mt.mail_header_default_id"
            " WHERE mail_type_id = %d AND version = %d",
             [mail_type_id, version]
        )
        if cur.rowcount != 1:
            raise ccReg.Mailer.InternalError()

        subject, body_tmpl, body_tmpl_ctt, footer_tmpl, tmpl_default_params, header_defaults = cur.fetchone()
        return EmailTemplate(subject, body_tmpl, body_tmpl_ctt, footer_tmpl, tmpl_default_params, header_defaults)

    def __dbGetMailTypes(self, conn):
        """
        Get mapping between ids and names of mailtypes.
        """
        cur = conn.cursor()
        cur.execute("SELECT id, name FROM mail_type")
        result = cur.fetchall()
        cur.close()
        return result

    def __completeEmail(self, mailid, mail_text, attachs):
        """
        Method attaches base64 attachments, few email headers to email message.
        """
        # Create email object and init headers
        msg = email.message_from_string(mail_text)

        filemanager = None
        # attach not templated attachments (i.e. pdfs)
        for attachid in attachs:
            # initialize filemanager if it is first iteration
            if not filemanager:
                try:
                    filemanager = self.__getFileManagerObject()
                except CosNaming.NamingContext.NotFound, e:
                    raise Mailer_i.MailerException("Could not get File "
                            "Manager's reference: %s" % e)
                if filemanager == None:
                    raise Mailer_i.MailerException("FileManager reference is "
                            "not filemanager.")
            # get attachment from file manager
            self.l.log(self.l.DEBUG, "<%d> Sending request for attachment with "
                    "id %d" % (mailid, attachid))
            try:
                # get MIME type of attachment
                attachinfo = filemanager.info(attachid)
                # create attachment
                if not attachinfo.mimetype or attachinfo.mimetype.find("/") < 0:
                    # provide some defaults
                    maintype = "application"
                    subtype = "octet-stream"
                else:
                    maintype, subtype = attachinfo.mimetype.split("/")
                part = MIMEBase(maintype, subtype)
                if attachinfo.name:
                    part.add_header('content-disposition', 'attachment',
                            filename=attachinfo.name)
                # get raw data of attachment
                loadobj = filemanager.load(attachid)
                attachdata = ""
                chunk = loadobj.download(2 ** 14) # download 16K chunk
                while chunk:
                    attachdata += chunk
                    chunk = loadobj.download(2 ** 14) # download 16K chunk
                loadobj.finalize_download()
                # encode attachment
                part.set_payload(attachdata)
                Encoders.encode_base64(part)
                msg.attach(part)

            except ccReg.FileManager.IdNotFound, e:
                raise Mailer_i.MailerException("Non-existing id of attachment "
                        "%d given." % attachid)
            except ccReg.FileManager.FileNotFound, e:
                raise Mailer_i.MailerException("For attachment with id %d is "
                        "missing file." % attachid)
            except ccReg.FileDownload.InternalError, e:
                raise Mailer_i.MailerException("Internal error when "
                        "downloading attachment with id %d: %s" %
                        (attachid, e.message))
            except ccReg.FileDownload.NotActive, e:
                raise Mailer_i.MailerException("Download object for attachment "
                        "with id %d is not active anymore: %s" %
                        (attachid, e.message))

        msg["Date"] = formatdate(localtime=True)
        # Message-ID contains the domain part, which is needed in envelope From.
        domain = msg["Message-ID"][(msg["Message-ID"].find('@') + 1):-1]
        envelope_from = "%d@return.%s" % (mailid, domain)
        # parseaddr returns sender's name and sender's address
        return contentfilter(msg.as_string(), msg.is_multipart()), envelope_from

    def __sign_email(self, mailid, mail):
        """
        Routine for signing of email.
        """
        # before signing remove non-MIME headers
        headerend_index = mail.find("\n\n") # find empty line
        headers = mail[:headerend_index + 1]
        mimeheaders = ""
        signedmail = ""
        sender = ""
        # throw away otherwise duplicated headers
        for header in headers.splitlines():
            if header.startswith("MIME-Version:") or \
                    header.startswith("Content-Type:") or \
                    header.startswith("Content-Transfer-Encoding:"):
                mimeheaders += header + '\n'
            else:
                signedmail += header + '\n'
                if header.startswith("From:"):
                    sender = re_mail.search(header[5:]).group(0).lower()
        mail = mimeheaders + mail[headerend_index + 1:]
        if not self.sender_cert.has_key(sender):
            self.l.log(self.l.WARNING, "<%d> Sender %s has no S/MIME certificate." % (mailid, sender))
            return mail
        smime = self.sender_cert[sender][0]
        # create temporary file for openssl which will be used as input
        tmpfile = tempfile.mkstemp(prefix="pyfred-smime")
        os.write(tmpfile[0], mail)
        os.close(tmpfile[0])
        # do the signing
        stat, outdata, errdata = runCommand(mailid, "%s smime -sign -signer %s -inkey %s -in %s" %
                   (self.openssl, smime['cert'], smime['key'], tmpfile[1]), None, self.l, retry_rounds=self.signing_cmd_retry_rounds)
        os.remove(tmpfile[1])

        if stat:
            if errdata:
                err = errdata
            else:
                err = ''
            self.l.log(self.l.ERR, "<%d> Openssl exited with failure (%d): %s" % (mailid, stat, err))
            raise Mailer_i.MailerException("Signing of email failed.")
        signedmail += outdata
        return signedmail

    def __sendEmail(self, mailid, mail, envelope_from):
        """
        This routine sends email.
        """
        # this tranformation guaranties that each line is terminated by crlf
        mail = mail.replace('\r', '')
        mail = mail.replace('\n', '\r\n')

        # send email
        if self.testmode:
            # if tester is not set, do nothing
            if self.tester:
                status, outdata, errdata = runCommand(mailid, "%s -f %s %s" % (self.sendmail, envelope_from, self.tester),
                                                    mail, self.l)
            else:
                status = 0
        else:
            status, outdata, errdata = runCommand(mailid, "%s -f %s -t" % (self.sendmail, envelope_from),
                                                  mail, self.l)

        if status is None: status = 0 # ok
        else: status = int(status) # sendmail failed

        return status

    def __renderEmail(self, email_data, email_tmpl):
        """
        Run e-mail data throught all templates
        """
        # init headers
        hdf = neo_util.HDF()
        # pour defaults in data set
        for key, value in email_tmpl.template_default_params.iteritems():
            hdf.setValue(key, value.encode("utf-8"))
        # pour user provided values in data set
        pyobj_to_hdf(encode_utf8(email_data.template_params), hdf)

        # render subject
        cs = neo_cs.CS(hdf)
        cs.parseStr(email_tmpl.subject)
        subject = cs.render().strip()

        cs = neo_cs.CS(hdf)
        cs.parseStr(email_tmpl.body_template)
        body = cs.render().strip()

        if email_tmpl.footer_template:
            cs = neo_cs.CS(hdf)
            cs.parseStr(email_tmpl.footer_template)
            footer = cs.render().strip()
        else:
            footer = None

        return RenderedEmail(subject, body, footer)


    def __prepareEmail(self, conn, email_data):
        """
        Create e-mail message with headers
        """
        email_tmpl = self.__dbGetEmailTemplate(conn, email_data.mail_type.id, email_data.template_version)
        rendered_data = self.__renderEmail(email_data, email_tmpl)

        # Create email object multi or single part (we have to decide now)
        if len(email_data.attach_file_ids) > 0 or rendered_data.footer or self.vcard:
            msg = MIMEMultipart()
            # render text attachments
            mimetext = MIMEText(rendered_data.body + '\n', email_tmpl.body_template_content_type)
            mimetext.set_charset("utf-8")
            # Leave this commented out, otherwise it duplicates header
            #   Content-Transfer-Encoding
            #Encoders.encode_7or8bit(mimetext)
            msg.attach(mimetext)
            # Add footer if configured so
            if rendered_data.footer:
                mimetext = MIMEText(rendered_data.footer + '\n', email_tmpl.body_template_content_type)
                mimetext.set_charset("utf-8")
                msg.attach(mimetext)
            # Attach vcard attachment if configured so
            if self.vcard:
                mimetext = MIMEText(self.vcard, "x-vcard")
                mimetext.set_charset("utf-8")
                msg.attach(mimetext)
        else:
            # render text attachment
            msg = MIMEText(rendered_data.body + '\n', email_tmpl.body_template_content_type)
            msg.set_charset("utf-8")

        headers = self.__generateHeaders(email_data, email_tmpl, rendered_data.subject)
        # Add headers to message and quote needed values
        for key, value in headers.iteritems():
            if key in ("Subject", "Organization"):
                value = qp_str(value)
            msg[key] = value

        return msg.as_string()

    def mailNotify(self, mailtype, header, data, handles, attachs, preview):
        """
        Method from IDL interface. It runs data through appropriate templates
        and generates an email. The text of the email and operation status must
        be archived in database.
        """
        conn = None
        try:
            id = random.randint(1, 9999)
            self.l.log(self.l.INFO, "<%d> Email-Notification request received "
                    "(preview = %s)" % (id, preview))

            # connect to database
            conn = self.db.getConn()
            # get unique email id (based on primary key from database)
            mailid = self.__dbNewEmailId(conn)

            # convert corba struct into template params dict / json
            hdf = neo_util.HDF()
            for pair in data:
                hdf.setValue(pair.key, pair.value)
            body_dict = hdf_to_pyobj(hdf)
            header_dict = {}
            for corba_attr, dict_key in EMAIL_HEADER_CORBA_TO_DICT_MAPPING.iteritems():
                value = getattr(header, corba_attr)
                if value:
                    header_dict[dict_key] = value

            if preview:
                cur = conn.cursor()
                cur.execute(
                    "SELECT mt.id AS mail_type_id, get_current_mail_template_version(mt.id)"
                     " FROM mail_type mt"
                    " WHERE mt.name = %s",
                    (mailtype,)
                )
                if cur.rowcount != 1:
                    raise ccReg.Mailer.InternalError

                mail_type_id, tmpl_version = cur.fetchone()
                mail_type = IdNamePair(mail_type_id, mailtype)
                email_data = EmailData(mailid, mail_type, tmpl_version, header_dict, body_dict, attachs)
                email_text = self.__prepareEmail(conn, email_data)
                return (mailid, email_text)

            self.__dbArchiveEmail(conn, mailid, mailtype, header_dict, body_dict, handles, attachs)
            # commit changes in mail archive
            conn.commit()

            self.l.log(self.l.DEBUG, "<%d> Email-Notification request saved "
                    "(mailid=%d)" % (id, mailid))
            return (mailid, "")

        except ccReg.Mailer.InternalError, e:
            raise
        except ccReg.Mailer.UnknownMailType, e:
            raise
        except ccReg.Mailer.InvalidHeader, e:
            self.l.log(self.l.ERR, "<%d> Header 'To' is empty." % id)
            raise
        except neo_util.ParseError, e:
            self.l.log(self.l.ERR, "<%d> Error when parsing template: %s" %
                    (id, e))
            raise ccReg.Mailer.InternalError("Template error")
        except pgdb.DatabaseError, e:
            self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
            raise ccReg.Mailer.InternalError("Database error")
        except Exception, e:
            self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
                    (id, sys.exc_info()[0], e))
            raise ccReg.Mailer.InternalError("Unexpected error")
        finally:
            self.db.releaseConn(conn)

    def resend(self, mailid):
        """
        Resend email from mail archive with given id. This includes zeroing of
        counter of unsuccessfull sendmail attempts and setting status to 1.
        """
        try:
            id = random.randint(1, 9999)
            self.l.log(self.l.INFO, "<%d> resend request for email with id = "
                    "%d received." % (id, mailid))

            conn = self.db.getConn()
            self.__dbUpdateStatus(conn, mailid, 1, True)
            conn.commit()
            self.db.releaseConn(conn)

        except ccReg.Mailer.UnknownMailid, e:
            self.l.log(self.l.ERR, "<%d> Unknown mailid %d." % (id, mailid))
            raise
        except pgdb.DatabaseError, e:
            self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
            raise ccReg.Mailer.InternalError("Database error")
        except Exception, e:
            self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
                    (id, sys.exc_info()[0], e))
            raise ccReg.Mailer.InternalError("Unexpected error")

    def getMailTypes(self):
        """
        Return mapping between ids of email types and their names.
        """
        try:
            id = random.randint(1, 9999)
            self.l.log(self.l.INFO, "<%d> get-mailtypes request received." % id)

            # connect to database
            conn = self.db.getConn()
            codelist = self.__dbGetMailTypes(conn)
            self.db.releaseConn(conn)
            return [ ccReg.MailTypeCode(item[0], item[1]) for item in codelist ]

        except pgdb.DatabaseError, e:
            self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
            raise ccReg.Mailer.InternalError("Database error")
        except Exception, e:
            self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
                    (id, sys.exc_info()[0], e))
            raise ccReg.Mailer.InternalError("Unexpected error")

    def renderMail(self, mailid):
        """
        Return rendered e-mail body and subject for given mailid
        """
        try:
            id = random.randint(1, 9999)
            self.l.log(self.l.INFO, "<%d> e-mail content rendering request received. (id=%d)" % (id, mailid))

            conn = self.db.getConn()
            cur = conn.cursor()
            cur.execute(
                "SELECT mar.id, mt.id, mt.name, mar.mail_template_version,"
                      " mar.message_params->'header', COALESCE(mar.message_params->'body', '{}'::JSONB)"
                 " FROM mail_archive mar"
                 " JOIN mail_type mt ON mt.id = mar.mail_type_id"
                " WHERE mar.id = %d", (mailid,)
            )
            if cur.rowcount != 1:
                raise ccReg.Mailer.UnknownMailid(mailid)

            msg_id, msg_type_id, msg_type_name, tmpl_version, header_params, tmpl_params = cur.fetchone()
            mail_type = IdNamePair(msg_type_id, msg_type_name)
            email_data = EmailData(msg_id, mail_type, tmpl_version, header_params, tmpl_params, None)

            email_tmpl = self.__dbGetEmailTemplate(conn, email_data.mail_type.id, email_data.template_version)
            rendered_data = self.__renderEmail(email_data, email_tmpl)
            headers = self.__generateHeaders(email_data, email_tmpl, rendered_data.subject)
            self.db.releaseConn(conn)

            headers_str = "\n".join([key + ": " + value for key, value in decode_utf8(headers).iteritems()])
            msg = "\n\n".join([headers_str, rendered_data.body.decode("utf-8"), rendered_data.footer.decode("utf-8")])
            return msg.encode("utf-8")
        except ccReg.Mailer.UnknownMailid, e:
            raise
        except pgdb.DatabaseError, e:
            self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
            raise ccReg.Mailer.InternalError("Database error")
        except Exception, e:
            self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" % (id, sys.exc_info()[0], e))
            raise ccReg.Mailer.InternalError("Unexpected error")


    def createSearchObject(self, filter):
        """
        This is universal mail archive lookup function. It returns object
        reference which can be used to access data.
        """
        try:
            id = random.randint(1, 9999)
            self.l.log(self.l.INFO, "<%d> Search create request received." % id)

            # construct SQL query coresponding to filter constraints
            conditions = []
            condvalues = []
            if filter.mailid != -1:
                conditions.append("ma.id = %d")
                condvalues.append(filter.mailid)
            if filter.mailtype != -1:
                conditions.append("ma.mail_type_id = %d")
                condvalues.append(filter.mailtype)
            if filter.status != -1:
                conditions.append("ma.status = %d")
                condvalues.append(filter.status)
            if filter.handle:
                conditions.append("mh.associd = %s")
                condvalues.append(filter.handle)
            if filter.attachid != -1:
                conditions.append("mt.attachid = %d")
                condvalues.append(filter.attachid)
            fromdate = filter.crdate._from
            if not isInfinite(fromdate):
                conditions.append("ma.crdate > '%d-%d-%d %d:%d:%d'" %
                        (fromdate.date.year,
                        fromdate.date.month,
                        fromdate.date.day,
                        fromdate.hour,
                        fromdate.minute,
                        fromdate.second))
            todate = filter.crdate.to
            if not isInfinite(todate):
                conditions.append("ma.crdate < '%d-%d-%d %d:%d:%d'" %
                        (todate.date.year,
                        todate.date.month,
                        todate.date.day,
                        todate.hour,
                        todate.minute,
                        todate.second))
            if filter.fulltext:
                conditions.append("ma.message LIKE '%%\%s%%'")
                condvalues.append(filter.fulltext[1:-1])
            if len(conditions) == 0:
                cond = ""
            else:
                cond = "WHERE (%s)" % conditions[0]
                for condition in conditions[1:]:
                    cond += " AND (%s)" % condition

            # connect to database
            conn = self.db.getConn()
            cur = conn.cursor()

            self.l.log(self.l.DEBUG, "<%d> Search WHERE clause is: %s" %
                    (id, cond))
            # execute MEGA GIGA query :(
            cur.execute("SELECT ma.id, ma.mail_type_id, ma.crdate, ma.moddate, "
                        "ma.status, ma.message_params, mt.attachid, mh.associd "
                    "FROM mail_archive ma "
                    "LEFT JOIN mail_handles mh ON (ma.id = mh.mailid) "
                    "LEFT JOIN mail_attachments mt ON (ma.id = mt.mailid) "
                    "%s ORDER BY ma.id" % cond, condvalues)
            # self.db.releaseConn(conn)
            self.l.log(self.l.DEBUG, "<%d> Number of records in cursor: %d" %
                    (id, cur.rowcount))

            # Create an instance of MailSearch_i and an MailSearch object ref
            searchobj = MailSearch_i(id, cur, self.l, conn)
            self.search_objects.put(searchobj)
            searchref = self.corba_refs.rootpoa.servant_to_reference(searchobj)
            return searchref

        except pgdb.DatabaseError, e:
            self.l.log(self.l.ERR, "<%d> Database error: %s" % (id, e))
            raise ccReg.Mailer.InternalError("Database error")
        except Exception, e:
            self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
                    (id, sys.exc_info()[0], e))
            raise ccReg.Mailer.InternalError("Unexpected error")


class MailSearch_i (ccReg__POA.MailSearch):
    """
    Class encapsulating results of search.
    """

    # statuses of search object
    ACTIVE = 1
    CLOSED = 2
    IDLE = 3

    def __init__(self, id, cursor, log, conn):
        """
        Initializes search object.
        """
        self.l = log
        self.id = id
        self.cursor = cursor
        self.status = self.ACTIVE
        self.crdate = time.time()
        self.lastuse = self.crdate
        self.lastrow = cursor.fetchone()
        self.conn = conn

    def __get_one_search_result(self):
        """
        Fetch one mail from archive. The problem is that attachments and handles
        must be transformed from cursor rows to lists.
        """
        if not self.lastrow:
            return None
        prev = self.lastrow
        curr = self.cursor.fetchone()
        id = prev[0]
        mtid = prev[1]
        crdate = prev[2].isoformat()
        if prev[3]: # moddate may be NULL
            moddate = prev[3].isoformat()
        else:
            moddate = ""
        if prev[4] == None: # status may be NULL
            status = -1
        else:
            status = prev[4]
        message = prev[5]
        if prev[6]: # attachment may be NULL
            attachs = [prev[6]]
        else:
            attachs = []
        if prev[7]: # handle may be NULL
            handles = [prev[7]]
        else:
            handles = []
        # process all rows with the same id
        while curr and id == curr[0]: # while the ids are same
            if curr[6]:
                if curr[6] not in attachs:
                    attachs.append(curr[6])
            if curr[7]:
                if curr[7] not in handles:
                    handles.append(curr[7])
            curr = self.cursor.fetchone() # move to next row
        # save leftover
        self.lastrow = curr
        return id, mtid, crdate, moddate, status, message, handles, attachs

    def getNext(self, count):
        """
        Get result of search.
        """
        try:
            self.l.log(self.l.INFO, "<%d> Get search results request received." %
                    self.id)

            # check count
            if count < 1:
                self.l.log(self.l.WARNING, "Invalid count of domains requested "
                        "(%d). Default value (1) is used." % count)
                count = 1

            # check status
            if self.status != self.ACTIVE:
                self.l.log(self.l.WARNING, "<%d> Search object is not active "
                        "anymore." % self.id)
                raise ccReg.MailSearch.NotActive()

            # update last use timestamp
            self.lastuse = time.time()

            # get 'count' results
            maillist = []
            for i in range(count):
                if not self.lastrow:
                    break
                (id, mailtypeid, crdate, moddate, status, message, handles,
                        attachs) = self.__get_one_search_result()
                # create email structure
                maillist.append(ccReg.Mail(id, mailtypeid, crdate, moddate,
                    status, handles, message, attachs))

            self.l.log(self.l.DEBUG, "<%d> Number of records returned: %d." %
                    (self.id, len(maillist)))
            return maillist

        except ccReg.MailSearch.NotActive, e:
            raise
        except Exception, e:
            self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
                    (self.id, sys.exc_info()[0], e))
            raise ccReg.MailSearch.InternalError("Unexpected error")

    def destroy(self):
        """
        Mark object as ready to be destroyed.
        """
        try:
            if self.status != self.ACTIVE:
                self.l.log(self.l.WARNING, "<%d> An attempt to close non-active "
                        "search." % self.id)
                return

            self.status = self.CLOSED
            self.l.log(self.l.INFO, "<%d> Search closed." % self.id)
            # close db cursor
            self.cursor.close()
        except Exception, e:
            self.l.log(self.l.ERR, "<%d> Unexpected exception: %s:%s" %
                    (self.id, sys.exc_info()[0], e))
            raise ccReg.MailSearch.InternalError("Unexpected error")
        finally:
            if self.conn:
                self.conn.close()


def init(logger, db, conf, joblist, corba_refs):
    """
    Function which creates, initializes and returns servant Mailer.
    """
    # Create an instance of Mailer_i and an Mailer object ref
    servant = Mailer_i(logger, db, conf, joblist, corba_refs)
    return servant, "Mailer"
