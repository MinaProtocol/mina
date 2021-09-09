[%%import
"/src/config.mlh"]

module Failure = Verification_failure
module Prod = Prod
module Dummy = Dummy

[%%if
proof_level = "full"]

include Prod

[%%else]

include Dummy

[%%endif]
