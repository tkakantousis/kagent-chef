action :add do
  ini_file = IniFile.load(node.kagent.services, :comment => ';#')
  cluster = "#{node.kagent.cluster}"
  service = "#{new_resource.service}"
  role = "#{new_resource.role}"

#
# A section name will have the format: ${CLUSTERNAME}-${SERVICENAME}-${ROLENAME}
# The ROLENAME is allowed to include '-' (separator character), but the clustername or servicename
# is not allowed to include a '-' in their name
# The ROLENAME will be the actual name of the script as used by init.d and systemd.
# The agent.py program will use start/stop/restart/status the service by calling, e.g., 
# systemctl start ROLENAME
#
  if cluster.include?("-") || service.include?("-") 
    raise "Invalid cluster or service name. Cannot contain  '-'" 
  end
  section="#{cluster}-#{service}-#{role}"
  Chef::Log.info "Loaded kagent services ini-file #{ini_file} with : #{section}"

  if ini_file.has_section?(section)
    Chef::Log.info "Over-writing an existing section in the ini file."
    ini_file.delete_section(section)
  end
  ini_file[section] = {
    'cluster' => "#{cluster}",
    'service'  => "#{service}",
    'role'  => "#{role}",
    'web-port' => new_resource.web_port,
    'stdout-file'  => "#{new_resource.log_file}",
    'config-file'  => "#{new_resource.config_file}"
#    'command'  => "#{new_resource.command}",
#    'command-user'  => "#{new_resource.command_user}",
#    'command-script'  => "#{new_resource.command_script}",
#    'status' => 'Stopped'
  } 
  ini_file.save
  Chef::Log.info "Saved an updated copy of services file at the kagent after updating #{cluster}-#{service}-#{role}"

  new_resource.updated_by_last_action(true)
end



action :systemd_reload do
  bash "start-if-not-running-#{new_resource.name}" do
    user "root"
    code <<-EOH
     set -e
     systemctl daemon-reload
    EOH
  end

end

