service_name = "kagent"

case node.platform
when "ubuntu"
 if node.platform_version.to_f <= 14.04
   node.default.systemd = "false"
 end
end

if node.systemd == "true"
  service "#{service_name}" do
    provider Chef::Provider::Service::Systemd
    supports :restart => true, :start => true, :stop => true, :enable => true
    action :nothing
  end

  case node.platform_family
  when "rhel"
    systemd_script = "/usr/lib/systemd/system/#{service_name}.service" 
  else # debian
    systemd_script = "/lib/systemd/system/#{service_name}.service"
  end

  template systemd_script do
    source "#{service_name}.service.erb"
    owner node.kagent.run_as_user
    group node.kagent.run_as_user
    mode 0650
  end

  link "/etc/systemd/system/#{service_name}.service" do
    only_if { node.systemd == "true" }
    owner "root"
    to "#{node.kagent.base_dir}/#{service_name}.service" 
  end

else # sysv

  service "#{service_name}" do
    provider Chef::Provider::Service::Init::Debian
    supports :restart => true, :start => true, :stop => true, :enable => true
    action :nothing
  end

  template "/etc/init.d/#{service_name}" do
    source "#{service_name}.erb"
    owner node.kagent.run_as_user
    group node.kagent.run_as_user
    mode 0650
    notifies :enable, "service[#{service_name}]"
    notifies :start, "service[#{service_name}]"
  end

end



template"#{node.kagent.base_dir}/agent.py" do
  source "agent.py.erb"
  owner node.kagent.run_as_user
  group node.kagent.run_as_user
  mode 0655
end


['start-agent.sh', 'stop-agent.sh', 'restart-agent.sh', 'get-pid.sh'].each do |script|
  Chef::Log.info "Installing #{script}"
  template "#{node.kagent.base_dir}/#{script}" do
    source "#{script}.erb"
    owner node.kagent.run_as_user
    group node.kagent.run_as_user
    mode 0655
  end
end 

['services'].each do |conf|
  Chef::Log.info "Installing #{conf}"
  template "#{node.kagent.base_dir}/#{conf}" do
    source "#{conf}.erb"
    owner node.kagent.run_as_user
    group node.kagent.run_as_user
    mode 0644
  end
end

private_ip = my_private_ip()
public_ip = my_public_ip()

dashboard_endpoint = node.kagent.dashboard.ip_port
if dashboard_endpoint.eql? ""
  if node.attribute? "kmon"
    dashboard_endpoint = private_cookbook_ip("kmon")  + ":8080"
  end
end

network_if = node.kagent.network.interface

# If the network i/f name not set by the user, set default values for ubuntu and centos
if node.kagent.network.interface == ""
  case node.platform_family
  when "debian"
    network_if = "eth0"
  when "rhel"
    network_if = "enp0s3"
  end
end

template "#{node.kagent.base_dir}/config.ini" do
  source "config.ini.erb"
  owner node.kagent.run_as_user
  group node.kagent.run_as_user
  mode 0600
  variables({
              :rest_url => "http://#{dashboard_endpoint}/#{node.kagent.dashboard_app}",
              :rack => '/default',
              :public_ip => public_ip,
              :private_ip => private_ip,
              :network_if => network_if
            })
  notifies :enable, "service[#{service_name}]"
  notifies :start, "service[#{service_name}]"
end

# TODO install MONIT to restart the agent if it crashes

kagent_kagent "restart-kagent" do
  action :restart
end

case node.platform_family
when "rhel"

  bash "disable-iptables" do
    code <<-EOH
    service iptables stop
  EOH
    only_if "test -f /etc/init.d/iptables && service iptables status"
  end

# if node.vagrant  == 'true'
#   bash "fix-sudoers-for-vagrant" do
#     code <<-EOH
#     echo "" >> /etc/sudoers
#     echo "#includedir /etc/sudoers.d" >> /etc/sudoers
#     echo "" >> /etc/sudoers
#     touch /etc/sudoers.d/.vagrant_fix
#   EOH
#     only_if "test -f /etc/sudoers.d/.vagrant_fix"
#   end
# end

# Fix sudoers to allow root exec shell commands for Centos
#node.default.authorization.sudo.include_sudoers_d = true
# default 'commands' attribute for this LWRP is 'ALL'
#sudo 'root' do
#  user      "root"
#  runas     'ALL:ALL'
#end

end

if node.kagent.allow_kmon_ssh_access == 'true'

  if node.attribute? "kmon"
    if node.kmon.attribute? "public_key"
      bash "add_dashboards_public_key" do
        user "root"
        code <<-EOF
         mkdir -p /root/.ssh
         chmod 700 /root/.ssh
         cat #{node.kmon.public_key} >> /root/.ssh/authorized_keys
        EOF
        not_if "test -f /root/.ssh/authorized_keys"
      end
    end
  end
end
