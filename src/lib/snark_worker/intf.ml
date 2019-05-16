open Core
open Coda_base
open Async
open Signature_lib

let command_name = "snark-worker"

module type Inputs_intf = sig
  open Snark_work_lib

  module Ledger_proof : sig
    type t [@@deriving bin_io, sexp, version]
  end

  module Worker_state : sig
    type t

    val create : unit -> t Deferred.t

    val worker_wait_time : float
  end

  val perform_single :
       Worker_state.t
    -> message:Coda_base.Sok_message.t
    -> ( Transaction_snark.Statement.t
       , Transaction.t
       , Transaction_witness.t
       , Ledger_proof.t )
       Work.Single.Spec.t
    -> (Ledger_proof.t * Time.Span.t) Or_error.t
end

module type S = sig
  module Ledger_proof : sig
    type t [@@deriving bin_io, sexp, version]
  end

  module Work : sig
    open Snark_work_lib

    module Single : sig
      module Spec : sig
        type t =
          ( Transaction_snark.Statement.t
          , Transaction.t
          , Transaction_witness.t
          , Ledger_proof.t )
          Work.Single.Spec.t
        [@@deriving sexp]
      end
    end

    module Spec : sig
      type t = Single.Spec.t Work.Spec.t [@@deriving sexp]
    end

    module Result : sig
      type t = (Spec.t, Ledger_proof.t) Work.Result.t
    end
  end

  module Rpcs : sig
    module Get_work : sig
      module V1 : sig
        type query = unit

        type response = Work.Spec.t option

        val rpc : (query, response) Rpc.Rpc.t
      end

      module Latest = V1
    end

    module Submit_work : sig
      module V1 : sig
        type query = Work.Result.t

        type response = unit

        val rpc : (query, response) Rpc.Rpc.t
      end

      module Latest = V1
    end
  end

  val command : Command.t

  val arguments :
       public_key:Public_key.Compressed.t
    -> daemon_address:Host_and_port.t
    -> shutdown_on_disconnect:bool
    -> string list
end
