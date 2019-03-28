open Core
open Async
open Signature_lib

let command_name = "snark-worker"

module type Inputs_intf = sig
  module Sparse_ledger : sig
    type t [@@deriving bin_io, sexp]
  end

  module Transaction_witness : sig
    type t [@@deriving bin_io, sexp]
  end

  module Transaction : sig
    type t [@@deriving bin_io, sexp]
  end

  module Proof : sig
    type t [@@deriving bin_io, sexp]
  end

  module Statement : sig
    type t [@@deriving sexp]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving bin_io, sexp]
        end
      end
      with type V1.t = t
  end

  module Pending_coinbase : sig
    type t [@@deriving bin_io, sexp]
  end

  open Snark_work_lib

  module Worker_state : sig
    type t

    val create : unit -> t Deferred.t

    val worker_wait_time : float
  end

  val perform_single :
       Worker_state.t
    -> message:Coda_base.Sok_message.t
    -> ( Statement.t
       , Transaction.t
       , Transaction_witness.t
       , Proof.t )
       Work.Single.Spec.t
    -> (Proof.t * Time.Span.t) Or_error.t
end

module type S = sig
  type proof

  type statement

  type transition

  type transaction_witness

  module Work : sig
    open Snark_work_lib

    module Single : sig
      module Spec : sig
        type t =
          ( statement
          , transition
          , transaction_witness
          , proof )
          Work.Single.Spec.t
        [@@deriving sexp]
      end
    end

    module Spec : sig
      type t = Single.Spec.t Work.Spec.t [@@deriving sexp]
    end

    module Result : sig
      type t = (Spec.t, proof) Work.Result.t
    end
  end

  module Rpcs : sig
    module Get_work : sig
      type query = unit

      type response = Work.Spec.t option

      val rpc : (query, response) Rpc.Rpc.t
    end

    module Submit_work : sig
      type query = Work.Result.t

      type response = unit

      val rpc : (query, response) Rpc.Rpc.t
    end
  end

  val command : Command.t

  val arguments :
       public_key:Public_key.Compressed.t
    -> daemon_address:Host_and_port.t
    -> shutdown_on_disconnect:bool
    -> string list
end
