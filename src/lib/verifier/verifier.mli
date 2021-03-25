module Failure = Verification_failure

module Dummy : module type of Dummy

module Prod : module type of Prod

include module type of Prod
