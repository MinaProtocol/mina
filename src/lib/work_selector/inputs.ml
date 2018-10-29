open Core_kernel

module type Inputs_intf = sig
  module Ledger_hash : sig
    type t
  end

  module Ledger_proof_statement : sig
    type t [@@deriving compare, sexp]
  end

  module Sparse_ledger : sig
    type t
  end

  module Super_transaction : sig
    type t
  end

  module Ledger_proof : sig
    type t
  end

  module Ledger_builder : sig
    type t

    val all_work_pairs :
         t
      -> ( ( Ledger_proof_statement.t
           , Super_transaction.t
           , Sparse_ledger.t
           , Ledger_proof.t )
           Snark_work_lib.Work.Single.Spec.t
         * ( Ledger_proof_statement.t
           , Super_transaction.t
           , Sparse_ledger.t
           , Ledger_proof.t )
           Snark_work_lib.Work.Single.Spec.t
           option )
         list
  end
end

module Test_input = struct
  module Ledger_hash = Int
  module Ledger_proof_statement = Int
  module Sparse_ledger = Int
  module Super_transaction = Int
  module Ledger_proof = Int

  module Ledger_builder = struct
    type t = int List.t

    let work i = Snark_work_lib.Work.Single.Spec.Transition (i, i, i)

    let chunks_of xs ~n = List.groupi xs ~break:(fun i _ _ -> i mod n = 0)

    let paired ls =
      let pairs = chunks_of ls ~n:2 in
      List.map pairs ~f:(fun js ->
          match js with
          | [j] -> (work j, None)
          | [j1; j2] -> (work j1, Some (work j2))
          | _ -> failwith "error pairing jobs" )

    let all_work_pairs (t : t) = paired t
  end
end
