#require 'json'

kagent_param "/tmp" do
  cookbook "kagent"
  recipe "test"
  param "param"
  value "value"
end

kagent_param "/tmp" do
  executing_cookbook "#{cookbook_name}"
  executing_recipe "#{recipe_name}"
  cookbook "kagent"
  recipe "test"
  param "param2"
  value "value2"
end

kagent_param "/tmp" do
  executing_cookbook "kagent2"
  executing_recipe "test2"
  cookbook "ndb"
  recipe "mgmd"
  param "opensshkey"
  value "xxxxxxxxxxxxxxxxxxxx"
end
