maintainer       "Jim Dowling"
maintainer_email "jdowling@kth.se"
name             "kagent"
license          "GPL 2.0"
description      "Installs/Configures the Karamel agent used by Hops"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.2"
source_url       "https://github.com/karamelchef/kagent-chef"


%w{ ubuntu debian centos }.each do |os|
  supports os
end

depends 'python'
#depends 'openssl'
#depends 'sudo'
depends 'hostsfile'

recipe "kagent::default", "Installs and configures the Karamel agent"

attribute "kagent/dashboard/ip_port",
:description => " Ip address and port for Dashboard REST API",
:type => 'string'

attribute "hop/hostid",
:display_name => "HostId",
:description => " One-time password used when registering the host",
:type => 'string'

attribute "kagent/name",
:description => "Cookbook name",
:type => 'string'

attribute "kagent/rest_api/user",
:description => "kagent REST API username",
:type => "string"

attribute "kagent/rest_api/password",
:description => "kagent REST API  password",
:type => "string"

attribute "kagent/dashboard/user",
:description => "kagent username to register with server",
:type => "string"

attribute "kagent/dashboard/password",
:description => "kagent password to register with server",
:type => "string"

attribute "ndb/mysql_port",
:description => "Port for the mysql server",
:type => "string"

attribute "ndb/mysql_socket",
:description => "Socket for the mysql server",
:type => "string"

attribute "systemd",
:description => "Use systemd startup scripts, default 'true'",
:type => "string"

attribute "kagent/network/interface",
:description => "Define the network intefaces (eth0, enp0s3)",
:type => "string"
