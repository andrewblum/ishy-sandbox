#!/usr/bin/ruby

require 'bugsnag/api'
require 'pry'
require 'json'

secrets_json = File.read("secrets.json")
token = JSON.parse(secrets_json)['bugsnag_auth_token']

cache_json = File.exist?("cache.json") && File.read("cache.json")
$cache = cache_json ? JSON.parse(cache_json) : {}

$client = Bugsnag::Api::Client.new(auth_token: token)

def make_request(method, arg)
  while true
    begin
      if $cache.key?("#{method}#{arg}")
        return $cache["#{method}#{arg}"]
      else
        result = arg.nil? ? $client.send(method) : $client.send(method, arg)
        result = result.is_a?(Array) ? result.map{ |d| d.to_h.transform_keys { |k| k.to_s } } : result.to_h.transform_keys { |k| k.to_s }
        $cache["#{method}#{arg}"] = result
        return result
      end
    rescue Bugsnag::Api::RateLimitExceeded
      sleep(5)
      next
    end
  end
end

def get_error_data_from_project(project_id)
  make_request(:errors, project_id).map do |error|
    error.merge!(last_event: make_request(:latest_event, error['id']).slice('id', 'metaData', 'unhandled'))
    error
  end
end

organization =  make_request(:organizations, nil)[0] # Assume there is only one org (Gusto)

projects_json = File.read("projects.json")
requested_projects = JSON.parse(projects_json)['projects']
projects = make_request(:projects, organization['id']).select{ |project| !(requested_projects & ['*',  project['name']]).empty? }

puts "Processing #{projects.count} projects"

project_errors = []
projects.each_with_index do |project, index|
  puts "#{index}: Processing #{project['name']}"

  project_error_data = {
      'project_id': project['id'],
      'project_name': project['name'],
      'project_errors': get_error_data_from_project(project['id'])
  }

  project_errors << project_error_data
end

# print project_errors

File.open("all_errors_output.json","w") do |f|
  f.write(project_errors.to_json)
end

File.open("cache.json","w") do |f|
  f.write($cache.to_json)
end