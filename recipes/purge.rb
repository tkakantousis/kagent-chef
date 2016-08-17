daemons = %w{kagent}
daemons.each { |d| 

  bash 'kill_running_service_#{d}' do
    user "root"
    ignore_failure true
    code <<-EOF
      service stop #{d}
      systemctl stop #{d}
      pkill -9 #{d}
    EOF
  end

  file "/etc/init.d/#{d}" do
    action :delete
    ignore_failure true
  end
  
case node.platform_family
when "debian"
  file "/lib/systemd/system/#{d}.service" do
    action :delete
    ignore_failure true
  end
when "rhel"
  file "/usr/lib/systemd/system/#{d}.service" do
    action :delete
    ignore_failure true
  end
end
}

# Remove the MySQL binaries and MySQL Cluster data directories
directory node.kagent.base_dir do
  recursive true
  action :delete
  ignore_failure true
end

directory node.kagent.home do
  recursive true
  action :delete
  ignore_failure true
end

directory node.kagent.certs_dir do
  recursive true
  action :delete
  ignore_failure true
end
