module Failure = Verification_failure
module For_test = For_test

module Dummy : module type of Dummy

module Prod : module type of Prod

include Verifier_intf.S with type ledger_proof = Ledger_proof.t
