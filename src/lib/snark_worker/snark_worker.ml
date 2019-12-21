[%%import
"/src/config.mlh"]

module Intf = Intf

[%%if
proof_level = "full"]

include Prod.Worker

[%%else]

include Debug.Worker

[%%endif]
