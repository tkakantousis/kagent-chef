
#
# Read notes on what needs to be done for pyspark here:
# http://blog.cloudera.com/blog/2015/09/how-to-prepare-your-apache-hadoop-cluster-for-pyspark-jobs/
#

node.override.anaconda.accept_license = "yes"
node.override.anaconda.owner = node.kagent.user
node.override.anaconda.group = node.kagent.group
node.override.anaconda.flavor = "x86_64"
node.override.anaconda.python = "python2"
#node.override.anaconda.install_root = node.anaconda.dir

#include_recipe "anaconda::python_workaround"

include_recipe "anaconda::default"

include_recipe "anaconda::shell_conveniences"


link node.anaconda.base_dir do
  action :delete
  only_if "test -L #{node.anaconda.base_dir}"
end

link node.anaconda.base_dir do
  owner node.anaconda.user
  group node.anaconda.group
  to node.anaconda.home
end

