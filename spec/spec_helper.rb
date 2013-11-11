ENV['RACK_ENV'] = 'test'

require 'webmock/rspec'
require "rack/test"
require 'simplecov'

SimpleCov.start

require './app'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir["./spec/support/**/*.rb"].each {|f| require f}
