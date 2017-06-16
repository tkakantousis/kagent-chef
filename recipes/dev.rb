private_ip = my_private_ip()

priv_net_if = node["kagent"]["network"]["interface"]

# If the network i/f name not set by the user, set default values for ubuntu and centos
if priv_net_if == ""
  case node["platform_family"]
  when "debian"
    priv_net_if = "eth1"
  when "rhel"
    priv_net_if = "enp0s8"
  end
end

pub_net_if = ""
case priv_net_if
when "enp0s3"
  pub_net_if = "enp0s8"
when "enp0s8"
  pub_net_if = "enp0s3"
when "eth1"
  pub_net_if = "eth0"
when "eth0"
  pub_net_if = "eth1"
end

directory '/etc/iptables' do
  owner 'root'
  group 'root'
  recursive true
  action :delete
end

directory '/etc/iptables' do
  owner 'root'
  group 'root'
  mode '0700'
  action :create
end

template '/etc/iptables/iptables.rules' do
  source 'iptables.rules.erb'
  owner 'root'
  group 'root'
  mode '0700'
  variables({
              :pub_net_if => pub_net_if,
              :priv_net_if => priv_net_if,
              :private_ip => private_ip,
              :public_ip => "10.0.2.15"
            })
  notifies :run, 'execute[ip_forward]', :immediately
end

execute 'ip_forward' do
  command "sed -i '/^#net.ipv4.ip_forward*/s/^#//' /etc/sysctl.conf"
  user 'root'
  group 'root'
  action :nothing
  notifies :run , 'execute[ip_tables]', :immediately
end

execute 'ip_tables' do
  command "iptables-restore < /etc/iptables/iptables.rules"
  user 'root'
  group 'root'
  action :nothing
end
