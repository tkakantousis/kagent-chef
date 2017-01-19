action :config do



bash "update_conda" do
  user node.anaconda.owner
  group node.ananconda.group
  code <<-EOF
#   #{node.anaconda.base_dir}/bin/conda update conda -y -q
#   #{node.anaconda.base_dir}/bin/conda update anaconda -y -q
# This is the hopsworks-wide default environment that all projects will clone their environment from.
   #{node.anaconda.base_dir}/bin/conda config --add create_default_packages numpy 
   #{node.anaconda.base_dir}/bin/conda config --add create_default_packages hdfs3
   #{node.anaconda.base_dir}/bin/conda config --add create_default_packages scikit-learn 
   #{node.anaconda.base_dir}/bin/conda config --add create_default_packages matplotlib 
   #{node.anaconda.base_dir}/bin/conda config --add create_default_packages pandas 
#   #{node.anaconda.base_dir}/bin/conda create -n hopsworksconda -y -q 
# --file #{node.kagent.base_dir}/anaconda/spec-file.txt
 EOF
end


end
