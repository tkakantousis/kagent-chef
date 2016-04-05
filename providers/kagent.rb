action :restart do
  Chef::Log.info "Restarting kagent..."
  bash "restart-#{new_resource.name}" do
    user "root"
    code <<-EOF
      service kagent restart
  EOF
  end
end




action :gems_install do
 inifile_gem = "inifile-2.0.2.gem"
end
