CHANGELOG
=========

2.15.1 (2022-03-01)
-------------------

* Fix rpm build

2.15.0 (2021-10-01)
-------------------

* Add possibility to disable e-mail sending procedure (``sendperiod=0``)

2.14.0 (2021-08-11)
-------------------

* PyGreSQL >= 5 support

* Fix python hashbangs

2.13.1 (2020-01-31)
-------------------

* Fix rpm for RHEL8 and F31

2.13.0 (2019-11-26)
-------------------

* Use setuptools for distribution

2.12.1 (2019-06-27)
-------------------

* Fix rpm build

2.12.0 (2019-03-18)
-------------------

* License GNU GPLv3+

2.11.1 (2019-02-11)
-------------------

* Add systemd service for fedora package

2.11.0 (2018-11-20)
-------------------

* COPR build

* AUTHORS file update

2.9.0 (2018-01-16)
-------------------

* Static IDL for python (precompiled)

2.8.0 (2017-03-02)
-------------------

* Configuration files documentation

* Fedora packaging

2.7.3 (2017-03-30)
------------------

* replace usage of user-defined aggregate function array_accum with built-in array_agg

2.7.2 (2016-03-21)
------------------

* Fix rpm build

* Removed unused idl references in setup.py

2.7.1 (2015-08-26)
------------------

* fix techcheck - glue test

* fix techcheck scripts - enable edns (tc responses)

* genzone - support for sha256 digest algorithm for ds records

2.7.0 (2015-01-27)
------------------

* domain browser code removed

* techcheck - regular check query optimization

* mailer - add support for idn

2.6.2 (2015-01-13)
------------------

* fix zone generator - ip address type resolution

2.6.1 (2014-08-01)
------------------

* removed domain browser from default modules

* m2crypto dependency fixes

2.6.0 (2014-02-13)
------------------

* Mail default header is now controlled by mail type

* Support for multiple signing certificates (distinguished by sender e-mail address)

2.5.3 (2014-02-17)
------------------

* Fix rpm dependencies

2.5.2 (2013-11-06)
------------------

* Fix genzone - glue records generation

* Fix domain browser

  * date time format fix reverted (fixed in web app)

  * registrar address formating

  * domain detail public/private data recognition (handle -> id fix)

2.5.1 (2013-09-12)
------------------

* Fix logging of job name (job_noop issue)

2.5.0 (2013-08-14)
------------------

* domain browser - implementation of idl interface

2.4.4 (2013-07-29)
------------------

* Fix fedora rpm package build

2.4.3 (2013-06-27)
------------------

* Removed hardcoded mail type priorities - now loaded from database

2.4.2 (2013-04-24)
------------------

* Temporary enhancement for email sending - hardcoded mail type priorities

2.4.1 (2012-10-18)
------------------

* Fix installation of additional directories

2.4.0 (2012-09-06)
------------------

* Whitespace normalization and PEP8-ification

* Update due to distutils changes (setup.cfg)

* Mailer - email type penalization code simplified

* Optional PID file

* Configure option for number of wait round for external mail signing command

2.3.1 (2012-07-13)
------------------

* add more debug logging to pyfred main loop

2.3.0 (2012-05-14)
------------------

* Mailer - add support for IMAP SSL

2.2.2 (2011-06-02)
-----------------------------

* Mailer - little tweak to not loose one send period because of penalized
  mail types when no other mail types are ready to send

2.2.1 (2011-05-30)
------------------

* Mailer - bugfixed list of attachments

2.2.0 (2011-05-23)
------------------

* Mailer

  * new approach for selecting emails ready to send

  * fixed connection handling in mailNotify method

* fixing dnssec technical test - new version of ldns drill utility

2.1.9 (2009-11-09)
------------------

* Fixed configuration defaults (logging option)

* Technical tests now notify only newest state (history) of nsset
  (parallel nsset of different states fix)

* Fixed email signing procedure - exception type changed

2.1.8 (2009-07-09)
------------------

* Fixes in mail module to properly update number of attempts (sending mails)

* External processes is now executed with common 'runCommand' method with timeout settings

* Fixes in installation procedure, implemented --no-check-deps for
  disabling of checking dependencies

* Removed use of _quote() method from pygresql library - due to changes in
  pygresql-4.0

* Logging system rewritten to support different handlers -
  syslog/file/console (using logging python module)

* Bugfix in configuration template

2.1.7 (2009-07-03)
------------------

* Bugfixes for previous release (last was quite broken)

  * install procedure

  * dnssec test - more error handling

2.1.6 (2009-06-24)
------------------

* Test for dnssec key chain of trust added. Test uses drill utility (this
  add new dependency to project).
  Test copy current approach, but changes was needed:

  * __dbGetAssocDomains(...) now return dictionary where key is fqdn of
    domain, value is True/False flag defining if there is a keyset
    associated with domain (we need test only this domains)
  * in database table ``check_test`` new value (3) is used in need_domain
    column determining that test needs only signed domains on standard
    input

* New configuration options:

  * drill binary executable

  * trust anchor key file

2.1.5 (2009-03-14)
------------------

* Bugfix in sending emails from tech check module - it generated invalid
  corba request because of empty list of email addresses.

2.1.4 (2009-03-26)
------------------

* When marking emails as undelivered, response is saved using base64
  encoding (due to SQL errors when non-utf8 response was delivered).
  Old data must be migrated:
  UPDATE mail_archive SET response = encode(convert_to(response, 'UTF8'),
  'base64')

2.1.3 (2009-02-10)
------------------

* Adding few log messages to debug memory consumtion

2.1.2 (2008-11-10)
------------------

* Little fix in installation procedure

  * MANIFEST.in updated

2.1.1 (2008-11-08)
------------------

* Renaming

  * pyfred_server -> fred-pyfred

  * genzone_test -> check_pyfred_genzone

2.1.0 (2008-10-19)
------------------

* Adding DS generation from DNSKEY records

2.0.1 (2008-09-18)
------------------

* Fixing zone generator

  * syntax error

  * DS record generation didn't work

2.0.0 (2008-08-14)
------------------

* DNSSEC implementation. Keysets attached to domains are transformed
  into DS records.

* Zone generation enahncement. Now It's possible to generate zonefile for
  all zones managed by registry. This is now default when no zone is
  specified either on command line or in config file. New option for
  genzone_client 'bind_conf' allow generate sample configuration file
  for bind.

* Default sample configuration file updated to allow mentioned multi
  zone generation

1.9.3 (2008-07-09)
------------------

* Bugfix in long option handling of filemanager_client

1.9.2 (2008-07-09)
------------------

* Bugfix in technical checks

  * existence script badly handled names of nonresolvable nameservers

  * mail template for existence had bug in test for techcheck name

1.9.0 (2008-06-20)
------------------

* Refactoring installation process into separate directory freddist

2008-04-18
----------

* IDL files are now created automatically during
  install step. IDL files are searched in directory which
  location depends on PREFIX variable.

* Added ability to run setup.py outside its directory.
  Files that setup.py produced (e.g. python bytecode or
  source distribution packages) are stored in current working
  directory.

* Added some setup command line options (e.g. sysconfdir,
  localstatedir) for better output emplacement of corresponding files.

2008-03-28
----------
* Build step 'build_ild' merged into 'build' step.

* pyfred.conf is now teplate, modifiable by options
  passed to setup.py during install phase.

1.8.0 (2008-02-09)
------------------

* RPM building, renaming conf files, change package name to
  fred-pyfred

1.7.6 (2007-11-07)
------------------

* Error in techcheck script existence was corrected. Due to the error
  nameservers which could not be resolved triggered unknown result
  instead of error result.

* Techcheck script existence was improved. Now it performs four
  types of queries in hope that at least one will trigger response
  from server. This gives fairly good results even if we have no domain
  to ask for.

* Not matched DNS servers in heterogenous technical check were not
  treated well.

* Technical test recursive4all was corrected to work for cz
  nameservers as well.

* Basic unittests for techcheck created.

* Mailer produces non-multipart emails if there are no attachments.

* Make sure the database schema is upgraded before starting pyfred.
  Column req_domain was renamed to need_domain and its type was changed.

1.7.5 (2007-10-10)
-----------------------------------

* Techcheck script recursive4all.py is working even for nic.cz domain
  now.

* Error in condition in filemanager_client was corrected.

* Basic unittests for filemanager created.

* build_idl target of setup.py doesn't generate IDL stubs if they
  are already present.

* Email addresses of recipients in mailer, which do not contain
  at-sign are silently discarded.

* Message-ID header in generated emails is saved in database in
  final form. This eliminates problems with incomplete message-id
  or retransmission of same messages with different IDs.

* To multipart emails is not added extra newline before signing,
  because it breaks signature verification in outlook client.

* Check undelivered procedure in mailer rewritten from POP3 to IMAP.
  The name of POP3* configuration directives was changed to IMAP*.

* It is possible to specify IP address where pyfred listens by new
  host configuration directive.

1.7.4 (2007-09-30)
------------------

* File descriptors closing is done better way (before call to wait).
  Credits Ondrej Sury.

* Techchecks were corrected. The situation when DNS server is not
  responding when domain is not in zone delegated on him was not
  expected.

1.7.3 (2007-09-30)
------------------

* Periodical technical checks may be turned off without affecting
  the out-of-order checks (issued over EPP interface). Useful for
  testing.

* Zone generator treated IPv6 address in SOA record as if it was
  IPv4.

* Bug in heterogenous technical test was fixed (missing import).

* Typo in techcheck module introduced in previous tag was corrected.

1.7.2 (2007-09-29)
------------------

* Mailer now closes descriptors when signing emails.

1.7.1 (2007-09-29)
------------------

* Techcheck now closes descriptors after it's childs

* Unittests for genzone are ready.

1.7.0 (2007-09-26)
------------------

* Mailer is capable of checking for undelivered email messages.
  It does so by downloading emails over POP3 protocol from mailbox,
  where are accumulated responses for sent emails. If there is a
  response for sent email, the email is marked in database as
  undelivered. The responses are archived as well.

* Genzone was greatly simplified. It isn't responsible for making
  decision whether domain should be placed in zone or not, based on
  various criteria. Now it simply checks for status 'outzone', which
  is set by another process. As consequence of this the configuration
  directives expiration_hour and safeperiod were cancelled.

* Few bugs in genzone server were corrected. The zone should now be
  more correctly generated than it was before.

* New configuration directive "post-hook" for genzone_client was added.
  It runs arbitrary command after successfull zone file generation.
  It is supersedes "rndc" and "reload" configuration directives, which
  were removed.

* New technical test, which tests requirement for GLUE, was added.
  This test is special, because it is realized directly in techcheck and
  not by external script, and because it influences inputs of all other
  technical tests.

* When doing technical test, the nameserver's fqdn is not resolved,
  if GLUE is present and should be used. All tests were corrected
  in respect to this.

* Changes in techcheck associated with new system for poll messages
  archival.

* Genzone client has new configuration option 'nobackups', which
  disables zone file backups if set to True.

* New script, not directly related to pyfred, in misc directory added.
  It downloads bank transcripts from IMAP mailbox and via
  filemanager_client stores them as files in database.

* In some not very often used scripts were set obsoleted import paths.
  This was fixed.

* New directory unittests was added to repository, but there's nothing
  usable yet.

1.6.3 (2007-09-13)
------------------

* Technical checks are more robust in respect to test script
  freeze-up. Reads are non-blocking and child is killed if it gets
  stuck.

* Error in all domain-dependant techcheck scripts was corrected.
  The results were interpreted as failure, allthough they shouldn't.

1.6.2 (2007-06-14)
------------------

* Bug in zone generator was fixed. GLUE records were generated
  if the nameserver came from the same zone instead of domain. This
  is wrong behaviour.

* The order of build targets in setup.py was fixed.

1.6.1 (2007-06-13)
------------------

* When pyfred_server terminates, references registered by corba
  nameservice when pyfred_server was started are deleted.

* Bug in test for python version in setup.py was fixed.

* Better handling of unexpected exceptions in pyfred_server (they
  are logged and printed to stderr).

* The behaviour of genzone client was modified. If there are no
  zones specified on cmd line, the new 'zones' directive from 'general'
  section from config file is taken into account.

* Critical error in genzone was fixed. The GLUE records were not
  properly generated.

1.6.0 (2007-06-11)
------------------

* Genzone client uses safe method for creating temporary files.

* It is possible to have individual configuration for each generated
  zone by genzone client.

* You can specify header and footer files to genzone client. Those
  files will be prepended and appended to zone file, which is convenient
  for comment insertion.

* pyfred_server creates pid file when it is started. The pidfile is
  named "pyfred.pid" and the directory, where it is created is
  configurable by "piddir" configuration directive.

* pyfredctl is again functional a can be used for controlling
  pyfred_server. However the pid file must be in default path
  /var/run/pyfred.pid in order to work well.

1.5.2 (2007-06-01)
------------------

* genzone client has new configuration file /etc/fred/genzone.conf.

1.5.1 (2007-05-25)
------------------

* Two bugs in techcheck which disabled generation of poll message
  were fixed (mapping of corba boolean to python's boolean and
  accepting negative check levels as if they would mean default level).

1.5.0 (2007-05-20)
------------------

* New mailer idl function resend was implemented. This function
  triggers sending of an email from email archive.

* The bug with empty 'To' header was fixed. If 'To' header is empty
  new exception 'InvalidHeader' is thrown.

* Pyfred server starts now fully daemonized (if run without -d option).
  Daemonization doesn't play very nice with omniorb. In some cases when
  pyfred calls exit, the threads get deadlocked and eat 100% CPU.

* The pyfred is now installed via setup.py (as it is ussuall in python
  world). This change trigered another one - the reorganization of files
  in repository. The layout of project has completely changed.

* Whois module is no longer alive, it was removed because it wasn't
  needed in production and there was no time to maintain it.

* The documentation was rewriten almost from scratch.

1.4.3 (2007-04-24)
------------------

* Critical Bug in pyfred's job scheduler was fixed. The bug
  practically inhibited regularly scheduled jobs.

* Logic of sending an email in Mailer module was splitted
  in two parts. One part accepts requests and does the templating
  and the other part which is run regularly from pyfred's internal
  job scheduler completes emails and sends them.

* Manual confirmation of email submission is now available in
  mailer. This may be used for debugging in production.

* Mailer now tries repeatedly to send email if sendmail fails.
  Maximal number of attempts is configurable by maxattempts
  directive.

1.4.2 (2007-04-05)
------------------

* Postfix adds extra newline after headers when lines terminations
  are mixed together (lf vs. crlf). All lines must have common
  terminator in order for signature to be valid. This was fixed.

1.4.1 (2007-04-04)
------------------

* Signing of emails is done by openssl binary instead of M2Crypto
  library which is not needed anymore. This is a worse solution of
  the signing problem but theres no other way, since outlook doesn't
  like emails signed with M2Crypto.

* VCard attachment is added to each email. This is kind of a hack to
  overcome bug in outlook, which cannot open multipart email composed
  from just one part.

1.4.0 (2007-02-13)
------------------

* TechCheck module is now able to do regular technical checks of
  all registered nssets.

* TechCheck has administration interface which is used for searching
  in archive of executed checks.

* Numerous improvements in check scripts used by techcheck module.

* Email templates now share the same footer. The footer is not
  duplicated in all templates as it was.

* pyfred server has its own start/stop/status script called pyfredctl.

* New attribute 'type' of file is kept about files managed by
  filemanager. Not confuse this new attr 'type' with MIME type,
  which is another attribute of file.

* Mailer signs all sent emails. Signing is accomplished
  by M2Crypto python library, which is wrapper around openssl library.
  Both theese libraries must be installed when running mailer module.

* FileManager was modified to transfer files chunk by chunk in
  sequence. The size of chunk is selectable by client. In princip
  for upload or download of a file is created independent CORBA
  object, which handles transfer of data.

* Documentation is more complete.

1.3.0 (2006-11-24)
------------------

* Over-branding of pyccReg to new name pyfred was done successfully.
  Old name still remains at some places, but those places cannot be
  changed without affecting other parts of registry software.

* The configuration file is no more shared with central register
  written in C++. Pyfred has now its own configuration file name
  pyfred.conf containing sections for individual modules.

* Database connection management is done now by pyfred core and
  not by modules, as it was till now.

* Modules are now able to register jobs (functions) which should
  be run in regular periods. Pyfred core now supports this neat
  feature.

* New module filemanager was created. Filemanager is capable of
  storing files and loading files. As storage backend is used
  filesystem, some meta information about files is kept in database.

* New module mailer, used for sending email notifications, was
  created. It depends on clearsilver templating library.

* Rewrite of genzone module (inspired by new mailer module).
  For each zone transfer is created separate corba object now.

* The concept of safe-interval was implemented in genzone.
  Additionaly all domains, which should not be generated in zonefile
  first time on that day, are excluded after concrete hour, common
  for all domains.

* History of inclusion or exclusion of domain in zone is now kept
  in database together with reason of not being included. The status
  is generated by set of complicated SQL statements (credits Jara).

* Serious bug was fixed in genzone client. For ipv6 addresses
  was not generated record AAAA but same record as for ipv4 addresses.

* Coding of CORBA strings was explicitly set to UTF-8 in server and
  all clients. Different encodings of two ORB endpoints resulted in
  missinterpretation of national characteres.

* Configuration file pyfred_modules.conf was removed, since there
  is no reason for it to exist, when we don't share configuration file
  with C++ central register. Modules which should be loaded are now
  specified in pyfred.conf.

* New modul techcheck for execution of technical checks on nssets
  was created. Scripts realizing individual tests are in subdirectory
  techchecks. In order to be able to run the test scripts, DNS python
  library, fpdns perl script and whois client must be installed
  in the system.

1.2.1 (2006-10-20)
------------------

* The output of genzone client, when running in test mode, was
  modified in order be fulfill expectations of Nagios monitoring tool.

* pyccReg listens on static port since now, because of better
  ability to do firewalling.

1.2.0 (2006-09-27)
------------------

* This ChangeLog was started in order to keep better overview
  of changes. The ChangeLog serves for whole pyccReg project (server
  and clients, etc.).

* All files and directories in repository where reorganized in
  better hierarchy. Makefile was completely rewritten.

* README files where added at places where they were most needed.

* Database change - the column for ip address of primary nameserver
  in table zone_soa was removed. Primary nameserver data are now
  maintained together with other nameservers in table zone_ns.
