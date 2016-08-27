actions :add

attribute :id, :kind_of => String, :name_attribute => true, :required => true
attribute :resource, :kind_of => String, :required => true


default_action :add
