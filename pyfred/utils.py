#!/usr/bin/env python
#
# Copyright (C) 2006-2019  CZ.NIC, z. s. p. o.
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
This module gathers various utility functions used in other pyfred's modules.
"""

import time, re
import sys, os, fcntl, select, time, popen2, signal


def strtime(timestamp=0):
    """
    Convert timestamp to its string reprezentation if argument is not given
    of has zero value. Reprezentation of current time is returned.
    """
    if timestamp == 0:
        timestamp = time.time()
    tm = time.localtime(timestamp)
    res = time.strftime("%Y-%m-%dT%H:%M:%S", tm)
    # ignore seconds and take daylight savings into account
    tzoff = time.altzone // 60
    if tzoff == 0:
        # zulu alias gmt alias utc time
        return res + "Z"
    elif tzoff > 0:
        res += "+"
    else:
        res += "-"
        tzoff = abs(tzoff)
    # convert tz offset in seconds in HH:MM format
    return "%s%02d:%02d" % (res, tzoff // 60, tzoff % 60)

def isExpired(timestamp):
    """
    Returns True if timestamp is older than curent timestamp, otherwise False.
    """
    if timestamp < time.time():
        return True
    return False

def ipaddrs2list(ipaddrs):
    """
    Utility function for converting a string containing ip addresses
    ( e.g. {ip1,ip2,ip3} ) to python list of theese ip adresses. If the
    string of ip adresses contains no ip adresses ( looks like {} ) then
    empty list is returned.
    """
    list = ipaddrs.strip("{}").split(",")
    if list[0] == "": return []
    return list

class domainClass(object):
    """
    Definition of results of domain classification.
    """
    CLASSIC = 0
    ENUM = 1
    BAD_ZONE = 2
    LONG = 3
    INVALID = 4

def classify(fqdn):
    """
    Classify domain name in following categories: classic domain, enum domain,
    bad zone, too long, invalid name. The valid zones are hardcoded in routine.
    """
    if len(fqdn) > 63:
        return domainClass.INVALID
    p = re.compile("^([a-z0-9]([-a-z0-9]*[a-z0-9])?\.)+([a-z]{2,10})$",
            re.IGNORECASE)
    if not p.match(fqdn):
        return domainClass.INVALID
    if re.compile("^.*\.cz$", re.IGNORECASE).match(fqdn):
        if fqdn.count(".") > 1:
            return domainClass.LONG
        return domainClass.CLASSIC
    if re.compile("^.*\.0\.2\.4\.(c\.)?e164\.arpa$", re.IGNORECASE).match(fqdn):
        return domainClass.ENUM
    return domainClass.BAD_ZONE

def isInfinite(datetime):
    """
    Decide if the date is invalid. If it is invalid, it is counted as infinite.
    """
    if datetime.date.month < 1:
        return True
    if datetime.date.day < 1:
        return True
    return False

def makeNonBlocking(fd):
    """
    Set non-blocking attribute on file.
    """
    fl = fcntl.fcntl(fd, fcntl.F_GETFL)
    try:
        fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.O_NDELAY)
    except AttributeError:
        fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.FNDELAY)


def runCommand(id, cmd, stdin, logger, retry_rounds=None):
    """
    Run command in non-blocking manner.
    """
    if retry_rounds is None:
        retry_rounds = 8
    # run the command
    child = popen2.Popen3(cmd, True)
    logger.log(logger.DEBUG, "<%d> Running command '%s', pid %d. (rounds=%d)" %
            (id, cmd, child.pid, retry_rounds))
    if (stdin):
        child.tochild.write(stdin)
    child.tochild.close()
    outfile = child.fromchild
    outfd = outfile.fileno()
    errfile = child.childerr
    errfd = errfile.fileno()
    makeNonBlocking(outfd)
    makeNonBlocking(errfd)
    outdata = errdata = ''
    outeof = erreof = 0
    for round in range(retry_rounds):
        # wait for input at most 1 second
        ready = select.select([outfd, errfd], [], [], 1.0)
        if outfd in ready[0]:
            outchunk = outfile.read()
            if outchunk == '':
                outeof = 1
            else:
                outdata += outchunk
        if errfd in ready[0]:
            errchunk = errfile.read()
            if errchunk == '':
                erreof = 1
            else:
                errdata += errchunk
        if outeof and erreof: break
        logger.log(logger.WARNING, "<%d> Output of command not ready, "
                "waiting (round %d)" % (id, round))
        time.sleep(0.3) # give a little time for buffers to fill

    child.fromchild.close()
    child.childerr.close()

    status = os.waitpid(child.pid, os.WNOHANG)

    if status[0] == 0:
        time.sleep(1)
        logger.log(logger.WARNING, "<%d> Child doesn't want to exit, TERM signal sent." % (id))
        os.kill(child.pid, signal.SIGTERM)
        time.sleep(1.2) # time to exit
        status = os.waitpid(child.pid, os.WNOHANG)

        if status[0] == 0:
            logger.log(logger.WARNING, "<%d> Child doesn't want to die, KILL signal sent." % (id))
            os.kill(child.pid, signal.SIGKILL)
            time.sleep(1.2) # time to exit
            status = os.waitpid(child.pid, os.WNOHANG)

    stat = 2 # by default assume error
    if outeof and erreof and (status[0] == child.pid) and os.WIFEXITED(status[1]):
        stat = os.WEXITSTATUS(status[1])

    return stat, outdata, errdata


def ccRegDateTimeInterval(ccReg, from_date, to_date):
    "Create ccReg.DateTimeInterval"
    try:
        # DateTimeInterval(Date from, Date to)
        interval = ccReg.DateTimeInterval(from_date, to_date)
    except TypeError, msg:
        # TypeError: __init__() takes exactly 5 arguments (3 given)
        # DateTimeInterval(Date from, Date to, type <DateTimeIntervalType>, offset  <short>)
        interval = ccReg.DateTimeInterval(from_date, to_date, ccReg.INTERVAL, 0)
    return interval


def encode_utf8(value):
    """
    Encode value to utf8, works also for nested structures
    """
    if isinstance(value, dict):
        return {encode_utf8(key): encode_utf8(value) for key, value in value.iteritems()}
    elif isinstance(value, list):
        return [encode_utf8(element) for element in value]
    elif isinstance(value, tuple):
        return tuple(encode_utf8(element) for element in value)
    elif isinstance(value, unicode):
        return value.encode('utf-8')
    else:
        return value


def decode_utf8(value):
    """
    Decode value to utf8, works also for nested structures
    """
    if isinstance(value, dict):
        return {decode_utf8(key): decode_utf8(value) for key, value in value.iteritems()}
    elif isinstance(value, list):
        return [decode_utf8(element) for element in value]
    elif isinstance(value, tuple):
        return tuple(decode_utf8(element) for element in value)
    elif isinstance(value, str):
        return value.decode('utf-8')
    else:
        return value
