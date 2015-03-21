require 'json'

kagent_param "/tmp" do
  cookbook "kagent"
  recipe "test"
  param "param"
  value "value"
end

kagent_param "/tmp" do
  cookbook "kagent"
  recipe "test"
  param "param2"
  value "value2"
end

kagent_param "/tmp" do
  cookbook "ndb"
  recipe "mgmd"
  param "opensshkey"
  value "xxxxxxxxxxxxxxxxxxxx"
end
