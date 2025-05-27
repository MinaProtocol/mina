open Core
open Async
open Snark_work_lib

let command_name = "snark-worker"

module type Rpc_master = sig
  module Master : sig
    module T : sig
      type query

      type response
    end

    module Caller = T
    module Callee = T
  end

  module Register (Version : sig
    val version : int

    type query [@@deriving bin_io]

    type response [@@deriving bin_io]

    val query_of_caller_model : Master.Caller.query -> query

    val callee_model_of_query : query -> Master.Callee.query

    val response_of_callee_model : Master.Callee.response -> response

    val caller_model_of_response : response -> Master.Caller.response
  end) : sig
    val rpc : (Version.query, Version.response) Rpc.Rpc.t
  end
end

module type Work_S = sig
  type ledger_proof

  module Single : sig
    module Spec : sig
      type t =
        (Transaction_witness.Stable.Latest.t, ledger_proof) Work.Single.Spec.t
      [@@deriving sexp, yojson]
    end
  end

  module Spec : sig
    type t = Single.Spec.t Work.Spec.t [@@deriving sexp, yojson]
  end

  module Result : sig
    type t = (Spec.t, ledger_proof) Work.Result.t

    val transactions :
         t
      -> Mina_transaction.Transaction.Stable.Latest.t option
         One_or_two.Stable.Latest.t
  end
end

module type Rpcs_versioned_S = sig
  module Get_work : sig
    module V2 : sig
      type query = unit [@@deriving bin_io]

      type response =
        (Selector.Spec.Stable.Latest.t * Signature_lib.Public_key.Compressed.t)
        option
      [@@deriving bin_io]

      val rpc : (query, response) Rpc.Rpc.t
    end

    module Latest = V2
  end

  module Submit_work : sig
    module V2 : sig
      type query = Selector.Result.Stable.Latest.t [@@deriving bin_io]

      type response = unit [@@deriving bin_io]

      val rpc : (query, response) Rpc.Rpc.t
    end

    module Latest = V2
  end

  module Failed_to_generate_snark : sig
    module V2 : sig
      type query =
        Error.t
        * Selector.Spec.Stable.Latest.t
        * Signature_lib.Public_key.Compressed.t
      [@@deriving bin_io]

      type response = unit [@@deriving bin_io]

      val rpc : (query, response) Rpc.Rpc.t
    end

    module Latest = V2
  end
end
