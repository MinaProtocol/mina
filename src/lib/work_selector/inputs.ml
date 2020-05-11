open Core_kernel
open Currency

module Test_inputs = struct
  module Transaction_witness = Int
  module Ledger_hash = Int
  module Sparse_ledger = Int
  module Transaction = Int
  module Ledger_proof_statement = Fee

  module Transaction_protocol_state = struct
    type 'a t = 'a
  end

  module Ledger_proof = struct
    type t = Fee.t [@@deriving hash, compare, sexp]
  end

  module Transaction_snark_work = struct
    type t = Fee.t

    let fee = Fn.id

    module Statement = struct
      type t = Transaction_snark.Statement.t One_or_two.t
    end
  end

  module Snark_pool = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Transaction_snark.Statement.Stable.V1.t One_or_two.Stable.V1.t
        [@@deriving hash, compare, sexp]

        let to_latest = Fn.id
      end
    end]

    module Work = Hashable.Make_binable (Stable.Latest)

    type t = Currency.Fee.t Work.Table.t

    let get_completed_work (t : t) = Work.Table.find t

    let create () = Work.Table.create ()

    let add_snark t ~work ~fee =
      Work.Table.update t work ~f:(function
        | None ->
            fee
        | Some fee' ->
            Currency.Fee.min fee fee' )
  end

  module Staged_ledger = struct
    type t =
      (int, int, Transaction_snark_work.t) Snark_work_lib.Work.Single.Spec.t
      List.t

    let work = Fn.id

    let all_work_pairs t ~get_state:_ = Ok (One_or_two.group_list t)

    let all_work_statements_exn t =
      List.map (One_or_two.group_list t)
        ~f:(One_or_two.map ~f:Snark_work_lib.Work.Single.Spec.statement)
  end
end

module Implementation_inputs = struct
  open Coda_base
  module Ledger_hash = Ledger_hash
  module Sparse_ledger = Sparse_ledger
  module Transaction = Transaction
  module Transaction_witness = Transaction_witness
  module Ledger_proof = Ledger_proof
  module Transaction_snark_work = Transaction_snark_work
  module Snark_pool = Network_pool.Snark_pool
  module Staged_ledger = Staged_ledger
  module Transaction_protocol_state = Transaction_protocol_state
end
