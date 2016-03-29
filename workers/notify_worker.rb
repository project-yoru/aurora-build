require 'faraday'

class NotifyWorker
  include Sidekiq::Worker
  include Sidekiq::Symbols

  sidekiq_options queue: :notifying

  def perform distribution, event_type, event_message
    logger.info "Performing NotifyWorker... Distribution ##{distribution[:id]}"
    logger.info "event_type #{event_type}, message: #{event_message} ..."

    conn = Faraday.new url: $secrets[:aurora_web_server][:url]
    response = conn.post do |req|
      req.url "/distributions/#{distribution[:id]}/notify"
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        event_type: event_type,
        event_message: event_message
      }.to_json
    end
  end

end
