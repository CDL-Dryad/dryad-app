require 'logger'

module RelatedIdentifiers
  class TsvUpdating
    def initialize(filename:)
      @filename = filename
      @logger = Logger.new(File.join(File.dirname(@filename), "#{File.basename(@filename, '.*')}.log"))
    end

    # this is the sheet for good identifiers and looks like this
    # dataset_identifier	resource_id	related_identifier	relation_type	Related Work Type
    # 10.5061/dryad.5tb2rbp0n	40119	https://doi.org/10.1002/ece3.5799	iscitedby	Article
    # 10.5061/dryad.sj3tx9629	63993	https://doi.org/10.1002/ecy.3033	iscitedby	Article
    # 10.5061/dryad.sj3tx9629	64737	https://doi.org/10.1002/ecy.3033	iscitedby	Article
    # The thing to update off here are the resource_id and related_identifier since we don't have the id
    def update_sheet1
      @logger.info("Started run")
      File.open(@filename, 'r').each_with_index do |line, idx|
        next if idx == 0 || line.strip == ''
        cols = line.split("\t").map(&:strip)
        puts cols
        # related = StashDatacite.where()
        break if idx == 10
      end
    end
  end
end
