module Failure = Verification_failure
module Prod = Prod
module Dummy = Dummy

let m =
  if Core_kernel.am_running_inline_test then
    (* Spawning a process using [Rpc_parallel] calls the current binary with a
       particular set of arguments. Unfortunately, unit tests use the inline
       test binary, which doesn't support these arguments, and so we're not
       able to use these [Rpc_parallel] calls. Instead, we detect this and call
       out to the dummy verifier instead.
       The implementation of dummy is equivalent to the one with
       [proof_level <> Full], so this should make no difference. Inline tests
       shouldn't be run with [proof_level = Full].
    *)
    (module Dummy : Verifier_intf.S with type ledger_proof = Ledger_proof.t )
  else (module Prod)

include (val m)
