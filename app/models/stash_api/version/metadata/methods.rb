# frozen_string_literal: true

require_relative 'metadata_item'

module StashApi
  class Version
    class Metadata
      class Methods < MetadataItem

        def value
          items = @resource.descriptions.type_methods.map(&:description)
          return items.first unless items.blank?

          nil
        end
      end
    end
  end
end
