require 'faraday'
require 'json'

require_relative 'utilities'

module AuroraBuilder
  class Fetcher
    include Utilities

    def initialize
    end

    def thread
      Thread.new do
        log 'Fetcher thread started'
        loop do
          if job = fetch_job
            log "fetched job: #{job}"
            $manager.new_job job
          end
          sleep 3
        end
      end
    end

    private

    def fetch_job
      conn = Faraday.new url: $secrets[:aurora_api_server][:url]
      response = conn.delete '/api/v1/jobs/to_build/pop'
      job = JSON.parse response.body, symbolize_names: true
      job == {} ? nil : job
    rescue
      AuroraBuilder::Utilities.log 'Fetching failed.'
      return nil
    end
  end
end
