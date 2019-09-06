#!/usr/bin/env python
#
# Copyright (C) 2007-2019  CZ.NIC, z. s. p. o.
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
This module is a framework in which can be easily embedded various corba
object implementations through extending modules defined in modules.conf.
Those objects are registered in corba name service and the rest is up to
a caller (corba client).
"""
import ConfigParser
import os
import signal
import sys
import time

import CosNaming
from omniORB import CORBA, PortableServer

from pyfred.runtime_support import DB, CorbaRefs, Logger, getConfiguration, init_logger

# These are global because they are needed in signal handler
pidfile = None
fredContext = None # Nameservice reference
nsnames = [] # Registered names by nameservice
log = None # Logger


# Fisrt item was replaced by setup.py to the path according to installation path.
CONFIGS = ("/usr/etc/fred/pyfred.conf",
           "/etc/fred/pyfred.conf",
           "/usr/local/etc/fred/pyfred.conf",
           "pyfred.conf",
          )


def job_noop(dummy):
    """
    This function is used as placeholder in job queue if the queue is empty.
    """
    pass

def createDaemon():
    """
    This function demonizes the process.
    """
    try:
        pid = os.fork()
    except OSError, e:
        sys.stderr.write("Error when daemonizing pyfred: %s\n" % e.strerror)
        os._exit(0)

    if pid == 0:    # The first child.
        # To become the session leader of this new session and the process group
        # leader of the new process group, we call os.setsid().  The process is
        # also guaranteed not to have a controlling terminal.
        os.setsid()

        try:
            pid = os.fork() # Fork a second child.
        except OSError, e:
            sys.stderr.write("Error when daemonizing pyfred: %s\n" % e.strerror)
            os._exit(0)

        if pid != 0:    # The second child.
            os._exit(0) # Exit parent (the first child) of the second child.
    else:
        os._exit(0) # Exit parent of the first child.

def sighandler(signum, arg):
    """
    Common signal handler, which terminates the pyfred process. The cleanup
    actions are: pidfile deletion and unregistering of corba object references.
    """
    global pidfile
    global nsnames
    global fredContext
    global log

    log.log(log.NOTICE, "Terminating pyfred server ...")

    # unregister corba objects
    if fredContext:
        for nsname in nsnames:
            try:
                fredContext.unbind(nsname)
            except Exception, e:
                log.log(log.ERR, "Error when unbinding name "
                        "from nameservice: %s" % e)

    if not pidfile:
        log.log(log.INFO, "The pidfile is not set - signal was "
                "probably delivered too early after the start "
                "or pidfile creation is disabled.")
        sys.exit(0)

    # delete the pidfile
    try:
        os.unlink(pidfile)
        log.log(log.DEBUG, "Pidfile %s deleted." % pidfile)
    except OSError, e:
        # ignore error if the file does not exist
        log.log(log.WARNING, "Pidfile %s is set but was not "
                "created." % pidfile)
    except Exception, e:
        log.log(log.ERROR, "Error when removing pidfile %s: %s" %
                (pidfile, e))
        sys.exit(1)
    # exit the program
    sys.exit(0)


#
# main
#
def run_fred_pyfred(argv):
    """
    """
    global pidfile
    global fredContext
    global nsnames
    global log

    # if server should detach from terminal after startup
    detach = True
    # default places where to look for configs
    configs = list(CONFIGS)
    for arg in argv[1:]:
        if arg == "-d":
            detach = False
        else:
            # append explicit config location if present on command line
            configs.insert(0, arg)
    # get configuration
    conf = getConfiguration(configs)
    if not conf:
        sys.exit(1)

    # Check pidfile
    try:
        pidfile = conf.get("General", "pidfile")
    except ConfigParser.NoOptionError:
        # pidfile disabled
        pidfile = None

    if pidfile and os.access(pidfile, os.F_OK):
        pidfd = open(pidfile, "r")
        pidline = pidfd.readline()
        # strip trailing \n if there is any
        if pidline[-1] == '\n':
            pid = int(pidline[:-1])
        else:
            pid = int(pidline)
        pidfd.close()
        sys.stderr.write("pyfred is already running with pid %d\n" % pid)
        sys.stderr.write("(Delete pidfile %s to force start)\n" % pidfile)
        sys.stderr.write("Exiting ...\n")
        sys.exit(1)

    # create database object to be used in modules
    db = DB(conf.get("General", "dbhost"),
            conf.get("General", "dbport"),
            conf.get("General", "dbname"),
            conf.get("General", "dbuser"),
            conf.get("General", "dbpassword"))

    # get logger configuration
    loghandler = conf.get("General", "loghandler").lower()
    loglevel = conf.get("General", "loglevel").lower()
    logfacility = conf.get("General", "logfacility").lower()
    logfilename = conf.get("General", "logfilename")

    try:
        logfd = init_logger(loghandler, loglevel, logfacility, logfilename, '', detach)
    except Exception, e:
        sys.stderr.write("Logger configuration error: handler=%s level=%s"
                         " [facility=%s filename=%s] (%s)\n" % (loghandler,
                         loglevel, logfacility, logfilename, str(e)))
        sys.exit(1)

    log = Logger('pyfred')

    # create structure for passing of CORBA references
    corba_refs = CorbaRefs()

    # get list of modules to import
    modulenames = conf.get("General", "modules").split(" ")
    #remove zero-length module names
    try:
        while 1:
            modulenames.remove('')
    except ValueError:
        pass
    # load all modules
    sys.stdout.write("Importing modules %s\n" % modulenames)
    try:
        mods = __import__("pyfred.modules", globals(), locals(), modulenames)
    except Exception, e:
        sys.stderr.write("Could not import module: %s\n" % e)
        sys.exit(1)
    # convert inconvenient mods structure into plain list of modules
    modules = []
    for module in dir(mods):
        # ignore private variables
        if module.startswith('__'):
            continue
        modules.append(eval("mods." + module))

    # Run init methods in registered modules and save servant refs for later use
    joblist = []
    servants = []
    for module in modules:
        try:
            servants.append(module.init(Logger(module.__name__),
                            db, conf, joblist, corba_refs))
        except Exception, e:
            sys.stderr.write("Error when initializing module '%s': %s:%s\n" %
                    (module.__name__, sys.exc_info()[0], e))
            sys.exit(1)

    sys.stdout.write("Logging to %s since now\n" % str(loghandler))

    # daemonize pyfred
    if detach:
        createDaemon()

        # Since now we will use only syslog
        if (os.sysconf_names.has_key("SC_OPEN_MAX")):
            maxfd = os.sysconf("SC_OPEN_MAX")
        else:
            maxfd = 1024
        # Iterate through and close all file descriptors. omit file log fd
        listfd = range(0, maxfd)
        if logfd:
            listfd.remove(logfd)
        for fd in listfd:
            try:
                os.close(fd)
            except OSError: # fd wasn't open (ignored)
                pass
        # This call to open is guaranteed to return the lowest file descriptor,
        # which will be 0 (stdin), since it was closed above.
        os.open(os.devnull, os.O_RDWR)  # standard input (0)
        # Duplicate standard input to standard output and standard error.
        os.dup2(0, 1)           # standard output (1)
        os.dup2(0, 2)           # standard error (2)

    # Initialise the ORB and get the root POA
    try:
        nsname = "NameService=corbaname::" + conf.get("General", "nshost") + \
                ":" + conf.get("General", "nsport")
        orb = CORBA.ORB_init(["-ORBnativeCharCodeSet", "UTF-8", "-ORBInitRef",
                nsname, "-ORBendPoint", "::%s:%s" %
                (conf.get("General", "host"), conf.get("General", "port"))])
        rootpoa = orb.resolve_initial_references("RootPOA")
        # create persistent poa
        ps = [rootpoa.create_lifespan_policy(PortableServer.PERSISTENT),
              rootpoa.create_id_assignment_policy(PortableServer.USER_ID),
              rootpoa.create_implicit_activation_policy(PortableServer.NO_IMPLICIT_ACTIVATION)]
        poa = rootpoa.create_POA("pyfredPOA", rootpoa._get_the_POAManager(), ps)

        # Obtain a reference to the root naming context
        obj = orb.resolve_initial_references("NameService")
        nsref = obj._narrow(CosNaming.NamingContext)
        if nsref is None:
            msg = "Failed to narrow the root naming context"
            sys.stderr.write(msg + '\n')
            log.log(log.ERR, msg)
            sys.exit(1)
    except CORBA.TRANSIENT, e:
        msg = "Is nameservice running? (%s)" % e
        sys.stderr.write(msg + '\n')
        log.log(log.ERR, msg)
        sys.exit(1)
    except CORBA.Exception, e:
        msg = "CORBA failure: %s" % e
        sys.stderr.write(msg + '\n')
        log.log(log.ERR, msg)
        sys.exit(1)

    # Bind a context named by default "fred.context" to the root context
    # This context is a container for all registered objects
    name = [CosNaming.NameComponent(conf.get("General", "nscontext"), "context")]
    try:
        fredContext = nsref.bind_new_context(name)
        log.log(log.INFO, "New %s context bound" %
                conf.get("General", "nscontext"))
    except CosNaming.NamingContext.AlreadyBound, ex:
        log.log(log.NOTICE, "%s context already exists" %
                conf.get("General", "nscontext"))
        obj = nsref.resolve(name)
        fredContext = obj._narrow(CosNaming.NamingContext)
        if fredContext is None:
            msg = "%s.context exists but is not a NamingContext" % conf.get("General", "nscontext")
            sys.stderr.write(msg + '\n')
            log.log(log.ERR, msg)
            sys.exit(1)

    corba_refs.rootpoa = rootpoa
    corba_refs.nsref = nsref

    # Register modules by nameservice and activate them in poa
    for item in servants:
        (servant, name) = item
        poa.activate_object_with_id(name, servant)
        ref = poa.id_to_reference(name)
        cosname = [CosNaming.NameComponent(name, "Object")]
        try:
            fredContext.bind(cosname, ref)
            log.log(log.INFO, "New '%s' object bound" % name)
        except CosNaming.NamingContext.AlreadyBound:
            fredContext.rebind(cosname, ref)
            log.log(log.NOTICE, "Existing '%s' object rebound" %
                    name)
        # archive reference name for future removal
        nsnames.append(cosname)

    # Activate the POA
    poaManager = poa._get_the_POAManager()
    poaManager.activate()

    # Create PID file
    if pidfile:
        try:
            pidfd = open(pidfile, "w")
        except Exception, e:
            log.log(log.ERR, "Could not create pid file %s. Check "
                    "permissions." % pidfile)
            sys.exit(1)
        pidfd.write("%d\n" % os.getpid())
        pidfd.close()

    # Install common signal handler for basic signals
    for sig in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, sighandler)

    # Run cron jobs forever
    if len(joblist) == 0:
        joblist = [ { "callback":job_noop, "context":None, "period":3600 } ]

    # helper function
    def get_job_name(job):
        job_class = str(job["callback"].im_class).split(".")[-1] if hasattr(job["callback"], "im_class") else None
        job_method = str(job["callback"].__name__)
        return ".".join(filter(None, [job_class, job_method]))

    delay = 5 # initial delay
    while True:
        log.log(log.DEBUG, "[main loop] sleep for %ds" % delay)
        time.sleep(delay)
        # job list inspect
        try:
            log.log(log.DEBUG, "[main loop] %d job(s) in queue" % len(joblist))
            ticks_sum = 0
            for j in joblist:
                ticks_sum += j["ticks"]
                log.log(log.DEBUG, "[main loop] %ds till %s" % (ticks_sum, get_job_name(j)))
        except Exception:
            pass
        # look what is scheduled for execution
        job = joblist.pop(0)
        # execute first job in a queue
        try:
            log.log(log.DEBUG, "[main loop] executing job %s" % get_job_name(job))
            job["callback"](job["context"])
            log.log(log.DEBUG, "[main loop] job finished")
        except Exception, e:
            log.log(log.ERR, "Unexpected error when "
                    "executing job. %s:%s" % (sys.exc_info()[0], e))
        # schedule job for next execution
        job["ticks"] = job["period"]
        for i in range(len(joblist)):
            item = joblist[i]
            if job["ticks"] - item["ticks"] >= 0:
                job["ticks"] -= item["ticks"]
            else:
                joblist.insert(i, job)
                item["ticks"] -= job["ticks"]
                job = None
                break
        if job:
            # job should be run as last
            joblist.insert(len(joblist), job)
        # calculate the time to next awakening
        delay = joblist[0]["ticks"]

    # Block for ever (or until the ORB is shut down)
    #orb.run()

if __name__ == "__main__":
    try:
        run_fred_pyfred(sys.argv)
    except SystemExit, e:
        # This means that Ctrl-C was pressed. Ignore it.
        pass
    except Exception, e:
        msg = "Unexpected error, this should not happen. Please " \
                "submit a bug report. %s:%s" % (sys.exc_info()[0], e)
        sys.stderr.write(msg + '\n')
        log.log(log.CRIT, msg)
        # do cleanup
        sighandler(0, None)
