# frozen_string_literal: true

# == Schema Information
#
# Table name: dcs_languages
#
#  id          :integer          not null, primary key
#  language    :text(65535)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  resource_id :integer
#
# Indexes
#
#  index_dcs_languages_on_resource_id  (resource_id)
#
module StashDatacite
  class Language < ApplicationRecord
    self.table_name = 'dcs_languages'
    belongs_to :resource, class_name: StashEngine::Resource.to_s
  end
end
