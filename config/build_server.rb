logger.info 'Loading config..'

environment :production do
end

environment :development do
  require 'byebug'
  require 'awesome_print'
end

# hostname = nil

# environment :production do
#     hostname = 'production.example.org'
# end

# environment :development do
#     hostname = 'dev.example.org'
# end
