[%%import
"/src/config.mlh"]

module Prod = Prod
module Dummy = Dummy

[%%if
proof_level = "full"]

include Prod

[%%else]

include Dummy

[%%endif]
