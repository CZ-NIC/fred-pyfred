=======================================
README file for pyfred server & clients
=======================================

.. toctree::
   :numbered:
   :caption: Table of Contents
   
   Introduction
   Servers' and clients' description
     Filemanager
     Genzone
       Configuration of genzone client
     Mailer
     Techcheck
    Repository overview
    Configuration
    Dependencies
    Testing


Introduction
============

Pyfred is part of FRED system (system for management of internet domains)
and includes various servers and clients both written in python.
In fact there is just one general server which encapsulates specialized
servers, which are often referred to as modules. It is a plugin architecture.
The underlying communication infrastructure is CORBA. Pyfred clients
communicate with servers by RMI paradigm, the interface is specified in
IDL files, which are not part of pyfred's repository, but are centrally
managed elsewhere.


Servers' and clients' description
=================================

There are following servers each of which has at least one client:

 +--------------------+-----------------------------------------+
 |        SERVER      |                     CLIENTS             |
 +====================+=========================================+
 |  filemanager       |          client and admin               |
 +--------------------+-----------------------------------------+
 |  genzone           |          client and test                |
 +--------------------+-----------------------------------------+
 |  mailer            |          client and admin               |
 +--------------------+-----------------------------------------+
 |  techcheck         |          client and admin               |
 +--------------------+-----------------------------------------+

Note: Content of clients column needs some explanation. Almost every interface
      defines two kinds of functions: custom and administrative. Custom
      functions fulfil the purpose of server's existence, it means that
      without these functions there is no reason for server to exist.
      Adminstrative functions constitute completion to normal operation of
      server. They implement more advanced functionality of server. These
      two groups of functions are separated in different files (in different
      clients). Genzone has test client, which is a script intended to be
      used by nagios monitoring software.


Filemanager
-----------

FileManager daemon is capable of storing and loading files. FileManager
stores files on filesystem under directory which is given in configuration.
FileManager does actually more than just storing or loading file. It keeps
some other information about managed files in database. Currently it is:

* Numeric id of file
* Date of creation of record (file's upload date)
* Human readable and friendly name of file
* MIME type of file
* Size of file in bytes
* Path to file on filesystem in repository
* Type of file (one of: invoice pdf, invoice xml, accounting xml,
  banking statement)

This set of information can be retrieved by a corba method call and by
another one can be downloaded the file from server. There is also a function
for upload of a file to server. The files are downloaded and uploaded
in client selected chunks in order not to exceed the data size limit
of one corba call.

It is possible to search files based on various criteria, but true
administration interface capable of deletion and manipulation with files
is not yet in place and is not planned for the near future.

Information about files is kept in database compared to files' content, which
is kept on filesystem. The files on filesystem are not stored in flat manner,
but are distributed in subdirectories in order not to overfill one directory.
The relative path is created as:

    {year}/{month}/{day}/{id}

where year, month and day are deduced from date when the file was uploaded
to server. The name of the file on filesystem, here denoted as id, is
primary key of file's record in database and should not be confused with
alias (human-friendly name of file) which is stored as attribute of file
in database and may not be unique.

There are two clients available for FileManager server. One is capable of
download/upload and the second (administrative) of searching in database
of files.


Genzone
-------

Goal of the zone generator server is to send all data needed for zone
file creation to a client. It is a task of client to format data in a way,
the DNS server understands to. The tasks of server are:

* Generate data which should be in a zone based on status flag
  'outzone'.
* Send resulting data through CORBA interface to client in several
  chunks by how big they are.

Zone generator utilizes results of another process, which sets status' for
objects in database. The zone generator simply picks domains, which don't have
status set to 'outzone'.

These constrains must be met in order for domain to be placed in zone. The list
of conditions here is not complete, since the zonegenerator is not responsible
for checking of these conditions.

* Domain must have associated nsset.
* Domain must not be expired and additionaly if it is an enum domain,
  validation must be still valid. By 'expired' we mean that
  domain is out of safe-period (which is about one month after the
  real expiration date).
* The domain must not have set status 'outZoneManual', it means
  the domain was not manually outaged from zone.

A nameserver which requires GLUE by DNS standard is considered valid
only if it has one. On the other side, if nameserver has a GLUE and the GLUE
is not required, the GLUE is not passed to client but the nameserver is.
Neither of mentioned inconsistencies influences placement or displacement
of a domain in a zone. Only warning messages are logged to syslog.

The client is responsible for formatting of received data in manner which is
acceptable by DNS server.  The only currently availabel output format is a
format of BIND DNS server. Second client script is dedicated solely to testing
of genzone server. Zone generation is so important service that there is a
special need to test, that server is up and running. Output of test script is
compatible with expectations of Nagios monitoring software.  Genzone client
handles also backups of old zone files before they are overwritten by newly
generated zone files. It is possible to configure post-hook for each zone (or
in DEFAULT section for all zones).  Hook is a command which is executed after
the zone is generated.  Genzone performs substitution for following tokens in
hook command line:

$file     absolute path of new generated zone file
$zone     name of zone which is generated
$backup   absolute path of previous (backed up) zone file

The hook is trigered only if the zone file is successfully generated. By this
hook you can conveniently restart a bind server for example.

Zone generation support generation of DS records from server keyset objects
attached to domains.

Configuration of genzone client
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Genzone client is configurable by configuration file. The default location
is /etc/fred/genzone.conf, but you may override this default from command
line. The configuration file may contain individual section for each zone.
Configuration parameters, which are not specific to a zone, are in section
called 'general'. The command line parameters are preferred to values
from configuration file, but beware that options on command line override
configuration of all generated zones. The description of configuration
directives follow.

General configuration directives:

* nameservice [localhost] - Host where is running corba nameservice.

* context [fred] - Corba nameservice context (directory)

* verbose [Off] - If the client should be verbose when generating zones.

* zones [] - Space separated list of zone names to be generated. This
  list is only used, if no zones were specified on command line. If no
  zones are specified at all, list of zones is downloaded from server

Zone specific configuration directives:

* zonedir [./] - Directory where new zone files should be generated.
  Default is current directory.

* backupdir [] - Directory where current zone file from zonedir should
  be backuped before being overwritten by new zone file. Default is
  to use the same directory as zonedir.

* nobackups [False] - It set to True, no backups are created at all
  (backupdir directive is in that case useless).

* chunk [100] - Relates to mechanism of how the records are transfered
  over corba. It means how many domains are transferred in one CORBA
  call.

* header [] - If defined, the content of header file will be prepended
  to zone file.

* footer [] - If defined, the content of footer file will be appended
  to zone file.

* maxchanges [-1] - The maximal number of changed records between the
  new zone file and previous zone file. If The number is negative, it
  means that the is no such a limit. If you prepend '%' character to
  the number, it means procentual change.

Mailer
------

Mailer daemon is responsible for delivering and archiving email messages.
It is a CORBA server with interface consisting of two parts:

1. User interface is one function for sending of emails.
2. Admin interface is a set of functions for mailarchive searching.

Part of configuration is stored in database and part in a configuration file.
Sending of email consists of following steps:

1. Merging client provided mail headers and defaults stored in database.

2. Running dataset provided by client merged with dataset from
   database through templates and subject, both selected according to
   email type. Mail type may contain multiple templates, each template will
   produce one part of multipart email message of MIME type text/*.

3. So far generated email is archived in database in text form together
   with some meta information (creation date, associated handles, ...).
   The email is marked as ready to be sent.

Then there is another process which periodically activated and it does:

1. The email, which is ready to be sent, is read from database.

2. Attachments not intended to be templated are retrieved from file-manager
   daemon, base64-encoded and attached to email message.

3. The whole MIME multipart email message is transformed to text and this
   text is signed. New SMIME email is created.

4. The email is sent by sendmail program. If sendmail is successfull,
   the email in archive is marked as sent otherwise number of attempts
   is incremented.

If email cannot be sent three times in row (configurable), sending of email is
given up.  The signing is done by openssl binary. M2Crypto python library
cannot be used, allthough it would be better solution, because emails signed by
m2crypto cannot be validated in MS Outlook.

Searching of mail archive for an email is based on "filter" and method of
incremental transfers. Filter is a structure which specifies constraints,
which must be fulfilled by email message in order to be chosen for retrieval.
The set of results is then transfered in chunks, of which size can be specified
by client. When all data are transfered or they are not wanted anymore, the
transfer should be closed.

As template system is used clearsilver, which is shared library, which can
be used from C and Python. Clearsilver templates are considerably easier
to use than xslt and at the same time have equal expression capabilities.
Information how to write clearsilver templates can be found at:
http://www.clearsilver.net/docs/man_templates.hdf. We will give just a few
examples, which should be sufficient for 99% of email templates, since
email templates aren't expected to be much complicated.

All substitution commands are enclosed in '<?cs' and '?>'.

  <?cs var:foo ?>    This will output variable 'foo' if it is defined.

  <?cs if:bar ?><?cs var:bar ?><?cs else ?>There is nothing to see<?cs /if ?>
  This is example of condition. If variable 'bar' is True then content of
  it is displayed. Otherwise the text after else is displayed.

The values for variables (in our case 'foo' and 'bar') are provided by
parameter of function for sending email, which is a list of key-value
structures.

Iterations can be done in following way (assuming we have defined myset,
which contains elements, which in turn have attributes key and value):

  <?cs each:item = myset ?>
    Key of element of myset: <?cs var:item.key ?>
    Value of element of myset: <?cs var:item.value ?>
  <?cs /each ?>

There exists a utility which makes working with templates easier. It is the
script template_sucker, which is capable of printing templates stored in
database in well arranged manner and printing of variables used in individual
templates.

As ussually there exist two client utilities for mailer. One is for email
submission and another one is for searching email archive.

Mailer has capability of checking whether an email was delivered successfully
under assumption that remote smtp server sends error message to "envelope
from" address, if something goes wrong. The smtp server responsible for
delivery of emails for domain used in "envelope from" must be aware of
pyfred and deliver these error messages to special mailbox, which is
accessed by mailer module in regular intervals and checked for new emails.
If user part of email address in "To" header matches identifier associated
with sent email archived in database, the email is marked as undelivered.
This process of downloading emails over imap is optional and may be turned
off in configuration file.

Emails in archive may have assigned several status values, which are numbers
from 0 to 4. Here is their meaning:

0 - Mail was successfully sent.

1 - Mail is ready to be sent.

2 - Mail waits for manual confirmation.

3 - This email will not be sent or touched by mailer.

4 - Delivery of email failed.


Techcheck
---------

Techcheck daemon is responsible for testing of nameservers in nsset. There
are two possible ways how to call out technical check.

1. You can do technical check on a single nsset synchronously. It means
   that the caller is blocked until the tests are done and then receives
   results in form of return value from CORBA function.

2. Another way is to do the test of nsset asynchronously. It means
   that server returns from CORBA function as soon as it has found all
   relevant data needed for technical check in database. The registrator
   is informed about results of technical tests in form of a poll message
   over EPP interface.

The technical check consists of several tests. The tests are highly dynamic and
are not hardcoded in source code (except one). The possible tests are defined
in database and when the pyfred starts up, they are read and so called "test
suite" is constructed, which is used in all checks untill the pyfred is
restarted. Test suite is a sequence of technical tests which should be applied
if they are not disabled by certain flag in database. There are a few
attributes of test, the most important is:

* numeric id of test (influences order of test in testsuite)
* name of test
* level of test (this is how the test is detailed, 1..10)
* information about dependency on another test(s)
* a path to script which executes the testing
* flag saying if the test is meaningfull without domain fqdn(s)

Basic schema of technical check is as follows:

1. test is popped from test suite and if the dependencies are satisfied
   and its level is lower or equal to specified level, the test is executed.
   There is one more exception when the test is not executed. It is when the
   test requires a list (possibly containing only one item) of domain fqdns in
   order to be meaningfull, but there are not any fqdns.

2. test is realized by execution of appropriate test script. Robustness
   in respect to potencial script freeze-up is accented. As last option
   is used SIGKILL to end life of child.

3. from return value of the script is deduced status of the test. Three
   values are possible: passed, failed, unknown. Unknown denotes that
   the script failed because of unexpected (unknown) reason or the reason
   is known, but it is not in scope of that particular test.

4. poll message is generated for registrar if the check was submitted
   over EPP interface (asynchronous way) or the caller is informed
   about the results through return value of CORBA function (synchronous
   way).

5. individual results of tests are archived in database.

There are two basic categories of tests. Tests which require list of domain
fqdns and tests which test nameservers as such without need of specific
domain fqdns.

There is also interface accomodating search in executed technical checks.
The interface is pretty similar to search interfaces in other modules ("filter
and search object" model).

In background are continuosly performed technical checks of all registered
nssets. This process is called regular (or periodic) technical checks.
These can be turned of in config file.

There is one special test, which tests necessity of GLUE for nameserver. This
test must be executed as first one, because it transforms a list of ip address
and all other tests use this modified list. All other tests should depend on
this test. This test is exceptional also because it is not executed by external
script but directly in techcheck, though it has a record in database, which
has empty string in 'script' field.


Repository overview
===================

Here we describe what is in which directory and where it is installed.

pyfred directory - is a python package which contains:

* 'zone' module used by genzone client for communication with CORBA server.
* 'utils' module which gathers various functions shared by corba servers.
* 'modules' package which contains modules implementing the CORBA servers.

scripts directory - contains python scripts (pyfred server and all clients)
which are installed in $PATH. There is also start/stop/status pyfredctl
script.

tc_scripts directory - contains scripts, currently only python scripts but
there may be any other scripts, which are used by techcheck server to
test a nameserver. These scripts are not installed in $PATH because they
are not ment to be run from command line, but rather in 
${PREFIX}/libexec/pyfred.

misc directory - contains everything else what didn't fit in any of previous
directories. Currently there is template_sucker.py script, which ease
debugging of mailer templates, and directory mailer_examples contains
prepared data files, which may be used together with mailer client.


Configuration
=============

The pyfred server looks for its configuration file (pyfred.conf) in current
directory, /etc/fred or /usr/local/etc/fred in this order. When starting it
prints, which config file it is using. You can explicitly set configuration
file on command line.

Configuration file is organized in sections. One called General which is not
specific to any CORBA server and influences general behaviour shared by
all CORBA servers, the other sections are dedicated to individual CORBA
servers.

Before we will look at configuration directives in depth, we will explain
meaning of 2 directives which are common for all CORBA servers (it means
they can be set in all sections except section General). It is 'idletreshold'
and 'checkperiod' used to control lifetime of dynamically created CORBA
objects, both accept number of seconds. Every CORBA server has by coincidence
need to spawn new CORBA objects, which are dedicated to one simple task
(i.e. to transfer bytes of file or to transfer a zone records).

* idletreshold [3600] - says how many seconds the object must not be
  accessed by any CORBA method in order to be taken as "death" and will be
  automically deleted.

* checkperiod [60] - is interval in which are checked objects for being idle.

The following rule should hold: checkperiod <= idletreshold.

The sections will be examined in following order:

1. General
2. Genzone
3. Mailer
4. FileManager
5. TechCheck

The default values for directive is enclosed in square brackets. If there is
no default value, the square brackets are missing.

General
-------

* modules - list of modules (CORBA servers) which should be loaded and started.

* dbhost - Database host (empty value means: use unix socket).

* dbport [5432] - Database port (5432 is standard postgresql's port).

* dbuser [fred] - Database username.

* dbpassword - Database password.

* dbname [fred] - Database name to use.

* nshost [localhost] - Host where CORBA nameservice runs.

* nsport [2809] - Port on which CORBA nameservice listens (2809 is standard).

* context [fred] - Corba nameservice context to use for binding objects.
  For example if we select 'fred' context then the object genzone will
  be known by nameservice as: 'fred.context/genzone.object'.

* loglevel [LOG_INFO] - Syslog level used for logging (LOG_DEBUG,
  LOG_NOTICE, LOG_INFO, LOG_WARNING, LOG_ERR, LOG_EMERG, LOG_CRIT).

* logfacility [LOG_LOCAL1] - Syslog facility used for logging (see manual
  page of syslog for possible facilities).

* piddir [/var/run] - Directory where pidfile pyfred.pid is created.

* host [] - IP address or hostname where pyfred listens. If empty then
  pyfred binds to all available IP addresses.

* port [2225] - Port where pyfred server listens.

Genzone
-------

* idletreshold and checkperiod influence lifetime of CORBA objects dedicated
  for zone transfers.

Mailer
------

* testmode [off] - In test mode the emails are send to tester's email
  address and not to appropriate recipient. If testmode is On and tester's
  email address is empty, the emails are silently discarded (but archived
  in database).

* tester - This sets tester's email address and is taken into account only
  if testmode is on.

* sendmail [/usr/sbin/sendmail] - Path to sendmail-compatible program.

* filemanager_object [FileManager] - Mailer uses filemanager object to
  retrieve email attachments. This sets a name under which is Filemanager's
  reference looked up in nameservice.

Example: If this is set to 'FileManager' the resulting identifier of
         CORBA object is: 'fred.context/FileManager.Object'.
         If this is set to 'fred2.FileManager' the resulting identifier is:
         'fred2.context/FileManager.Object'.

* signing [Off] - Whether the emails should be cryptographically signed
  or not.

* openssl [/usr/bin/openssl] - Openssl binary used to sign emails. It is
  used only if signing is turned On.

* certfile - Path to x509 PEM encoded certificate.

* keyfile  - Path to certificate's key. The key must not be protected by
  passphrase!

* vcard [Off] - Attach to each email a vcard attachment.

* sendperiod [300] - Interval (in seconds) in which are looked up and sent
  "ready-to-be-send" emails. If this is zero, sending is turned off and all
  directives related to sending of emails are meaningless.

* manconfirm [Off] - If this is turned on, all generated emails must be at first
  manually confirmed in database before they are sent.

* maxattempts [3] - If sending of email fails from some reason, the email
  is sent after 'sendperiod' again. This numbers sets the maximal number of
  attempts to send email before the mailer gives up.

* undeliveredperiod [0] - Regularly check for undelivered email messages
  over IMAP. The interval is in seconds. If this is zero, the checks are
  turned off and all directives related to checking of undelivered emails
  are meaningless.

* IMAPuser [pyfred] - Username for IMAP account.

* IMAPpass [] - Password for IMAP account.

* IMAPserver [localhost] - Host and optional port where IMAP daemon runs
  in format host[:port].

* idletreshold and checkperiod are used to control lifetime of CORBA
  objects used for downloading of results of a search in mail archive.

TechCheck
---------

* testmode [Off] - If this is On the level 0 is assumed for all tested
  nssets, which practically disables execution of any tests. Use it if
  you have test data in database.

* periodic_checks [On] - Turn this off if you want to avoid background
  periodical checks, but still want to perform technical checks requested
  explicitly by a client.

* scriptdir [/usr/libexec/pyfred] - Directory where technical test scripts
  are placed.

* msgLifetime [7] - Service life of techcheck poll message. If during
  technical check of nsset called out over EPP interface are detected any
  errors, the EPP client is informed about it by means of EPP poll message.

* queueperiod [5] - Period in seconds in which is looked up new candidate
  (nsset) for technical check. This influences speed of regular nsset tests.
  If this is too small, the system can be overloaded, if this is too big,
  the technical checks will not be ready in time.

* oldperiod [30] - Number of days since last technical check on nsset
  after which is the nsset considered as a candidate for new one. Tweak this
  together with queueperiod to find optimal compromise.

* missrounds [10] - Number of rounds the candidate for technical check
  will not be looked up in database if previous attempt to find any
  candidate was unsuccessfull. This is here to optimize database load,
  since the query for looking up candidate is quite complicated and once
  we did regular technical check on all nssets, it is probable that
  next round, there won't be any candidate again.

* mailer_object [Mailer] - Name of mailer object under which it is known
  in CORBA nameservice. Techcheck needs the reference to this object
  because it has to send emails to technical contacts of nsset if it
  encounters any error during regular technical check.

Example: If this is set to 'Mailer' the resulting identifier of
         CORBA object is: 'fred.context/Mailer.Object'.
         If this is set to 'fred2.Mailer' the resulting identifier is:
         'fred2.context/Mailer.Object'.

* mailtype [techcheck] - This is an type of email, which is used when
  sending an email through mailer.

* idletreshold and checkperiod influences lifetime of CORBA objects used
  for transfering results of a search in techcheck archive back to client.


Dependencies
============

pyfred servers and clients assume that certain packages are installed on your
system. If you want to test your system for presence of dependecies (which is
strongly recommended to do anyway), type:

$ python setup.py config

The output of this command reminds strongly output of a configure script
generated by autoconf.

Here are explicitly listed the dependencies:

* Linux operating system
* Python version 2.5 or higher
* python bindings for omniORB library
* pygresql package
* dnspython package
* python bindings for clearsilver library


Testing
=======

There are unittests in directory "unittests". Currently there is only test
for genzone component. For more information about unittest see comments in
file.
