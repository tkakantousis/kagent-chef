action :config do

# This is the hopsworks-wide default environment that all projects will clone their environment from.
#   #{node.anaconda.base_dir}/bin/conda create -n hopsworksconda -y -q 
# --file #{node.kagent.base_dir}/anaconda/spec-file.txt

execute "change_owner_to_kagent" do
  user "root"
  command "chown -R #{node.kagent.user}:#{node.kagent.group} #{node.anaconda.home}"
end
  
execute "update_conda" do
  user "root"
  command "su #{node.kagent.user} -c \"#{node.anaconda.base_dir}/bin/conda update conda -y -q\""
end

execute "update_anconda" do
  user "root"
  command "su #{node.kagent.user} -c \"#{node.anaconda.base_dir}/bin/conda update anaconda -y -q\""
end

#
# Install libraries into the root environment
#
for lib in node.anaconda.default_libs do
  execute "install_anconda_default_libs" do
    user "root"
    command "su #{node.anaconda.user} -c \"#{node.anaconda.base_dir}/bin/conda install -q -y #{lib}\""
# The guard checks if the library is installed. Be careful with library names like 'sphinx' and 'sphinx_rtd_theme' - add space so that 'sphinx' doesnt match both.
    not_if  "su #{node.anaconda.user} -c \"#{node.anaconda.base_dir}/bin/conda list | grep \"#{lib} \"\""
  end
end


execute "create_base" do
  user "root"
  command "su #{node.kagent.user} -c \"#{node.anaconda.base_dir}/bin/conda create -n #{node.kagent.user}\""
  not_if "test -d #{node.anaconda.base_dir}/envs/#{node.kagent.user}"
end


end
