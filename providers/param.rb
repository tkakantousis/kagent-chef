require 'json'

def deep_merge(h1, h2)
  h1.merge(h2) { |key, h1_elem, h2_elem| deep_merge(h1_elem, h2_elem) }
end

action :add do

  path = "#{new_resource.path}"
  cookbook = "#{new_resource.cookbook}"
  recipe = "#{new_resource.recipe}"
  param = "#{new_resource.param}"
  value = "#{new_resource.value}"
  executing_cookbook = "#{new_resource.executing_cookbook}"
  executing_recipe = "#{new_resource.executing_recipe}"

# The result will be written to file in this json format
  entry_hash = {"#{cookbook}" => { "#{recipe}" => { "#{param}" => "#{value}" }}}

  filename = "#{path}/#{executing_cookbook}__#{executing_recipe}__output.json"
# 'w+' : Read and write access. Pointer is positioned at start of file.
# We will overwrite the file with a new json object.
  file = ::File.new(filename, "w+")
  if ::File.file?(filename) && (not ::File.zero?(filename))
     data_json = JSON.parse(file)
  else
     data_hash = Hash.new
  end

  data_hash = deep_merge(data_hash, entry_hash)
  file.puts(JSON.pretty_generate(data_hash))
  file.close
end

