#
# Read notes on what needs to be done for pyspark here:
# http://blog.cloudera.com/blog/2015/09/how-to-prepare-your-apache-hadoop-cluster-for-pyspark-jobs/
#

node.override.conda.accept_license = "yes"

if node.attribute?(:hops) and node.hops.attribute?(:yarn) and node.hops.yarn.attribute?(:user)
  node.override.conda.user = node.hops.yarn.user
  node.override.conda.group = node.hops.group
end                             

if node.attribute?(:install) and node.hops.attribute?(:dir) and node.install.dir.empty? == false
  node.override.conda.dir = node.install.dir
end  

if node.attribute?(:install) and node.hops.attribute?(:user) and node.install.user.empty? == false
  node.override.conda.user = node.install.user
  node.override.conda.group = node.install.group
end

include_recipe "conda::install"
include_recipe "conda::default"

kagent_conda "packages" do
  action :config
end
