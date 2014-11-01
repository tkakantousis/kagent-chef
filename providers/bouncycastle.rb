action :install do

    package_url = node[:java][:bouncycastle_url]
    Chef::Log.info "Downloading bouncy castle jar from #{node[:java][:bouncycastle_url]}"
    base_package_filename =  Chef::Recipe::File.basename(node[:java][:bouncycastle_url])
    Chef::Log.info "Into file #{base_package_filename}"

    remote_file "#{Chef::Config[:file_cache_path]}/#{base_package_filename}" do
      source package_url
      mode "0644"
      action :create_if_missing
    end

    bash 'add_bouncycastle_security' do
      user "root"
      code <<-EOF
    cp #{Chef::Config[:file_cache_path]}/#{base_package_filename} #{node[:java][:java_home]}/jre/lib/ext/
    NUM=`cat #{node[:java][:java_home]}/jre/lib/security/java.security | grep ^security.provider.[0-9+] | wc -l`
    NUM=`expr $NUM + 1`    
#    find /usr/lib/jvm -name "java.security" -exec bash -c "echo 'security.provider.${NUM}=org.bouncycastle.jce.provider.BouncyCastleProvider' >> {}"\;
    echo "security.provider.${NUM}=org.bouncycastle.jce.provider.BouncyCastleProvider" >> #{node[:java][:java_home]}/jre/lib/security/java.security
    if ! [ test -d /usr/lib/jvm/default-java ] ; then
      ln -s #{node[:java][:java_home]} /usr/lib/jvm/default-java
    fi
    touch #{node[:java][:java_home]}/.bouncycastle_installed
    EOF
      not_if "test -f #{node[:java][:java_home]}/.bouncycastle_installed"
    end



end
