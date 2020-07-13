#!/usr/bin/ruby

require 'pry'
require 'json'
require 'csv'

input = File.read(ARGV[0])
project_error_data = JSON.parse(input)

potential_retriable_errors = project_error_data.map do |project_data|
  project_errors = project_data['project_errors']

  total_project_events = 0
  project_data['project_errors'] = project_errors.select do |project_error|
    # We want unhandled production errors where the last event has retry set,
    # but retry_count not set

    total_project_events += project_error['unthrottled_occurrence_count']

    release_stages = project_error['release_stages']
    next false if !release_stages.include?('production')

    last_event = project_error['last_event']
    next false if !last_event['unhandled']

    sidekiq_msg = last_event.dig('metaData', 'sidekiq', 'msg')
    next false if sidekiq_msg.nil?

    retry_option = sidekiq_msg['retry']
    next false if retry_option.nil? || !retry_option.is_a?(Integer) || retry_option.zero?

    sidekiq_msg['retry_count'].nil?
  end

  event_count = project_data['project_errors'].sum{ |project_error| project_error['unthrottled_occurrence_count'] }

  {
      'project_name' => project_data['project_name'],
      'project_errors' => project_data['project_errors'].map{ |project_error| project_error['id'] },
      'count' => project_data['project_errors'].count,
      'event_count' => event_count,
      'total_project_events' => total_project_events,
      'event_ratio' => event_count.zero? ? 0 : (event_count.to_f / total_project_events.to_f) * 100
  }
end

puts "Total events: #{potential_retriable_errors.sum { |potential_retriable_error| potential_retriable_error['event_count'] }}"

File.open("errors_successful_on_retry.json","w") do |f|
  f.write(potential_retriable_errors.to_json)
end

CSV.open("errors_successful_on_retry.csv", "w", write_headers: true, headers: potential_retriable_errors.first.keys) do |csv|
  potential_retriable_errors.each do |hash|
    csv << hash.values
  end
end