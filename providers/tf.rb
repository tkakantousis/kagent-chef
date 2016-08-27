action :add do

  ini_file = IniFile.load(node.tf.services, :comment => ';#')
  cluster = "#{node.kagent.cluster}"
  resource = "#{new_resource.resource}"
  id = "#{new_resource.id}"

#
# A section name will have the format: ${CLUSTERNAME}-${RESOURCENAME}-${ID}
# The ID is allowed to include '-' (separator character), but the clustername or resourcename
# is not allowed to include a '-' in their name
#
  if cluster.include?("-") || resource.include?("-") 
    raise "Invalid cluster or resource name. Cannot contain  '-'" 
  end
  section="#{cluster}-#{resource}-#{id}"

  if ini_file.has_section?(section)
    Chef::Log.info "Over-writing an existing section in the ini file."
    ini_file.delete_section(section)
  end
  ini_file[section] = {
    'cluster' => "#{cluster}",
    'resource'  => "#{resource}",
    'id'  => "#{id}",
    'projuser' => "",
    'starttime' => "",
    'pidfile' => "",
    'program' => "",
    'args' => "",
    'log' => "",
    'status' => 'Free'
  } 
  ini_file.save

  new_resource.updated_by_last_action(true)
end
