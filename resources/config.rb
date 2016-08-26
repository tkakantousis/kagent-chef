actions :add, :systemd_reload

attribute :role, :kind_of => String, :name_attribute => true, :required => true
attribute :service, :kind_of => String, :required => true
attribute :web_port, :kind_of => Integer, :default => 0
attribute :log_file, :kind_of => String, :required => true
attribute :config_file, :kind_of => String, :default => ""
attribute :command, :kind_of => String, :default => ""
attribute :command_user, :kind_of => String, :default => ""
attribute :command_script, :kind_of => String, :default => ""

default_action :add
