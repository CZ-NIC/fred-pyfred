#!/usr/bin/env python
# vim:set ts=4 sw=4:
"""
This module gathers various utility functions used in other modules.
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

def clusterrows(cursor, firstrow, index = 0):
	"""
This is a utility function for grouping of db rows in recursive lists.
Example:
    SQL rows: 1. A B C 11
              2. A B D 11
              3. A E C 56
              4. B G B 01
              ...
    Result when index = 0 is:
[ (A, [ (B, [ (C, [ (11, []) ]), (D, [(11, [])]) ]), (E, [(C, [(56, [])] )] )] )]
    And left over 4th row is returned to be used in next call.
	"""
	cols = len(cursor.description)
	result = []
	# create first recursive list in result set
	list = result
	for col in range(cols - 1):
		if not firstrow[col]: # null values will not be in result set
			break
		list.append( (firstrow[col], []) )
		list = list[-1][1]
	if curr[col]: list.append(firstrow[col])
	# add items in result set untill there are no data or neighbours differ
	# in significant column (which column is significant is defined by index par)
	prev = firstrow
	curr = cursor.fetchone()
	while True:
		if not curr: # no more data?
			break
		for col in range(cols): # get differing column
			if prev[col] != curr[col]:
				break
		if col <= index: # is the column significant
			break
		if prev[col] != curr[col]: # we ignore completly identical rows
			list = result
			for i in range(col): # dive into level, where we should add new item
				list = list[-1][1]
			for col in range(col, cols - 1):
				if not curr[col]: # null values will not be in result set
					break
				list.append( (curr[col], []) )
				list = list[-1][1]
			if curr[col]: list.append( curr[col] )
		prev = curr
		curr = cursor.fetchone()
	return result, curr

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
