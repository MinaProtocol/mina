open Core_kernel
open Async_kernel

module Ring_buffer : sig
  type 'a t [@@deriving sexp, bin_io]
  val read_all : 'a t -> 'a list
end

module State : sig
  module Job : sig
    type ('a, 'd) t =
      | Merge_up of 'a option
      | Merge of 'a option * 'a option
      | Base of 'd option
    [@@deriving bin_io, sexp]
  end

  type ('a, 'b, 'd) t [@@deriving bin_io]
  val jobs : ('a, 'b, 'd) t -> ('a, 'd) Job.t Ring_buffer.t
end

module type Spec_intf = sig
  module Data : sig
    type t [@@deriving sexp_of]
  end

  module Accum : sig
    type t [@@deriving sexp_of]
    (* Semigroup+deferred *)
    val ( + ) : t -> t -> t Deferred.t
  end

  module Output : sig
    type t [@@deriving sexp_of, eq]
  end

  val map : Data.t -> Accum.t Deferred.t
  val merge : Output.t -> Accum.t -> Output.t Deferred.t
end

val scan :
  init:'b ->
  data:'d Linear_pipe.Reader.t ->
  parallelism_log_2:int ->
  spec:(module Spec_intf with type Data.t = 'd and type Accum.t = 'a and type Output.t = 'b) ->
  ('b option * ('a, 'b, 'd) State.t) Linear_pipe.Reader.t

val scan_from :
  state:('a, 'b, 'd) State.t ->
  data:'d Linear_pipe.Reader.t ->
  spec:(module Spec_intf with type Data.t = 'd and type Accum.t = 'a and type Output.t = 'b) ->
  ('b option * ('a, 'b, 'd) State.t) Linear_pipe.Reader.t

