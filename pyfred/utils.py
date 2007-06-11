#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
This module gathers various utility functions used in other pyfred's modules.
"""

import time, re

def strtime(timestamp = 0):
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

