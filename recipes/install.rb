# ubuntu python-mysqldb package install only works if we first run "apt-get update; apt-get upgrade"

case node.platform_family
when "debian"
  bash "apt_update_install_build_tools" do
    user "root"
    code <<-EOF
   apt-get update -y
#   DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
   apt-get install build-essential -y
   apt-get install libssl-dev -y
 EOF
  end
when "rhel"
# gcc, gcc-c++, kernel-devel are the equivalent of "build-essential" from apt.
  package "gcc" do
    action :install
  end
  package "gcc-c++" do
    action :install
  end
  package "kernel-devel" do
    action :install
  end
  package "openssl-devel" do
    action :install
  end
end


#node.override['poise-python']['options']['pip_version'] = true

#installs python 2
include_recipe "poise-python"
# The openssl::upgrade recipe doesn't install openssl-dev/libssl-dev, needed by python-ssl
# Now using packages in ubuntu/centos.
#include_recipe "openssl::upgrade"


group node.kagent.group do
  action :create
  not_if "getent group #{node.kagent.group}"
end

group node.kagent.certs_group do
  action :create
  not_if "getent group #{node.kagent.certs_group}"
end

user node.kagent.user do
  gid node.kagent.group
  supports :manage_home => true
  home "/home/#{node.kagent.user}"
  action :create
  system true
  shell "/bin/bash"
  not_if "getent passwd #{node.kagent.user}"
end

group node.kagent.group do
  action :modify
  members ["#{node.kagent.user}"]
  append true
end

group node.kagent.certs_group do
  action :modify
  members ["#{node.kagent.user}"]
  append true
end


inifile_gem = "inifile-2.0.2.gem"
cookbook_file "/tmp/#{inifile_gem}" do
  source "#{inifile_gem}"
  owner node.kagent.user
  group node.kagent.user
  mode 0755
  action :create_if_missing
end

requests="requests-1.0.3"
cookbook_file "/tmp/#{requests}.tar.gz" do
  source "#{requests}.tar.gz"
  owner node.kagent.user
  group node.kagent.user
  mode 0755
  action :create_if_missing
end

bottle="bottle-0.11.4"
cookbook_file "/tmp/#{bottle}.tar.gz" do
  source "#{bottle}.tar.gz"
  owner node.kagent.user
  group node.kagent.user
  mode 0755
  action :create_if_missing
end

cherry="CherryPy-3.2.2"
cookbook_file "/tmp/#{cherry}.tar.gz" do
  source "#{cherry}.tar.gz"
  owner node.kagent.user
  group node.kagent.user
  mode 0755
end

openSsl="pyOpenSSL-0.13"
cookbook_file "/tmp/#{openSsl}.tar.gz" do
  source "#{openSsl}.tar.gz"
  owner node.kagent.user
  group node.kagent.user
  mode 0755
  action :create_if_missing
end

# ubuntu python-mysqldb package install only works if we first run "apt-get update; apt-get upgrade"
if platform?("ubuntu", "debian") 
  package "python-mysqldb" do
   options "--force-yes"
   action :install
  end
elsif platform?("centos","redhat","fedora")
  package "MySQL-python" do
    action :install
  end
else
  python_package "MySQL-python" do
    action :install
  end
end

netifaces="netifaces-0.8"
cookbook_file "/tmp/#{netifaces}.tar.gz" do
  source "#{netifaces}.tar.gz"
  owner node.kagent.user
  group node.kagent.user
  mode 0755
  action :create_if_missing
end

ipy="IPy-0.81"
cookbook_file "/tmp/#{ipy}.tar.gz" do
  source "#{ipy}.tar.gz"
  owner node.kagent.user
  group node.kagent.user
  mode 0755
  action :create_if_missing
end

pexpect="pexpect-2.3"
cookbook_file "/tmp/#{pexpect}.tar.gz" do
  source "#{pexpect}.tar.gz"
  owner node.kagent.user
  group node.kagent.user
  mode 0755
  action :create_if_missing
end


bash "install_python" do
  user "root"
  code <<-EOF
  cd /tmp
  tar zxf "#{bottle}.tar.gz"
  cd #{bottle}
  python setup.py install
  cd ..
  tar zxf "#{requests}.tar.gz"
  cd #{requests}
  python setup.py install
  cd ..
  tar zxf "#{cherry}.tar.gz"
  cd #{cherry}
  python setup.py install
  cd ..
  tar zxf "#{openSsl}.tar.gz"
  cd #{openSsl}
  python setup.py install
  cd ..
  tar zxf "#{netifaces}.tar.gz"
  cd #{netifaces}
  python setup.py install
  cd ..
  tar zxf "#{ipy}.tar.gz"
  cd #{ipy}
  python setup.py install
  cd ..
  tar zxf "#{pexpect}.tar.gz"
  cd #{pexpect}
  python setup.py install
  touch /tmp/.python_libs_installed
 EOF
  not_if "test -f /tmp/.python_libs_installed"
end


bash "make_gemrc_file" do
  user "root"
  code <<-EOF
   echo "gem: --no-ri --no-rdoc" > ~/.gemrc
 EOF
  not_if "test -f ~/.python_libs_installed"
end

gem_package "inifile" do
  source "/tmp/#{inifile_gem}"
  action :install
end

directory node.kagent.home do
  owner node.kagent.user
  group node.kagent.group
  mode "755"
  action :create
  recursive true
end

directory node.kagent.certs_dir do
  owner node.kagent.user
  group node.kagent.certs_group
  mode "750"
  action :create
  recursive true
end


link node.kagent.base_dir do
  action :delete
  only_if "test -L #{node.kagent.base_dir}"
end

link node.kagent.base_dir do
  owner node.kagent.user
  group node.kagent.group
  to node.kagent.home
end



directory "#{node.kagent.base_dir}/bin" do
  owner node.kagent.user
  group node.kagent.group
  mode "755"
  action :create
  recursive true
end


directory node.kagent.keystore_dir do
  owner node.kagent.user
  group node.kagent.group
  mode "755"
  action :create
  recursive true
end

file node.default.kagent.services do
  owner node.kagent.user
  group node.kagent.group
  mode "755"
  action :create_if_missing
end

# set_my_hostname
if node.vagrant === "true" || node.vagrant == true 
    my_ip = my_private_ip()
  case node.platform_family
  when "debian"
    hostsfile_entry "#{my_ip}" do
      hostname  node.fqdn
      action    :create
      unique    true
    end
    hostsfile_entry "#{my_ip}" do
      hostname  node.hostname
      action    :create
      unique    true
    end
  when "rhel"
    hostsfile_entry "#{my_ip}" do
      hostname  "default-centos-70.vagrantup.com"
      unique    true
    end
  end

end


if node.ntp.install == "true"
  include_recipe "ntp::default"
end



template "#{node.kagent.base_dir}/agent.py" do
  source "agent.py.erb"
  owner node.kagent.user
  group node.kagent.group
  mode 0710
end


template"#{node.kagent.certs_dir}/csr.py" do
  source "csr.py.erb"
  owner node.kagent.user
  group node.kagent.group
  mode 0710
end


['start-agent.sh', 'stop-agent.sh', 'restart-agent.sh', 'get-pid.sh'].each do |script|
  Chef::Log.info "Installing #{script}"
  template "#{node.kagent.base_dir}/bin/#{script}" do
    source "#{script}.erb"
    owner node.kagent.user
    group node.kagent.group
    mode 0750
  end
end 

['services'].each do |conf|
  Chef::Log.info "Installing #{conf}"
  template "#{node.kagent.base_dir}/#{conf}" do
    source "#{conf}.erb"
    owner node.kagent.user
    group node.kagent.group
    mode 0644
  end
end

['start-service.sh', 'stop-service.sh', 'restart-service.sh', 'status-service.sh'].each do |script|
  template  "#{node.kagent.base_dir}/bin/#{script}" do
    source "#{script}.erb"
    owner "root"
    group node.kagent.group
    mode 0750
  end
end


template "/etc/sudoers.d/kagent" do
  source "kagent_sudoers.erb"
  owner "root"
  group "root"
  mode "0440"
  variables({
                :user => node.kagent.user,
                :start => "#{node.kagent.base_dir}/bin/start-service.sh",
                :stop => "#{node.kagent.base_dir}/bin/stop-service.sh",
                :restart => "#{node.kagent.base_dir}/bin/restart-service.sh",
                :status => "#{node.kagent.base_dir}/bin/status-service.sh",
                :startall => "#{node.kagent.base_dir}/bin/start-all-local-services.sh",
                :stopall => "#{node.kagent.base_dir}/bin/shutdown-all-local-services.sh",
                :statusall => "#{node.kagent.base_dir}/bin/status-all-local-services.sh"
              })
  action :create
end  
