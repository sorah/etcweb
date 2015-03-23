require 'etcweb'

run Etcweb::App.rack(
  etcd: {
    host: '127.0.0.1', port: 2379,
  }
)
