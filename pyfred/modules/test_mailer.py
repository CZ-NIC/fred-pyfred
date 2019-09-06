#
# Copyright (C) 2017-2018  CZ.NIC, z. s. p. o.
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

import pickle

from pyfred.modules.mailer import Mailer_i


def corba_struct_to_dict(struct):
    ret = {}
    for attr in dir(struct):
        if not attr.startswith('_'):
            ret[attr] = getattr(struct, attr)
    return ret


class TestMailer_i(Mailer_i):

    def __init__(self, logger, db, conf, joblist, corba_refs):
        Mailer_i.__init__(self, logger, db, conf, joblist, corba_refs)
        self.maxstoredcalls = 100
        self.storedcall = []
        if conf.has_section('Mailer'):
            # maxstoredcalls
            try:
                self.maxstoredcalls = conf.getint('Mailer', 'maxstoredcalls')
                if 0 < self.maxstoredcalls:
                    self.storedcall = []
                    self.l.log(self.l.DEBUG, 'Calls are temporarily stored.')
            except ConfigParser.NoOptionError, e:
                pass

    def mailNotify(self, mailtype, header, data, handles, attachs, preview):
        try:
            if 0 < self.maxstoredcalls:
                if mailtype == ':kujme pickle:':
                    result = (0, pickle.dumps(self.storedcall))
                    self.storedcall = []
                    return result
                if len(self.storedcall) < self.maxstoredcalls:
                    d_header = corba_struct_to_dict(header)
                    d_data = [corba_struct_to_dict(key_value_struct) for key_value_struct in data]
                    self.storedcall.append({
                        'method': 'mailNotify',
                        'arguments': {
                            'mailtype': mailtype,
                            'header': d_header,
                            'data': d_data,
                            'handles': handles,
                            'attachs': attachs,
                            'preview': preview
                        }
                    })
                    self.l.log(self.l.DEBUG, str(d_header))
                    self.l.log(self.l.DEBUG, str(d_data))
        except Exception as e:
            self.l.log(self.l.ERR, str(e))
        return Mailer_i.mailNotify(self, mailtype, header, data, handles, attachs, preview)

    def resend(self, mailid):
        try:
            if 0 < self.maxstoredcalls:
                if len(self.storedcall) < self.maxstoredcalls:
                    self.storedcall.append({
                        'method':'resend',
                        'arguments':{'mailid':mailid}})
        except:
            pass
        Mailer_i.resend(self, mailid)

def init(logger, db, conf, joblist, corba_refs):
    """
    Function which creates, initializes and returns servant Mailer.
    """
    # Create an instance of Mailer_i and an Mailer object ref
    servant = TestMailer_i(logger, db, conf, joblist, corba_refs)
    return servant, 'TestMailer'
