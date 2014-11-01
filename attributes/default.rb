default[:hadoop][:version]                = "2.2.0"

# Default values for configuration parameters
default[:kagent][:run_as_user]          = "root"
default[:kagent][:base_dir]             = "/var/lib/kagent"

default[:kagent][:group_name]           = "group1"

# Username/Password for connecting to the HopDashboard
default[:kagent][:rest_api][:user]      = "kagent@sics.se"
default[:kagent][:rest_api][:password]  = "kagent"

# Username/Password for the dashboard connecting to this agent
default[:kagent][:dashboard][:user]     = "kthfsagent@sics.se"
default[:kagent][:dashboard][:password] = "kthfsagent"

# Agent's local certificate for SSL connections
default[:kagent][:certificate_file]     = "server.pem"

# dashboard ip:port endpoint
# 10.0.2.15:8080
default[:kagent][:dashboard][:ip_port]  = "" 
default[:kagent][:dashboard_app]        = "hop-dashboard"


# local settings for agent
default[:kagent][:port]                      = 8090
default[:kagent][:heartbeat_interval]        = 10
default[:kagent][:watch_interval]            = 2
default[:kagent][:pid_file]                  = "/var/lib/kagent/hop-agent.pid"
default[:kagent][:logging_level]             = "INFO"
default[:kagent][:max_log_size]              = "10000000"

default[:kagent][:network][:interface]  = "eth0"


# services file contains locally installed services
default[:hop][:services]                  = "/var/lib/kagent/services"
# name of cluster as shown in Dashboard
default[:hop][:cluster]                   = "Hops_Cluster"

default[:mysql][:root][:password]         = "kthfs"
default[:ndb][:mysql_socket]              = "/tmp/mysql.sock"
default[:ndb][:mysql][:jdbc_url]          = ""
default[:ndb][:mysql_port]                = "3306"

default[:kagent][:hostid]                    = 100

# Set of all services that may be installed
default[:ndb][:service]                   = "NDB"
default[:hop][:service]                   = "HDFS"
default[:yarn][:service]                  = "YARN"
default[:mr][:service]                    = "MAP_REDUCE"
default[:spark][:service]                 = "SPARK"
default[:collectd][:service]              = "COLLECTD"
default[:stratosphere][:service]          = "STRATOSPHERE"

default[:kagent][:public_ips]           = ['10.0.2.15']
default[:kagent][:private_ips]          = ['10.0.2.15']

# Base URL used to download hop binaries
default[:download_url]                    = "http://193.10.67.171/hops"

default['java']['bouncycastle_url']       = "#{node[:download_url]}/bcprov-jdk16-146.jar"
#default['java']['bouncycastle_url']      = "http://downloads.bouncycastle.org/java/bcprov-jdk16-146.jar"

default[:vagrant]                         = "false"
