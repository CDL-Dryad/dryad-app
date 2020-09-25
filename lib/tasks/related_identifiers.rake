require_relative 'related_identifiers/replacements'
require_relative 'related_identifiers/tsv_updating'

namespace :related_identifiers do

  desc 'update all the DOIs I can into correct format (in separate field)'
  task fix_common_doi_problems: :environment do
    RelatedIdentifiers::Replacements.update_doi_prefix
    RelatedIdentifiers::Replacements.update_bare_doi
    RelatedIdentifiers::Replacements.move_good_format
    RelatedIdentifiers::Replacements.update_http_good
    RelatedIdentifiers::Replacements.update_http_dx_doi
    RelatedIdentifiers::Replacements.update_protocol_free
    RelatedIdentifiers::Replacements.update_non_ascii
    RelatedIdentifiers::Replacements.remaining_strings_containing_dois
  end

  desc 'update the DOIs according to sheet1'
  task fix_sheet1: :environment do
    $stdout.sync = true
    fn = '/Users/sfisher/related_fixing/sheet1.tsv'
    updater = RelatedIdentifiers::TsvUpdating.new(filename: fn)
    updater.update_sheet1
  end

  desc 'hide bad in sheet2'
  task hidden_sheet2: :environment do
    $stdout.sync = true
    fn = '/Users/sfisher/related_fixing/sheet2.tsv'
    updater = RelatedIdentifiers::TsvUpdating.new(filename: fn)
    updater.update_hidden_sheet2
  end

  desc 'update works in sheet2'
  task update_works_sheet2: :environment do
    $stdout.sync = true
    fn = '/Users/sfisher/related_fixing/sheet2.tsv'
    updater = RelatedIdentifiers::TsvUpdating.new(filename: fn)
    updater.update_works_sheet2
  end

  desc 'update tab3 where type of work set'
  task update_works_sheet3: :environment do
    $stdout.sync = true
    fn = '/Users/sfisher/related_fixing/sheet3.tsv'
    updater = RelatedIdentifiers::TsvUpdating.new(filename: fn)
    updater.update_works_sheet3
  end

  desc 'update tab4 recent works'
  task update_works_sheet4: :environment do
    $stdout.sync = true
    fn = '/Users/sfisher/related_fixing/sheet4.tsv'
    updater = RelatedIdentifiers::TsvUpdating.new(filename: fn)
    updater.update_works_sheet4
  end

  desc 'update things to have better identifiers'
  task update_unknown_better_ids: :environment do
    $stdout.sync = true
    RelatedIdentifiers::TsvUpdating.better_identifiers
  end
end
