# frozen_string_literal: true

require 'httparty'

module StashEngine
  module StatusDashboard

    class OaiService < DependencyCheckerService

      def ping_dependency
        super
        env = Rails.env.production? ? 'mrtoai.cdlib.org' : 'mrtoai-stg.cdlib.org'
        target = "http://#{env}:37001/mrtoai/state"
        resp = HTTParty.get(target)
        online = resp.code == 200
        msg = resp.body unless online
        record_status(online: online, message: msg)
        online
      rescue StandardError => e
        record_status(online: false, message: e.to_s)
        false
      end

    end

  end
end
