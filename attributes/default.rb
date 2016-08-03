node.default.hadoop.version                = "2.4.0"

# Default values for configuration parameters
default.kagent.run_as_user            = "root"
default.kagent.dir                    = "/var/lib"
default.kagent.base_dir               = "#{node.kagent.dir}/kagent"

default.kagent.group_name             = "group1"

default.kagent.enabled                = "false"

# Username/Password for connecting to the agent
default.kagent.rest_api.user          = "kagent@hops.io"
default.kagent.rest_api.password      = "kagent"

# API calls
default.kagent.dashboard.api.register = "/api/agent/register"
default.kagent.dashboard.api.login    = "/api/auth/login"


# Username/Password for the dashboard connecting to Hopsworks
default.kagent.dashboard.user         = "agent@hops.io"
default.kagent.dashboard.password     = "admin"

# Username/Password for the keystore

default.hopsworks.master.password     = "adminpw"

# Agent's local certificate for SSL connections
default.kagent.certificate_file       = "server.pem"

# dashboard ip:port endpoint
# default.kagent.dashboard.port         = ""
default.kagent.dashboard.ip           = "10.0.2.15"
default.kagent.dashboard.port         = "8080"  
default.kagent.dashboard_app          = "hopsworks"


# local settings for agent
default.kagent.port                   = 8090
default.kagent.heartbeat_interval     = 10
default.kagent.watch_interval         = 2
default.kagent.pid_file               = node.kagent.base_dir + "/hop-agent.pid"
default.kagent.logging_level          = "INFO"
default.kagent.max_log_size           = "10000000"

default.kagent.network.interface      = ""


# services file contains locally installed services
default.kagent.services               = node.kagent.base_dir + "/services"
# name of cluster as shown in Dashboard
default.kagent.cluster                = "Hops"

default.kagent.hostid                 = 100

default.kagent.keystore_dir 		 = node.kagent.base_dir + "/keystores"

default.kagent.public_ips             = ['10.0.2.15']
default.kagent.private_ips            = ['10.0.2.15']
default.kagent.allow_ssh_access       = "false"

node.default.download_url                  = "http://193.10.67.171/hops"
node.default.systemd                       = "true"
node.default.ndb.mysql_socket              = "/tmp/mysql.sock"
node.default.ndb.mysql.jdbc_url            = ""
node.default.ndb.mysql_port                = "3306"

node.default.vagrant                       = "false"


node.default.ntp.install                            = "false"
# Servers to sync ntp time with
# '0.pool.ntp.org', '1.pool.ntp.org'
node.normal.ntp.servers                             = ['0.europe.pool.ntp.org', '1.europe.pool.ntp.org', '2.europe.pool.ntp.org', '3.europe.pool.ntp.org']

node.normal.ntp.peers                               = ['time0.int.example.org', 'time1.int.example.org']
