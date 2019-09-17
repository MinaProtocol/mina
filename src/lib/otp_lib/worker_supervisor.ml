open Async_kernel
open Core_kernel

module type Base_intf = sig
  type t

  type create_args

  type input

  type output

  val create : create_args -> t

  val close : t -> unit Deferred.t
end

module type Worker_intf = sig
  include Base_intf

  val perform : t -> input -> output Deferred.t
end

module type S = sig
  include Base_intf

  val is_working : t -> bool

  val dispatch : t -> input -> output Deferred.t
end

module Make (Worker : Worker_intf) :
  S
  with type create_args := Worker.create_args
   and type input := Worker.input
   and type output := Worker.output = struct
  type t = {mutable thread: Worker.output Deferred.t option; worker: Worker.t}

  let create args = {thread= None; worker= Worker.create args}

  let is_working t =
    Option.value_map t.thread ~default:false ~f:Deferred.is_determined

  let assert_not_working t =
    if is_working t then failwith "cannot dispatch to busy worker"

  let dispatch t work =
    assert_not_working t ;
    let thread = Worker.perform t.worker work in
    t.thread <- Some thread ;
    thread

  let close t = assert_not_working t ; Worker.close t.worker
end
