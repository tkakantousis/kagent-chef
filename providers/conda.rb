action :config do

# This is the hopsworks-wide default environment that all projects will clone their environment from.
#   #{node.anaconda.base_dir}/bin/conda create -n hopsworksconda -y -q 
# --file #{node.kagent.base_dir}/anaconda/spec-file.txt

bash "update_conda_root" do
  user node.kagent.user
  group node.kagent.group
  timeout 7200
  code <<-EOF
   #{node.anaconda.base_dir}/bin/conda update conda -y -q
   #{node.anaconda.base_dir}/bin/conda update anaconda -y -q
 EOF
end

   # #{node.anaconda.base_dir}/bin/conda config --add create_default_packages numpy 
   # #{node.anaconda.base_dir}/bin/conda config --add create_default_packages hdfs3
   # #{node.anaconda.base_dir}/bin/conda config --add create_default_packages scikit-learn 
   # #{node.anaconda.base_dir}/bin/conda config --add create_default_packages matplotlib 
   # #{node.anaconda.base_dir}/bin/conda config --add create_default_packages pandas 


bash 'create_default_anaconda_env' do
  user node.kagent.user
  group node.kagent.group
  timeout 7200
  code <<-EOF
     #{node.kagent.base_dir}/bin/anaconda_env.sh #{node.kagent.user} install
    EOF
  not_if "source <%= node.anaconda.base_dir %>/bin/activate #{node.kagent.user}"
end


# bash "update_conda" do
#   user node.kagent.user
#   group node.kagent.group
#   code <<-EOF
#    #{node.anaconda.base_dir}/bin/conda config --add create_default_packages numpy 
#  EOF
# end


end
