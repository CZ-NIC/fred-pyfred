#!/usr/bin/python
"""
Postgres manager.
Usage:

pgman create            # create cluster
pgman start             # start server
pgman db                # create database user and database
pgman load data.sql     # load data dump

pgman status            # show status running/not running
pgman dump > file.sql   # dump database into file
pgman stop              # stop server
pgamn destroy           # delete cluster
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
        self.db_name = "fred"
        self.db_user = "fred"
        self.db_password = "pokus"

    def __getitem__(self, key):
        "Emulate dict"
        return getattr(self, key)

    @property
    def db_host(self):
        return os.path.join(self.pg_data, "pg_sockets")

    @property
    def psql_password(self):
        "Password parameter for psql"
        return "PGPASSWOD=%s " % self.db_password if self.db_password else ""


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


def cluster_create(args=None):
    "Create postgresql cluster."
    conf = get_config()

    if os.path.exists(conf.pg_data):
        raise PgManagerError("""Directory "%s" exists but is not empty
If you want to create a new database system, either remove or empty the directory.""" % conf.pg_data)

    os.system("%(pg_initdb)s --pgdata=%(pg_data)s" % conf)
    # modify default pg configuration
    conf_path = os.path.join(conf.pg_data, "postgresql.conf")
    body = open(conf_path).read()
    body = re.compile('^#max_prepared_transactions\s*=\s*0', re.MULTILINE).sub('max_prepared_transactions = 5', body, 1)
    body = re.compile('^#log_min_duration_statement\s*=\s*-1', re.MULTILINE).sub('log_min_duration_statement = 0', body, 1)
    open(conf_path, "w").write(body)
    os.mkdir(conf.db_host)


def cluster_destroy(args=None):
    "Destroy postgresql cluster."
    conf = get_config()
    if server_is_running(conf):
        raise PgManagerError('Can not destroy server. It is running.')
    if not os.path.exists(conf.pg_data):
        raise PgManagerError('Directory "%s" does not exists' % conf.pg_data)
    os.system("rm -rf %s" % conf.pg_data)


def server_start(args=None):
    "Start postgresql server."
    conf = get_config()
    if server_is_running(conf):
        raise PgManagerError("Server is already running.")
    os.system('%(pg_ctl)s start -t 2 -w --pgdata=%(pg_data)s -l %(pg_data)s/pg.log -o "-p %(pg_port)d -k %(db_host)s -c TimeZone=UTC -c fsync=false"' % conf)


def server_stop(args=None):
    "Stop postgresql server."
    conf = get_config()
    if not server_is_running(conf):
        raise PgManagerError("Server is already stopped.")
    os.system('%(pg_ctl)s stop -w --pgdata=%(pg_data)s' % conf)


def server_status(conf):
    "Get status of postgresql server."
    if not os.path.exists(conf.pg_data):
        raise PgManagerError('Directory "%s" does not exists' % conf.pg_data)
    proc = subprocess.Popen("%(pg_ctl)s status --pgdata=%(pg_data)s | head -n 1" % conf, shell=True, stdout=subprocess.PIPE)
    return proc.stdout.read()


def server_is_running(conf):
    "Check if server is running."
    return re.search("server is running", server_status(conf)) is not None


def show_server_status(args=None):
    conf = get_config()
    if server_is_running(conf):
        print "server is running"
        print "%(psql_password)spsql -p %(pg_port)d -h %(db_host)s -U %(db_user)s %(db_name)s" % conf
    else:
        print "server is stopped"


def dump_database(args=None):
    "Dump database from postgresql server."
    conf = get_config()
    # pg_dump -p 26100 -h /var/opt/testdb/pg_sockets fred > dump.sql
    os.system("%(psql_password)spg_dump -p %(pg_port)d -h %(db_host)s -U %(db_user)s %(db_name)s" % conf)


def load_into_database(path):
    "Load data into database."
    conf = get_config()
    conf.path = path
    os.system("%(psql_password)spsql -p %(pg_port)d -h %(db_host)s -U %(db_user)s %(db_name)s < %(path)s" % conf)

def load_into_db(args):
    "Load data into database."
    return load_into_database("".join(args.data))


def psql_client(args=None):
    "Run psql client."
    conf = get_config()
    os.system("%(psql_password)spsql -p %(pg_port)d -h %(db_host)s -U %(db_user)s %(db_name)s" % conf)


def create_user_and_database(args=None):
    "Create user and database"
    conf = get_config()
    query = []
    if conf.db_password:
        query.append("CREATE ROLE %(db_user)s WITH CREATEDB LOGIN PASSWORD '%(db_password)s';" % conf.__dict__)
    else:
        query.append("CREATE ROLE %(db_user)s WITH CREATEDB;" % conf.__dict__)
    query.append("CREATE DATABASE %(db_name)s OWNER %(db_user)s;" % conf.__dict__)
    #query.append("CREATE OR REPLACE LANGUAGE plpgsql;")
    conf.query = " ".join(query)
    os.system("echo \"%(query)s\" | psql -p %(pg_port)d -h %(db_host)s postgres" % conf)



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
    parser_dump.set_defaults(func=dump_database)

    parser_load = subparsers.add_parser('load', help='Load data into database name.')
    parser_load.add_argument("data", nargs=1, help="Data to load.")
    parser_load.set_defaults(func=load_into_db)

    parser_client = subparsers.add_parser('client', help='Run psql client.')
    parser_client.set_defaults(func=psql_client)

    parser_user = subparsers.add_parser('db', help='Create database user and database.')
    parser_user.set_defaults(func=create_user_and_database)

    args = parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    try:
        main()
    except PgManagerError, msg:
        print >> sys.stderr, msg
