module StashDatacite
  class Creator < ActiveRecord::Base
    self.table_name = 'dcs_creators'
    belongs_to :resource, class_name: StashDatacite.resource_class.to_s
    belongs_to :name_identifier
    belongs_to :affliation

    scope :filled, -> { joins(:affliation).
        where("TRIM(IFNULL(creator_first_name,'')) <> '' AND TRIM(IFNULL(creator_last_name,'')) <> ''") }

    scope :names_filled, -> { where("TRIM(IFNULL(creator_first_name,'')) <> '' AND TRIM(IFNULL(creator_last_name,'')) <> ''") }


    scope :affliation_filled, -> { joins(:affliation).
        where("TRIM(IFNULL(dcs_affliations.long_name,'')) <> ''") }


    def creator_full_name
      "#{creator_last_name}, #{creator_first_name}".strip
    end
  end
end
