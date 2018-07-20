open Core
open Async

module type Inputs_intf = sig
  module Public_key : sig
    type t [@@deriving bin_io]

    val arg_type : t Command.Arg_type.t
  end

  module Sparse_ledger : sig
    type t [@@deriving bin_io]
  end

  module Super_transaction : sig
    type t [@@deriving bin_io]
  end

  module Proof : sig
    type t [@@deriving bin_io]
  end

  module Statement : sig
    type t [@@deriving bin_io]
  end

  open Snark_work_lib

  module Worker_state : sig
    type t

    val create : unit -> t Deferred.t
  end

  val perform_single :
       Worker_state.t
    -> message:Currency.Fee.t * Public_key.t
    -> ( Statement.t
       , Super_transaction.t
       , Sparse_ledger.t
       , Proof.t )
       Work.Single.Spec.t
    -> Proof.t Or_error.t
end

module type S = sig
  type proof

  type statement

  type transition

  type sparse_ledger

  type public_key

  module Work : sig
    open Snark_work_lib

    module Single : sig
      module Spec : sig
        type t =
          (statement, transition, sparse_ledger, proof) Work.Single.Spec.t
      end
    end

    module Spec : sig
      type t = Single.Spec.t Work.Spec.t
    end

    module Result : sig
      type t = (Spec.t, proof) Work.Result.t
    end
  end

  module Rpcs : sig
    module Get_work : sig
      type query = unit

      type response = Work.Spec.t

      val rpc : (query, response) Rpc.Rpc.t
    end

    module Submit_work : sig
      type msg = Work.Result.t

      val rpc : msg Rpc.One_way.t
    end
  end

  val command : Command.t

  val arguments : public_key:public_key -> daemon_port:int -> string list
end
