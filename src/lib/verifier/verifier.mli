[%%import "../../config.mlh"]

module Dummy : module type of Dummy

module Prod : module type of Prod

[%%if proof_level = "full"]

include module type of Prod

[%%else]

include module type of Dummy

[%%endif]
