open Core_kernel
open Async_kernel
open Pipe_lib

module Priced_proof : sig
  type ('proof, 'fee) t = {proof: 'proof; fee: 'fee}
  [@@deriving bin_io, sexp, fields]
end

module type Inputs_intf = sig
  module Proof : Binable.S

  module Fee : sig
    type t
    include Binable.S with type t := t
    include Comparable.S with type t := t
    include Sexpable.S with type t := t
    val gen : t Quickcheck.Generator.t
  end

  module Statement : sig
    type t
    include Binable.S with type t := t
    include Hashable.S_binable with type t := t
    include Sexpable.S with type t := t
  end

  module Work : sig
    type t
    include Binable.S with type t := t
    include Hashable.S_binable with type t := t
    include Sexpable.S with type t := t
    val gen : t Quickcheck.Generator.t
    val statements : t -> Statement.t list
  end
end

module type S = sig
  type statement

  type work

  type proof

  type fee

  type t [@@deriving bin_io]

  val create :
       parent_log:Logger.t
    -> relevant_statement_changes_reader:(statement, int) List.Assoc.t Linear_pipe.Reader.t
    -> t

  val add_snark :
       t
    -> work:work
    -> proof:proof
    -> fee:fee
    -> [`Rebroadcast | `Don't_rebroadcast]

  val request_proof : t -> work -> (proof, fee) Priced_proof.t option
end

module Make (Inputs : Inputs_intf) :
  S with type work := Inputs.Work.t
     and type statement := Inputs.Statement.t
     and type proof := Inputs.Proof.t
     and type fee := Inputs.Fee.t
