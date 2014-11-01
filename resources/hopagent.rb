actions :restart, :gems_install

def initialize( *args )
  super
  @action = :restart
end
