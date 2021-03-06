require 'aws-sdk-s3'

# use example
# require 'stash/aws/s3'
#
# Stash::Aws::S3.put(s3_key: 'test01/color.txt', contents: 'Dryad Green is #40841c')
# Stash::Aws::S3.exists?(s3_key: 'test01/color.txt')
# Stash::Aws::S3.delete_file(s3_key: 'test01/color.txt')

module Stash
  module Aws
    class S3

      def self.put(s3_key:, contents:)
        return unless s3_key && contents

        object = s3_bucket.object(s3_key)
        object.put(body: contents)
      end

      def self.put_stream(s3_key:, stream:)
        return unless s3_key && stream

        object = s3_bucket.object(s3_key)
        object.upload_stream do |write_stream|
          IO.copy_stream(stream, write_stream)
        end
      end

      def self.put_file(s3_key:, filename:)
        return unless s3_key && filename

        object = s3_bucket.object(s3_key)
        object.upload_file(filename)
      end

      def self.exists?(s3_key:)
        obj = s3_bucket.object(s3_key)
        obj.exists?
      end

      def self.size(s3_key:)
        obj = s3_bucket.object(s3_key)
        obj.size
      end

      def self.presigned_download_url(s3_key:)
        return unless s3_key

        object = s3_bucket.object(s3_key)
        object.presigned_url(:get, expires_in: 1.day.to_i)
      end

      def self.delete_file(s3_key:)
        return unless s3_key

        object = s3_bucket.object(s3_key)
        object.delete
      end

      def self.delete_dir(s3_key:)
        return unless s3_key

        s3_key = s3_key.chop if s3_key.ends_with?('/')
        s3_bucket.objects(prefix: "#{s3_key}/").batch_delete!
      end

      def self.objects(starts_with:)
        return unless starts_with

        s3_bucket.objects(prefix: starts_with)
      end

      class << self
        private

        def s3_credentials
          @s3_credentials ||= ::Aws::Credentials.new(APP_CONFIG[:s3][:key], APP_CONFIG[:s3][:secret])
        end

        def s3_client
          @s3_client ||= ::Aws::S3::Client.new(region: APP_CONFIG[:s3][:region], credentials: s3_credentials)
        end

        def s3_resource
          @s3_resource ||= ::Aws::S3::Resource.new(client: s3_client)
        end

        def s3_bucket
          @s3_bucket ||= s3_resource.bucket(APP_CONFIG[:s3][:bucket])
        end

      end
    end
  end
end
