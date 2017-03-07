#
# Read notes on what needs to be done for pyspark here:
# http://blog.cloudera.com/blog/2015/09/how-to-prepare-your-apache-hadoop-cluster-for-pyspark-jobs/
#

node.override.anaconda.accept_license = "yes"
node.override.anaconda.user = node.kagent.user
node.override.anaconda.group = node.kagent.group
node.override.anaconda.flavor = "x86_64"
node.override.anaconda.python = "python2"

# Bugs: Changing the install path led to problems.
#node.override.anaconda.install_root = node.anaconda.dir
# Bug 2: it still installs as user 'anaconda'. Need to change ownership afterwards.

include_recipe "anaconda::default"


link node.anaconda.base_dir do
  action :delete
  only_if "test -L #{node.anaconda.base_dir}"
end

link node.anaconda.base_dir do
  owner node.anaconda.user
  group node.anaconda.group
  to node.anaconda.home
end

magic_shell_environment 'PATH' do
  value "$PATH:#{node.anaconda.base_dir}/bin"
end

kagent_conda "packages" do
  action :config
end


