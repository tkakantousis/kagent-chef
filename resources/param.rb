require 'json'

actions :add

attribute :path, :kind_of => String, :name_attribute => true, :required => true
attribute :executing_cookbook, :kind_of => String, :required => true
attribute :executing_recipe, :kind_of => String, :required => true
attribute :cookbook, :kind_of => String, :required => true
attribute :recipe, :kind_of => String, :required => true
attribute :subrecipe, :kind_of => String, :default => ""
attribute :subsubrecipe, :kind_of => String, :default => ""
attribute :param, :kind_of => String, :required => true
attribute :value, :kind_of => String, :required => true

default_action :add

