require 'qiniu'

Qiniu.establish_connection! access_key: $secrets[:cdn][:qiniu][:access_key], secret_key: $secrets[:cdn][:qiniu][:secret_key]
