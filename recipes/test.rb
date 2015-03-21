require 'json'

kagent_param "/tmp" do
  cookbook "kagent"
  recipe "test"
  param "param"
  value "value"
end
