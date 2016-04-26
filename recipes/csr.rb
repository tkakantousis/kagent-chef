
template"#{node.kagent.base_dir}/csr.py" do
  source "csr.py.erb"
  owner node.kagent.run_as_user
  group node.kagent.run_as_user
  mode 0655
  variables({
     :cert => "kafka"
})
end

private_ip = my_private_ip()
public_ip = my_public_ip()

dashboard_endpoint = ""
#dashboard_endpoint = "bbc1.sics.se:14009"
 if node.attribute? "hopsworks"
    dashboard_endpoint = private_recipe_ip("hopsworks","default")  + ":" + node.kagent.dashboard.port
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

template "#{node.kagent.base_dir}/config-csr.ini" do
  source "config-csr.ini.erb"
  owner node.kagent.run_as_user
  group node.kagent.run_as_user
  mode 0600
  variables({
              :rest_url => "http://#{dashboard_endpoint}/#{node.kagent.dashboard_app}",
              :rack => '/default',
              :public_ip => public_ip,
              :private_ip => private_ip,
              :network_if => network_if,
              :username => node.kagent.dashboard.user,
              :password => node.kagent.dashboard.password 
            })
end
