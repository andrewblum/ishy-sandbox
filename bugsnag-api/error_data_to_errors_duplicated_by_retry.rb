#!/usr/bin/ruby

require 'pry'
require 'json'

input = File.read(ARGV[0])
project_error_data = JSON.parse(input)

potential_retriable_errors = project_error_data.map do |project_data|
  project_errors = project_data['project_errors']

  total_retries = 5
  project_data['project_errors'] = project_errors.select do |project_error|
    # We want unhandled production errors where the last event has retry set,
    # and retry_count being the last retry

    release_stages = project_error['release_stages']
    next false if !release_stages.include?('production')

    last_event = project_error['last_event']
    next false if !last_event['unhandled']

    sidekiq_msg = last_event.dig('metaData', 'sidekiq', 'msg')
    next false if sidekiq_msg.nil?

    retry_option = sidekiq_msg['retry']
    next false if retry_option.nil? || !retry_option.is_a?(Integer) || retry_option.zero?

    total_retries = sidekiq_msg['retry']
    sidekiq_msg['retry_count'] == sidekiq_msg['retry'] - 1
  end

  {
      'project_name' => project_data['project_name'],
      'project_errors' => project_data['project_errors'].map{ |project_error| project_error['id'] },
      'count' => project_data['project_errors'].count,
      'duplicate_count' => (project_data['project_errors'].sum{ |project_error| project_error['unthrottled_occurrence_count'] }.to_f * ((total_retries - 1).to_f/total_retries.to_f)).round
  }
end

puts "Total events: #{potential_retriable_errors.sum { |potential_retriable_error| potential_retriable_error['duplicate_count'] }}"

File.open("errors_duplicated_by_retry.json","w") do |f|
  f.write(potential_retriable_errors.to_json)
end