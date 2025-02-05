open Core_kernel

type t = Pickles.Proof.Proofs_verified_2.t

type cache_db = unit

let unwrap = Fn.id

let generate () = Fn.id

let create_db path ~logger =
  [%log trace] "mocking path %s" path ;
  Async.Deferred.Result.return ()

module For_tests = struct
  let blockchain_dummy = Mina_base.Proof.blockchain_dummy

  let transaction_dummy = Mina_base.Proof.transaction_dummy

  let create_db () = ()
end
