action :config do

  execute "update_conda" do
   user "root"
   command "su #{node["conda"]["user"]} -c \"#{node["conda"]["base_dir"]}/bin/conda update conda -y -q\""
 end

 execute "update_anconda" do
   user "root"
   command "su #{node["conda"]["user"]} -c \"#{node["conda"]["base_dir"]}/bin/conda update anaconda -y -q\""
 end

#
# Install libraries into the root environment
#
for lib in node["conda"]["default_libs"] do
  execute "install_anconda_default_libs" do
    user "root"
    command "su #{node["conda"]["user"]} -c \"#{node["conda"]["base_dir"]}/bin/conda install -q -y #{lib}\""
# The guard checks if the library is installed. Be careful with library names like 'sphinx' and 'sphinx_rtd_theme' - add space so that 'sphinx' doesnt match both.
    not_if  "su #{node["conda"]["user"]} -c \"#{node["conda"]["base_dir"]}/bin/conda list | grep \"#{lib} \"\""
  end
end


execute "create_base" do
  user "root"
  command "su #{node["conda"]["user"]} -c \"#{node["conda"]["base_dir"]}/bin/conda create -n #{node["conda"]["user"]}\""
  not_if "test -d #{node["conda"]["base_dir"]}/envs/#{node["conda"]["user"]}"
end


end
