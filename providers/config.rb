action :add do
  ini_file = IniFile.load(node[:kagent][:services], :comment => ';#')
  cluster = "#{node[:kagent][:cluster]}"
  service = "#{new_resource.service}"
  role = "#{new_resource.role}"
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
    'start-script'  => "#{new_resource.start_script}",
    'stop-script'  => "#{new_resource.stop_script}",
    'init-script'  => "#{new_resource.init_script}",
    'pid-file'  => "#{new_resource.pid_file}",
    'stdout-file'  => "#{new_resource.log_file}",
    'config-file'  => "#{new_resource.config_file}",
    'command'  => "#{new_resource.command}",
    'command-user'  => "#{new_resource.command_user}",
    'command-script'  => "#{new_resource.command_script}",
    'status' => 'Stopped'
  } 
  ini_file.save
  Chef::Log.info "Saved an updated copy of services file at the kagent after updating #{cluster}-#{service}-#{role}"

  new_resource.updated_by_last_action(true)
end

