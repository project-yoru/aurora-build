# TODO notification truncate max length limit

require 'faraday'

require_relative 'utilities'

module AuroraBuilder
  class Notifier
    include Utilities

    NOTIFIERS_LIMIT = 3

    def initialize
      @notifications = Queue.new
      start_notifiers
    end

    def notify notification
      # notification: { job: hash, event_name: string, message: hash }
      @notifications.push notification
    end

    private

    def start_notifiers
      @notifiers = (NOTIFIERS_LIMIT).times.map do
        Thread.new do
          begin
            log 'Notifier thread started'
            loop do
              unless notification = @notifications.pop
                sleep 1
                next
              end

              log "sending notification: #{notification}"

              conn = Faraday.new url: $secrets[:aurora_api_server][:url]
              response = conn.patch do |req|
                req.url "/api/v1/jobs/#{notification[:job][:id]}/progress"
                req.headers['Content-Type'] = 'application/json'
                # TODO optimize body size
                req.body = notification.to_json
              end

              # TODO handle errors
            end
          end
        end
      end
    end
  end
end
