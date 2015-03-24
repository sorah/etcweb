require 'etcweb'
require 'omniauth'

use Rack::Session::Cookie, :key => 'etcweb_sess',
                           :secret => 'configuration'

use OmniAuth::Builder do
  provider :developer
end

run Etcweb::App.rack(
  etcd: {
    host: '127.0.0.1', port: 4001,
  },
  etcvault: true,
  auth: {
    omniauth: 'developer',
  },
)
