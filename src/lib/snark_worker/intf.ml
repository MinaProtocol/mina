open Core
open Async

let command_name = "snark-worker"

module type Inputs_intf = sig
  open Snark_work_lib

  module Ledger_proof : Ledger_proof.S

  module Worker_state : sig
    type t

    val create :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> proof_level:Genesis_constants.Proof_level.t
      -> unit
      -> t Deferred.t

    val worker_wait_time : float
  end

  val perform_single :
       Worker_state.t
    -> message:Mina_base.Sok_message.t
    -> (Transaction_witness.Stable.Latest.t, Ledger_proof.t) Work.Single.Spec.t
    -> (Ledger_proof.t * Time.Span.t) Deferred.Or_error.t
end

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
  open Snark_work_lib

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
  module Work : Work_S

  module Get_work : sig
    module V2 : sig
      type query = unit [@@deriving bin_io]

      type response =
        (Work.Spec.t * Signature_lib.Public_key.Compressed.t) option
      [@@deriving bin_io]

      val rpc : (query, response) Rpc.Rpc.t
    end

    module Latest = V2
  end

  module Submit_work : sig
    module V2 : sig
      type query = Work.Result.t [@@deriving bin_io]

      type response = unit [@@deriving bin_io]

      val rpc : (query, response) Rpc.Rpc.t
    end

    module Latest = V2
  end

  module Failed_to_generate_snark : sig
    module V2 : sig
      type query = Error.t * Work.Spec.t * Signature_lib.Public_key.Compressed.t
      [@@deriving bin_io]

      type response = unit [@@deriving bin_io]

      val rpc : (query, response) Rpc.Rpc.t
    end

    module Latest = V2
  end
end

(* result of Functor.Make *)
module type S0 = sig
  type ledger_proof

  module Work : Work_S with type ledger_proof := ledger_proof

  module Rpcs : sig
    module Get_work :
      Rpc_master
        with type Master.T.query = unit
         and type Master.T.response =
          (Work.Spec.t * Signature_lib.Public_key.Compressed.t) option

    module Submit_work :
      Rpc_master
        with type Master.T.query = Work.Result.t
         and type Master.T.response = unit

    module Failed_to_generate_snark :
      Rpc_master
        with type Master.T.query =
          Bounded_types.Wrapped_error.t
          * Work.Spec.t
          * Signature_lib.Public_key.Compressed.t
         and type Master.T.response = unit
  end

  val command_from_rpcs :
       commit_id:string
    -> proof_level:Genesis_constants.Proof_level.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> (module Rpcs_versioned_S with type Work.ledger_proof = ledger_proof)
    -> Command.t

  val arguments :
       proof_level:Genesis_constants.Proof_level.t
    -> daemon_address:Host_and_port.t
    -> shutdown_on_disconnect:bool
    -> string list
end

(* add in versioned Rpc modules *)
module type S = sig
  include S0

  module Rpcs_versioned :
    Rpcs_versioned_S with type Work.ledger_proof = ledger_proof

  val command :
       commit_id:string
    -> proof_level:Genesis_constants.Proof_level.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> Command.t
end
