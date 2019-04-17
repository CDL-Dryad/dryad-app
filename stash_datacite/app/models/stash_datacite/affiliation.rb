# frozen_string_literal: true

require 'stash/organization/ror'

module StashDatacite
  class Affiliation < ActiveRecord::Base

    include Stash::Organization::Ror

    self.table_name = 'dcs_affiliations'
    has_and_belongs_to_many :authors, class_name: 'StashEngine::Author', join_table: 'dcs_affiliations_authors'
    has_and_belongs_to_many :contributors, class_name: 'StashDatacite::Contributor'

    before_save :strip_whitespace

    # prefer short_name if it is set over long name and make string
    def smart_name
      return '' if short_name.blank? && long_name.blank?
      (short_name.blank? ? long_name.strip : short_name.strip)
    end

    def fee_waivered?
      return false if ror_id.blank?
      # Retrieve the ROR record and then check if itys a fee waiver country
      ror_org = find_by_ror_id(ror_id)
      return false unless ror_org.present? && ror_org.country.present? && ror_org.country[:name].present?
      fee_waiver_countries&.include?(ror_org.country[:name])
    end

    def fee_waiver_countries
      APP_CONFIG.fee_waiver_countries || []
    end

    private

    def strip_whitespace
      self.long_name = long_name.strip unless long_name.nil?
    end

  end
end
