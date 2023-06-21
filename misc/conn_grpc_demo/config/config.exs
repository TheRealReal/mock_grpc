import Config

Application.put_env(:demo, :grpc_address, "localhost:50020")

import_config "#{config_env()}.exs"
