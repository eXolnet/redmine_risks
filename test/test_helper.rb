$VERBOSE = nil # for hide ruby warnings

# Load the Redmine helper
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

module RedmineRisks
  module TestHelper
    def compatible_request(type, action, parameters = {})
      return send(type, action, :params => parameters) if Rails.version >= '5.1'
      send(type, action, parameters)
    end

    def compatible_xhr_request(type, action, parameters = {})
      return send(type, action, :params => parameters, :xhr => true) if Rails.version >= '5.1'
      xhr type, action, parameters
    end

    def compatible_api_request(type, action, parameters = {}, headers = {})
      return send(type, action, :params => parameters, :headers => headers) if Redmine::VERSION.to_s >= '3.4'
      send(type, action, parameters, headers)
    end
  end
end

include RedmineRisks::TestHelper
