action :config do

# This is the hopsworks-wide default environment that all projects will clone their environment from.
#   #{node.anaconda.base_dir}/bin/conda create -n hopsworksconda -y -q 
# --file #{node.kagent.base_dir}/anaconda/spec-file.txt

execute "create_base" do
  user node.kagent.user
  command "#{node.anaconda.base_dir}/bin/conda create -n #{node.kagent.user} --clone=root"
  not_if "source <%= node.anaconda.base_dir %>/bin/activate #{node.kagent.user}"
end

execute "update_conda" do
  user node.kagent.user
  command "#{node.anaconda.base_dir}/bin/conda update conda -y -q"
end

execute "update_anconda" do
  user node.kagent.user
  command "#{node.anaconda.base_dir}/bin/conda update anaconda -y -q"
end

for lib in node.anaconda.default_libs do
  execute "install_anconda_default_libs" do
    user node.kagent.user
    command "#{node.anaconda.base_dir}/bin/conda install -q -y #{lib}"
  end
end

end
