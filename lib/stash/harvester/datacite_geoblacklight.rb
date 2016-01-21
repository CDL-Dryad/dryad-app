module Stash
  module Harvester
    # Indexing support for [Apache Solr](http://lucene.apache.org/solr/)
    module Solr
      Dir.glob(File.expand_path('../datacite_geoblacklight/*.rb', __FILE__), &method(:require))
    end
  end
end
