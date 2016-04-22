require 'qiniu'

access_key = $secrets[:cdn][:qiniu][:access_key]
secret_key = $secrets[:cdn][:qiniu][:secret_key]
up_host = case $env
          when :development
            'http://up.qiniu.com'
          when :production
            'http://up.qiniug.com'
          end

Qiniu.establish_connection! access_key: access_key, secret_key: secret_key, up_host: up_host
