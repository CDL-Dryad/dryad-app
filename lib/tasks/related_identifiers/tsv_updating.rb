require 'logger'
require 'byebug'

module RelatedIdentifiers
  class TsvUpdating


    def initialize(filename:)
      @filename = filename
      @logger = Logger.new(File.join(File.dirname(@filename), "#{File.basename(@filename, '.*')}.log"))

      @valid_types = StashDatacite::RelatedIdentifier::WORK_TYPES_TO_RELATION_TYPE.keys.map{ |i| i.to_s }
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

        related_ids = StashDatacite::RelatedIdentifier.where(resource_id: cols[1], related_identifier: cols[2] )
        if related_ids.length.positive?
          related_ids.each do |related_id|
            if valid_work_type?(cols[4])
              related_id.update_columns(relation_type: relation_type(cols[4]),
                                        work_type: fixed_work_type(cols[4]),
                                        verified: true,
                                        hidden: false)
            else
              @logger.error("idx: #{idx}, related_id: #{related_id.id} -- Invalid work type #{cols[4]} for resource #{cols[1]} and ID #{cols[2]}")
            end
          end
        else
          @logger.error("idx: #{idx}, Couldn't find record with resource #{cols[1]} and ID #{cols[2]}")
        end
        puts "Finished #{idx} records" if (idx % 100) == 0 && idx != 0
      end
      puts 'Done'
    end

    def update_hidden_sheet2
      @logger.info("Started run update hidden")
      count = 0
      File.open(@filename, 'r').each_with_index do |line, idx|
        next if idx == 0 || line.strip == ''

        cols = line.split("\t").map(&:strip)

        next if cols[3]&.downcase&.strip != 'no'

        related_ids = StashDatacite::RelatedIdentifier.where(resource_id: cols[1], related_identifier: cols[5] )
        if related_ids.length.positive?
          related_ids.each do |related_id|
            count += 1
            related_id.update_columns(verified: false, hidden: true)
          end
        else
          @logger.error("idx: #{idx}, Couldn't find record with resource #{cols[1]} and ID #{cols[5]}")
        end
        puts "Finished #{idx} records" if (idx % 100) == 0 && idx != 0
      end
      puts "Done:  #{count} items hidden"
    end

    def update_works_sheet2
      @logger.info("Started run sheet 2 updated works")
      count = 0
      File.open(@filename, 'r').each_with_index do |line, idx|
        next if idx == 0 || line.strip == ''

        cols = line.split("\t").map(&:strip)

        next if cols[3]&.downcase&.strip == 'no'

        shortened_like = ( cols[5].length > 10 ? cols[5][-10..-1] : str )

        related_ids = StashDatacite::RelatedIdentifier.where(resource_id: cols[1]).where("related_identifier LIKE ?", "%#{shortened_like}%" )
        if related_ids.length.positive?
          related_ids.each do |related_id|
            if valid_work_type?(cols[4])
              count += 1
              fixed_id = StashDatacite::RelatedIdentifier.standardize_format(cols[5])
              id_type = StashDatacite::RelatedIdentifier.identifier_type_from_str(fixed_id)
              validated = StashDatacite::RelatedIdentifier.valid_url?(fixed_id)
              related_id.update_columns(relation_type: relation_type(cols[4]),
                                        work_type: fixed_work_type(cols[4]),
                                        verified: validated,
                                        related_identifier: fixed_id,
                                        related_identifier_type: id_type,
                                        hidden: false)
            else
              @logger.error("idx: #{idx}, Couldn't find record with resource #{cols[1]} and ID #{cols[5]}")
            end
          end
        else
          @logger.error("idx: #{idx}, Couldn't find record with resource #{cols[1]} and ID #{cols[5]}")
        end
        puts "Finished #{idx} records" if (idx % 100) == 0 && idx != 0
      end
      puts "Updated #{count} related"
      puts 'Done'
    end


    private

    def fixed_work_type(value)
      return 'dataset' if value&.downcase == 'data'
      return 'supplemental_information' if value&.downcase == 'protocol' || value&.downcase == 'supporting information'

      value.downcase
    end

    def valid_work_type?(value)
      @valid_types.include?(fixed_work_type(value.downcase))
    end

    def relation_type(work_type)
      StashDatacite::RelatedIdentifier::WORK_TYPES_TO_RELATION_TYPE[fixed_work_type(work_type)]
    end
  end
end
