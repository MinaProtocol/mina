open Core_kernel
open Async_kernel

module type Proof_intf = sig
  type input
  type t
  [@@deriving eq, bin_io]

  include Constraint_count.Cost_s with type t := t
  val verify : t -> input -> bool Deferred.t
end

module type S = sig
  type t
  type work
  type work_unit
  type proof
  module With_path : sig
    type 'a t
    val data : 'a t -> 'a
  end

  module Evidence : sig
    type t
    val create : work With_path.t -> proof -> t
  end

  val create : unit -> t

  include Constraint_count.Free_s with type t := t

  (* Applies as many work_units as possible that are paid for by
   * proofs and returns any work_units for which we didn't have
   * enough budget *)
  val submit : t -> units:work_unit list -> proofs:Evidence.t list -> work_unit list
  val work : t -> geq:Constraint_count.t -> work With_path.t list Or_error.t
end

module Make
 (Work_unit : sig
   type t [@@deriving eq, bin_io]
   include Constraint_count.Cost_s with type t := t
 end)
 (Proof : Proof_intf with type input := Work_unit.t)
 (Work : Work_intf.S with type proof := Proof.t and type input := Work_unit.t) : S with type work := Work.t
               and type work_unit := Work_unit.t
               and type proof := Proof.t

module Constraint_count : sig
  type t = private int
end

