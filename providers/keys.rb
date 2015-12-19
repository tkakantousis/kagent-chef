action :generate do
  homedir = "#{new_resource.homedir}"
  cb_user = "#{new_resource.cookbook_user}"
  cb_group = "#{new_resource.cookbook_group}"

  bash "generate-ssh-keypair-for-#{homedir}" do
    user cb_owner
    group cb_group
    code <<-EOF
     ssh-keygen -b 2048 -f #{homedir}/.ssh/id_rsa -t rsa -q -N ''
  EOF
    not_if { ::File.exists?( "#{homedir}/.ssh/id_rsa" ) }
  end
end


action :return_publickey do
 homedir = "#{new_resource.homedir}"
 contents = ::IO.read("#{homedir}/.ssh/id_rsa.pub")

 raise if contents.empty?
 
 Chef::Log.info "Public key read is: #{contents}"
 cb = "#{new_resource.cookbook_name}"
 recipeName = "#{new_resource.cookbook_recipe}"
 cb_user = "#{new_resource.cookbook_user}"
 cb_group = "#{new_resource.cookbook_group}"

 node.default["#{cb}"]["#{r}"][:public_key] = contents
# This works for chef-solo - we are executing this recipe.rb file.
# recipeName = "#{__FILE__}".gsub(/.*\//, "")
# recipeName = "#{recipeName}".gsub(/\.rb/, "")


  template "#{homedir}/.ssh/config" do
    source "ssh_config.erb" 
    owner cb_user
    group cb_group
    mode 0600
  end
 
 kagent_param "/tmp" do
   executing_cookbook cb
   executing_recipe  recipeName
   cookbook cb
   recipe recipeName
   param "public_key"
   value  "#{contents}"
 end
end

action :get_publickey do
  homedir = "#{new_resource.homedir}"
  cb = "#{new_resource.cookbook_name}"
  recipeName = "#{new_resource.cookbook_recipe}"
  cb_user = "#{new_resource.cookbook_user}"
  cb_group = "#{new_resource.cookbook_group}"

  key_contents = node["#{cb}"]["#{recipeName}"][:public_key]
  guard = ".#{cb}_#{recipeName}_key_authorized"
  Chef::Log.debug "Public key read is: #{key_contents}"
  bash "add_#{cb}_#{recipeName}_public_key" do
    user cb_owner
    group cb_group
    code <<-EOF
      set -e
      if [ ! -d #{homedir}/.ssh ] ; then
        mkdir #{homedir}/.ssh
      fi
      echo "#{key_contents}" >> #{homedir}/.ssh/authorized_keys
      touch #{homedir}/.ssh/#{guard}
  EOF
    not_if { ::File.exists?( "#{homedir}/.ssh/#{guard}" || "#{key_contents}".empty? ) }
  end
end
