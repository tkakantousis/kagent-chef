#
# Read notes on what needs to be done for pyspark here:
# http://blog.cloudera.com/blog/2015/09/how-to-prepare-your-apache-hadoop-cluster-for-pyspark-jobs/
#

node.override.conda.accept_license = "yes"

include_recipe "conda::default"

kagent_conda "packages" do
  action :config
end


