#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'byebug'

# other classes for this
require_relative 'submitted_reports'
require_relative 'uploader'

# setup variables needed
@report_directory = ENV['REPORT_DIR'] || File.join(File.expand_path(__dir__), 'reports')
# ENV['TOKEN'] should be set, used in uploader class
# if ENV['REPORT_IDS'] is set then just report the IDs for our reports

if ENV['REPORT_IDS'].nil? && (ENV['TOKEN'].nil? || ENV['REPORT_DIR'].nil?)
  puts 'You must set environment variables for the TOKEN and REPORT_DIR to upload to DataCite'
  exit(1)
end

# get the json files we have non-zero reports for and are in the correct filename format
@json_files = Dir.glob(File.join(@report_directory, '*.json'))
@json_files.keep_if { |f| f.match(/\d{4}-\d{2}.json$/) && File.size(f) > 0 }
@json_files.sort!

@submitted_reports = SubmittedReports.new
@submitted_reports.process_reports

if ENV['REPORT_IDS']
  puts 'Information about submitted months'
  puts "year-month\tresults_pages\tid"
  @submitted_reports.reports.values.sort { |a, b| a.year_month <=> b.year_month }.each do |report|
    puts "#{report.year_month}\t#{report.pages}\t#{report.id}"
  end
  exit 0
end

@json_files.each do |json_file|
  month_year = File.basename(json_file, '.json')
  submitted_report = @submitted_reports.reports[month_year]
  if Helper.needs_submission?(month_year: month_year, report_info: submitted_report)
    puts "adding or updating #{month_year} with #{submitted_report&.pages || 'unsubmitted'} pages"

    report_id = (submitted_report.nil? ? nil : submitted_report.id)
    uploader = Uploader.new(report_id: report_id, file_name: json_file)
    token = uploader.process
    puts "report submitted with id #{token}\n\n"
  else
    puts "skipping #{submitted_report.year_month} with #{submitted_report.pages} pages\n\n"
  end
end

exit 0
