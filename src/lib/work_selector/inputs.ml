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

    module With_hash = struct
      type 'a t = { hash : int; data : 'a }

      let create ~f data =
        { hash =
            Ppx_hash_lib.Std.Hash.of_fold
              (One_or_two.hash_fold_t Transaction_snark.Statement.hash_fold_t)
              (f data)
        ; data
        }

      let hash { hash; _ } = hash

      let map ~f { hash; data } = { hash; data = f data }

      let data { data; _ } = data
    end

    module Statement = struct
      type t = Transaction_snark.Statement.t One_or_two.t
      [@@deriving equal, compare, hash, sexp, yojson]
    end

    module Statement_with_hash = struct
      type t = Transaction_snark.Statement.t One_or_two.t With_hash.t

      let hash = With_hash.hash

      let hash_fold_t st With_hash.{ hash; _ } = Int.hash_fold_t st hash

      let equal With_hash.{ data = d1; _ } With_hash.{ data = d2; _ } =
        Statement.equal d1 d2

      let compare With_hash.{ data = d1; _ } With_hash.{ data = d2; _ } =
        Statement.compare d1 d2

      let create = With_hash.create ~f:Fn.id

      let t_of_sexp =
        Fn.compose create
          (One_or_two.t_of_sexp Transaction_snark.Statement.t_of_sexp)

      let sexp_of_t With_hash.{ data; _ } =
        One_or_two.sexp_of_t Transaction_snark.Statement.sexp_of_t data

      let to_yojson With_hash.{ data; _ } =
        One_or_two.to_yojson Transaction_snark.Statement.to_yojson data
    end
  end

  module Snark_pool = struct
    type t =
      (Transaction_snark_work.Statement_with_hash.t, Currency.Fee.t) Hashtbl.t

    let get_completed_work = Hashtbl.find

    let create () =
      Hashtbl.create (module Transaction_snark_work.Statement_with_hash)

    let add_snark t ~work ~fee =
      Hashtbl.update t work ~f:(function
        | None ->
            fee
        | Some fee' ->
            Currency.Fee.min fee fee' )
  end

  module Staged_ledger = struct
    type t =
      (int, Transaction_snark_work.t) Snark_work_lib.Work.Single.Spec.t List.t

    let work = Fn.id

    let all_work_pairs t ~get_state:_ = Ok (One_or_two.group_list t)
  end

  module Transition_frontier = struct
    type t = Staged_ledger.t

    type best_tip_view = unit

    let best_tip_pipe : t -> best_tip_view Pipe_lib.Broadcast_pipe.Reader.t =
     fun _t ->
      let reader, _writer = Pipe_lib.Broadcast_pipe.create () in
      reader

    let best_tip_staged_ledger = Fn.id

    let get_protocol_state _t _hash =
      Ok
        (Lazy.force Precomputed_values.for_unit_tests)
          .protocol_state_with_hashes
          .data
  end
end

module Implementation_inputs = struct
  open Mina_base
  open Mina_transaction
  module Ledger_hash = Ledger_hash
  module Sparse_ledger = Mina_ledger.Sparse_ledger
  module Transaction = Transaction
  module Transaction_witness = Transaction_witness
  module Ledger_proof = Ledger_proof
  module Transaction_snark_work = Transaction_snark_work
  module Snark_pool = Network_pool.Snark_pool
  module Staged_ledger = Staged_ledger
  module Transaction_protocol_state = Transaction_protocol_state

  module Transition_frontier = struct
    type t = Transition_frontier.t

    type best_tip_view = Extensions.Best_tip_diff.view

    let best_tip_pipe : t -> best_tip_view Pipe_lib.Broadcast_pipe.Reader.t =
     fun t ->
      let open Transition_frontier.Extensions in
      let extensions = Transition_frontier.extensions t in
      get_view_pipe extensions Best_tip_diff

    let best_tip_staged_ledger t =
      Transition_frontier.(best_tip t |> Breadcrumb.staged_ledger)

    let get_protocol_state t state_hash =
      match Transition_frontier.find_protocol_state t state_hash with
      | Some p ->
          Ok p
      | None ->
          Or_error.errorf
            !"Protocol state with hash %{sexp: State_hash.t} not found"
            state_hash
  end
end
