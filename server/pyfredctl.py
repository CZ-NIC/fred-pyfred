#!/usr/bin/env python
# vim:set ts=4 sw=4:

import os, sys, commands, time, signal, re

def get_instances():
	lines = commands.getoutput("ps -eo pid,command | grep pyfred.py").split('\n')
	instances = []
	pattern = re.compile("(\d+)\s+python\s+\S*pyfred.py(\s+(\S+))?")
	for line in lines:
		matchres = pattern.match(line.strip())
		if matchres:
			matchgroups = matchres.groups()
			instances.append( (int(matchgroups[0]), matchgroups[2]) )
	return instances

def select_pids(instances, confs):
	if not confs:
		for instance in instances:
			if not instance[1]:
				return [instance[0]]
		return []
	pids = []
	for conf in confs:
		for instance in instances:
			if instance[1] == conf:
				pids.append(instance[0])
	return pids

def usage():
	sys.stderr.write("Usage: pyfredctl.py [ start | stop | status ] conf1 "
			"conf2 ...\n")
	sys.stderr.write("Optional confs identify instances of pyfred.\n")


if __name__ == "__main__":
	if len(sys.argv) < 2:
		sys.stderr.write("Invalid parameter count\n")
		usage()
		sys.exit(2)
	if len(sys.argv) > 2:
		confs = sys.argv[2:]
	else:
		confs = None
	instances = get_instances()
	if sys.argv[1] == "start":
		pids = select_pids(instances, confs)
		if len(pids) > 0:
			sys.stdout.write("pyfred is already running - use status parameter "
					"to see what's running.\n")
			sys.stdout.write("Stop the pyfred at first\n")
		else:
			if not confs and len(instances) > 0:
				sys.stdout.write("Specify config file or stop other instances"
						"of pyfred.\n")
			else:
				if not confs:
					pid = os.spawnlp(os.P_NOWAIT, "pyfred.py")
					sys.stdout.write("pyfred started with pid %d\n" % pid)
				else:
					for conf in confs:
						print "pyfred.py %s" % conf
						pid = os.spawnlp(os.P_NOWAIT, "pyfred.py", conf)
						sys.stdout.write("instance '%s' of pyfred started with "
								"pid %d\n" % (conf, pid))
	elif sys.argv[1] == "stop":
		if confs:
			pids = select_pids(instances, confs)
		else:
			pids = [ instance[0] for instance in instances ]
		if len(pids) == 0:
			sys.stdout.write("specified instance of pyfred is not running\n")
		else:
			sys.stdout.write("Stopping instance(s): ")
			for pid in pids:
				sys.stdout.write("%d " % pid)
				os.kill(pid, signal.SIGTERM)
			sys.stdout.write("\n")
			sys.stdout.write("Waiting 3 seconds for process(es) to terminate\n")
			time.sleep(3)
			instances = get_instances()
			pids = select_pids(instances, confs)
			if pids:
				sys.stdout.write("Killing processes: ")
				for pid in pids:
					sys.stdout.write("%d " % pid)
					os.kill(pid, signal.SIGKILL)
				sys.stdout.write("\n")
	elif sys.argv[1] == "status":
		if len(instances) == 0:
			sys.stdout.write("pyfred is not running.\n")
		else:
			for instance in instances:
				if not instance[1]:
					sys.stdout.write("pyfred is running with pid %d.\n" %
							instance[0])
				else:
					sys.stdout.write("Instance '%s' of pyfred is running with "
							"pid %d.\n" % (instance[1], instance[0]))
	else:
		sys.stderr.write("Invalid parameter")
		usage()
		sys.exit(2)
	sys.exit()
