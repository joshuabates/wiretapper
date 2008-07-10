# Include hook code here
begin
  require "mechanize" 
rescue LoadError
  raise "Fake mechanics requires the mechanize gem"
end

require "fake_mechanics"