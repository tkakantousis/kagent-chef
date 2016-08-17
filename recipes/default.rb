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
    owner node.kagent.user
    group node.kagent.group
    mode 0650
    notifies :enable, "service[#{service_name}]"
    notifies :restart, "service[#{service_name}]", :delayed
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
    owner node.kagent.user
    group node.kagent.group
    mode 0650
    notifies :enable, "service[#{service_name}]"
    notifies :restart, "service[#{service_name}]", :delayed
  end

end



private_ip = my_private_ip()
public_ip = my_public_ip()

dashboard_endpoint = "10.0.2.15"  + ":" + node.kagent.dashboard.port 

if node.attribute? "hopsworks"
  begin
    dashboard_endpoint = private_recipe_ip("hopsworks","default")  + ":" + node.kagent.dashboard.port    
  rescue
    dashboard_endpoint =
    Chef::Log.warn "could not find the hopsworks server ip to register kagent to!"
  end
end

network_if = node.kagent.network.interface

# If the network i/f name not set by the user, set default values for ubuntu and centos
if network_if == ""
  case node.platform_family
  when "debian"
    network_if = "eth0"
  when "rhel"
    network_if = "enp0s3"
  end
end


template "#{node.kagent.base_dir}/bin/start-all-local-services.sh" do
  source "start-all-local-services.sh.erb"
  owner node.kagent.user
  group node.kagent.group
  mode 0740
end

template "#{node.kagent.base_dir}/bin/shutdown-all-local-services.sh" do
  source "shutdown-all-local-services.sh.erb"
  owner node.kagent.user
  group node.kagent.group
  mode 0740
end

template "#{node.kagent.base_dir}/bin/status-all-local-services.sh" do
  source "status-all-local-services.sh.erb"
  owner node.kagent.user
  group node.kagent.group
  mode 0740
end


#
# Certificate Signing code - Needs Hopsworks dashboard
#


template "#{node.kagent.base_dir}/keystore.sh" do
  source "keystore.sh.erb"
  owner node.kagent.user
  group node.kagent.group
  mode 0700
   variables({
              :directory => node.kagent.keystore_dir,
              :keystorepass => node.hopsworks.master.password 
            })
end


template "#{node.kagent.base_dir}/config.ini" do
  source "config.ini.erb"
  owner node.kagent.user
  group node.kagent.group
  mode 0600
  variables({
              :rest_url => "http://#{dashboard_endpoint}/#{node.kagent.dashboard_app}",
              :rack => '/default',
              :public_ip => public_ip,
              :private_ip => private_ip,
              :network_if => network_if
            })
  notifies :enable, "service[#{service_name}]"
  notifies :restart, "service[#{service_name}]", :delayed
end

kagent_keys "sign-certs" do
 action :csr
end

execute "service kagent stop"
execute "rm -f #{node.kagent.pid_file}"

case node.platform_family
when "rhel"

  bash "disable-iptables" do
    code <<-EOH
    service iptables stop
  EOH
    only_if "test -f /etc/init.d/iptables && service iptables status"
  end

end

if node.kagent.allow_ssh_access == 'true'

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
