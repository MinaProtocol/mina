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

  type ('a, 'b, 'd) t [@@deriving sexp, bin_io]

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
    type t [@@deriving sexp_of]
  end

  val map : Data.t -> Accum.t Deferred.t

  val merge : Output.t -> Accum.t -> Output.t Deferred.t
end

val start : parallelism_log_2:int -> init:'b -> seed:'d -> ('a, 'b, 'd) State.t

val step :
     state:('a, 'b, 'd) State.t
  -> data:'d list
  -> spec:(module
           Spec_intf with type Data.t = 'd and type Accum.t = 'a and type Output.
                                                                          t = 'b)
  -> 'b option Deferred.t

val next_k_jobs :
     state:('a, 'b, 'd) State.t
  -> spec:(module
           Spec_intf with type Data.t = 'd and type Accum.t = 'a and type Output.
                                                                          t = 'b)
  -> int
  -> ('a, 'd) State.Job.t list Or_error.t
