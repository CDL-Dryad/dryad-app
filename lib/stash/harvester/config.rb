module Stash
  module Harvester
    class Config

      # The database connection info, as a hash
      # @return [Hash<String, String>] the database connection info
      attr_reader :connection_info

      # The harvest source configuration
      # @return [SourceConfig] the configuration (as an appropriate
      #   subclass of +SourceConfig+ for the specified protocol)
      attr_reader :source_config

      # The index configuration
      # @return [IndexConfig] the configuration (as an apporpriate
      #   subclass of +IndexConfig+ for the specified adapter)
      attr_reader :index_config

      def initialize(connection_info:, source_config:, index_config:)
        @connection_info = connection_info
        @source_config = source_config
        @index_config = index_config
      end

      # Reads the specified file and creates a new +Config+ from it.
      #
      # @param path [String] the path to read the YAML from
      # @raise [IOError] in the event the file does not exist, cannot be read, or is invalid
      def self.from_file(path)
        fail IOError, "Specified config file #{path} is not a file" unless File.file?(path)
        fail IOError, "Specified config file #{path} is not readable" unless File.readable?(path)
        begin
          yml = File.read(path)
          from_yaml(yml)
        rescue IOError
          raise
        rescue => e
          raise IOError, "Error parsing specified config file #{path}: #{e.message}"
        end
      end

      # Creates a new +Config+ from the specified YAML string.
      #
      # @param yml [String] the YAML string to load
      def self.from_yaml(yml)
        yaml = YAML.load(yml)
        connection_info = yaml['db']
        config = keys_to_syms(yaml)
        source_config = SourceConfig.from_hash(config[:source])
        index_config = IndexConfig.from_hash(config[:index])
        Config.new(connection_info: connection_info, source_config: source_config, index_config: index_config)
      end

      # Private methods

      def self.keys_to_syms(v)
        return v unless v.respond_to?(:to_h)
        v.to_h.map { |k2, v2| [k2.to_sym, keys_to_syms(v2)] }.to_h
      end

      private_class_method :keys_to_syms
    end
  end
end
