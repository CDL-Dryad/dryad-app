# frozen_string_literal: true

module StashDatacite
  class Size < ActiveRecord::Base
    self.table_name = 'dcs_sizes'
    belongs_to :resource, class_name: StashEngine::Resource.to_s
    include StashEngine::Concerns::ResourceUpdated
  end
end
