module type Base_intf = sig
  type t

  type create_args

  type input

  type output

  val create : create_args -> t

  val close : t -> unit Async_kernel.Deferred.t
end

module type Worker_intf = sig
  type t

  type create_args

  type input

  type output

  val create : create_args -> t

  val close : t -> unit Async_kernel.Deferred.t

  val perform : t -> input -> output Async_kernel.Deferred.t
end

module type S = sig
  type t

  type create_args

  type input

  type output

  val create : create_args -> t

  val close : t -> unit Async_kernel.Deferred.t

  val is_working : t -> bool

  val dispatch : t -> input -> output Async_kernel.Deferred.t
end

module Make : functor (Worker : Worker_intf) -> sig
  type t

  val create : Worker.create_args -> t

  val close : t -> unit Async_kernel.Deferred.t

  val is_working : t -> bool

  val dispatch : t -> Worker.input -> Worker.output Async_kernel.Deferred.t
end
