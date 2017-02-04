action :config do

# This is the hopsworks-wide default environment that all projects will clone their environment from.
#   #{node.anaconda.base_dir}/bin/conda create -n hopsworksconda -y -q 
# --file #{node.kagent.base_dir}/anaconda/spec-file.txt


execute "update_conda" do
  user "root"
  command "su anaconda -c \"#{node.anaconda.base_dir}/bin/conda update conda -y -q\""
end

execute "update_anconda" do
  user "root"
  command "su anaconda -c \"#{node.anaconda.base_dir}/bin/conda update anaconda -y -q\""
end

execute "create_base" do
  user "root"
  command "su #{node.kagent.user} -c \"#{node.anaconda.base_dir}/bin/conda create -n #{node.kagent.user} --clone=root\""
  not_if "test -d /home/#{node.kagent.user}/.conda/envs/#{node.kagent.user}"
end


for lib in node.anaconda.default_libs do
  bash "install_anconda_default_libs_#{lib}" do
  user node.kagent.user
    code <<-EOH
        #{node.anaconda.base_dir}/bin/conda install --name #{node.kagent.user} -q -y #{lib}"
  EOH
  end
end

end
