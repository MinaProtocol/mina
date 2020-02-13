open Async_kernel
open Core_kernel
open Otp_lib
open Intf

(* TODO: tune me -- batch verification time cost = 700ms + 10ms * N *)

module Noop : Diff_intake_creator_intf =
functor
  (Pool : Applicable_pool_intf)
  ->
  struct
    type t = {pool: Pool.t; mutable last_job: unit Deferred.t}

    let create pool = {pool; last_job= Deferred.unit}

    let add_diff t diff =
      t.last_job
      <- (let%bind () = t.last_job in
          Pool.apply_diffs t.pool [diff])
  end

module Diff_accumulator (Diff : Resource_pool_diff_intf) :
  Batch_mailbox.Accumulator_intf
  with type data = Diff.t
   and type emission = Diff.t list
   and type 'a creator = unit -> 'a = struct
  (* extend a basic sequential accumulator to track the total size of diff
   * contents instead of tracking the number of diffs themselves *)
  module Base_accumulator = Batch_mailbox.Make_sequential_accumulator (Diff)

  type t = {base_accumulator: Base_accumulator.t; mutable size: int}

  type 'a creator = unit -> 'a

  type data = Diff.t

  type emission = Diff.t list

  let create_map : (t -> 'a) -> 'a creator =
   fun f ->
    Base_accumulator.create_map (fun base_accumulator ->
        f {base_accumulator; size= 0} )

  let create = create_map Fn.id

  let size {size; _} = size

  let add t diff =
    t.size <- t.size + Diff.size diff ;
    Base_accumulator.add t.base_accumulator diff

  let flush t =
    t.size <- 0 ;
    Base_accumulator.flush t.base_accumulator
end

module Batched (Rules : Batch_mailbox.Rules_intf) : Diff_intake_creator_intf =
functor
  (Pool : Applicable_pool_intf)
  ->
  struct
    include Batch_mailbox.Make
              (Rules)
              (Diff_accumulator (Pool.Resource_pool.Diff))
              (Worker)

    type t = Supervisor.t

    let create_map f pool = f (Buffer.create (Pool.apply_diffs pool))

    let create pool = Buffer.create (Pool.apply_diffs pool)

    let add_diff = Buffer.add
  end
