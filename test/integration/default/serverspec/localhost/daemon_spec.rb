require 'spec_helper'

describe service('kagent') do  
  it { should be_enabled   }
  it { should be_running   }
end 

describe file('/tmp/kagent/services') do
  it { should be_file }
end

describe file('/tmp/kagent/config.ini') do
  it { should be_file }
  its(:content) { should match /agent/ }
end
