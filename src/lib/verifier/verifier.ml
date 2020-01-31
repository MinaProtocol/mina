[%%import
"/src/config.mlh"]

module Prod = Prod
module Dummy = Dummy
module Any = Any

[%%if
proof_level = "full"]

include Prod

[%%else]

include Dummy

[%%endif]
