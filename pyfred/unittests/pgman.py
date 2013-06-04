#!/usr/bin/python
"""
Postgres manager.
"""
import sys
import re
import os
import subprocess
import argparse


class Config(object):

    def __init__(self):
        self.pg_port = 33455
        self.pg_data = "/tmp/pyfredtestdb"
        self.pg_ctl = None # "/usr/lib/postgresql/9.1/bin/pg_ctl"
        self.pg_initdb = None # "/usr/lib/postgresql/9.1/bin/initdb"


class PgManagerError(Exception):
    "Postgresql manager error"



def get_config():
    conf = Config()
    if conf.pg_ctl is None:
        proc = subprocess.Popen("ls -d /usr/lib/postgresql/*/bin/ 2>/dev/null| sort -r", shell=True, stdout=subprocess.PIPE)
        path = proc.stdout.read().strip()
        conf.pg_ctl = "%spg_ctl" % path
        conf.pg_initdb = "%sinitdb" % path
    return conf


def cluster_create(args):
    "Create postgresql cluster."
    conf = get_config()

    if os.path.exists(conf.pg_data):
        raise PgManagerError("""Directory "%s" exists but is not empty
If you want to create a new database system, either remove or empty the directory.""" % conf.pg_data)

    os.system("%s --pgdata=%s" % (conf.pg_initdb, conf.pg_data))
    # modify default pg configuration
    conf_path = os.path.join(conf.pg_data, "postgresql.conf")
    body = open(conf_path).read()
    body = re.sub('^#max_prepared_transactions\s*=\s*0', 'max_prepared_transactions = 5', body, 1, re.MULTILINE)
    body = re.sub('^#log_min_duration_statement\s*=\s*-1', 'log_min_duration_statement = 0', body, 1, re.MULTILINE)
    open(conf_path, "w").write(body)

    os.mkdir(os.path.join(conf.pg_data, "pg_sockets"))



def cluster_destroy(args):
    "Destroy postgresql cluster."
    conf = get_config()
    if server_is_running(conf):
        raise PgManagerError('Can not destroy server. It is running.')
    if not os.path.exists(conf.pg_data):
        raise PgManagerError('Directory "%s" does not exists' % conf.pg_data)
    os.system("rm -rf %s" % conf.pg_data)


def server_start(args):
    "Start postgresql server."
    conf = get_config()
    if server_is_running(conf):
        raise PgManagerError("Server is already running.")
    os.system('%(command)s start -w --pgdata=%(pgdata)s -l %(pgdata)s/pg.log -o "-p %(port)d -k %(pgdata)s/pg_sockets -c TimeZone=UTC -c fsync=false"' % {
        "command": conf.pg_ctl, "port": conf.pg_port, "pgdata": conf.pg_data})


def server_stop(args):
    "Stop postgresql server."
    conf = get_config()
    if not server_is_running(conf):
        raise PgManagerError("Server is already stopped.")
    os.system('%(command)s stop -w --pgdata=%(pgdata)s' % {"command": conf.pg_ctl, "pgdata": conf.pg_data})


def server_status(conf):
    "Get status of postgresql server."
    if not os.path.exists(conf.pg_data):
        raise PgManagerError('Directory "%s" does not exists' % conf.pg_data)
    proc = subprocess.Popen("%s status --pgdata=%s | head -n 1" % (conf.pg_ctl, conf.pg_data), shell=True, stdout=subprocess.PIPE)
    return proc.stdout.read()


def server_is_running(conf):
    "Check if server is running."
    return re.search("server is running", server_status(conf)) is not None


def show_server_status(args):
    conf = get_config()
    if server_is_running(conf):
        print "server is running"
        print "   psql -p %(pg_port)d -h %(pg_data)s/pg_sockets postgres" % conf.__dict__
    else:
        print "server is stopped"


def dump_database(args):
    "Dump database from postgresql server."
    conf = get_config()
    # pg_dump -p 26100 -h /var/opt/testdb/pg_sockets fred > dump.sql
    os.system("pg_dump -p %(pg_port)d -h %(host)s %(dbname)s" % {
        "pg_port": conf.pg_port,
        "host": os.path.join(conf.pg_data, "pg_sockets"),
        "dbname": "".join(args.name),
    })


def load_into_database(args):
    "Load data into database."
    conf = get_config()
    if args.name is None:
        dbname = "postgres"
    else:
        dbname = "".join(args.name)
    # psql -p 22822 -h /var/opt/testdb/pg_sockets postgres < dump.sql
    os.system("psql -p %(pg_port)d -h %(host)s %(dbname)s < %(path)s" % {
        "pg_port": conf.pg_port,
        "host": os.path.join(conf.pg_data, "pg_sockets"),
        "path": "".join(args.data),
        "dbname": dbname,
    })


def psql_client(args):
    "Run psql client."
    conf = get_config()
    params = dict(dbname="postgres" if args.name is None else args.name)
    params.update(conf.__dict__)
    os.system("psql -p %(pg_port)d -h %(pg_data)s/pg_sockets %(dbname)s" % params)


def main():
    "Main loop"
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()

    parser_create = subparsers.add_parser('create', help='Create postgresql database.')
    parser_create.set_defaults(func=cluster_create)

    parser_destroy = subparsers.add_parser('destroy', help='Destroy postgresql database.')
    parser_destroy.set_defaults(func=cluster_destroy)

    parser_start = subparsers.add_parser('start', help='Start database at the port defined in the config.')
    parser_start.set_defaults(func=server_start)

    parser_stop = subparsers.add_parser('stop', help='Start database at the port defined in the config.')
    parser_stop.set_defaults(func=server_stop)

    parser_status = subparsers.add_parser('status', help='Show database status.')
    parser_status.set_defaults(func=show_server_status)

    parser_dump = subparsers.add_parser('dump', help='Dump database name into stdout.')
    parser_dump.add_argument("name", nargs=1, help="Database name")
    parser_dump.set_defaults(func=dump_database)

    parser_load = subparsers.add_parser('load', help='Load data into database name.')
    parser_load.add_argument("data", nargs=1, help="Data to load.")
    parser_load.add_argument("name", nargs="?", help="Database name")
    parser_load.set_defaults(func=load_into_database)

    parser_client = subparsers.add_parser('client', help='Run psql client.')
    parser_client.add_argument("name", nargs="?", help="Database name")
    parser_client.set_defaults(func=psql_client)

    args = parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    try:
        main()
    except PgManagerError, msg:
        print >> sys.stderr, msg
