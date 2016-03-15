require 'logger'
logger = Logger.new STDOUT

# 
logger.info 'Configuring redis...'
Sidekiq.configure_server{ |config| config.redis = { namespace: 'aurora-core-build-server', url: $secrets[:redis][:url] } }
Sidekiq.configure_client{ |config| config.redis = { namespace: 'aurora-core-build-server', url: $secrets[:redis][:url] } }
