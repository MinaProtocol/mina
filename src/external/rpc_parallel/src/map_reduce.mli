(** A parallel map/reduce library. See examples/add_numbers.ml and
    examples/number_stats.ml for examples. *)

open! Core
open! Async

module Config : sig
  type t

  (** Default is to create the same number of local workers as the cores in local
      machine. All spawned workers will their redirect stdout and stderr to the same
      file. *)
  val create
    :  ?local : int
    -> ?remote : (_ Remote_executable.t * int) list
    -> ?cd : string  (** default / *)
    -> redirect_stderr : [ `Dev_null | `File_append of string ]
    -> redirect_stdout : [ `Dev_null | `File_append of string ]
    -> unit
    -> t
end

module type Worker = sig
  type t
  type param_type
  type run_input_type
  type run_output_type

  val spawn_config_exn : Config.t -> param_type -> t list Deferred.t
  val run_exn : t -> run_input_type -> run_output_type Deferred.t
  val shutdown_exn : t -> unit Deferred.t
end

(** {4 Map functions} *)

(** [Map_function] modules must be created using the [Make_map_function] or
    [Make_map_function_with_init] functors. The init variety allows you to specify an
    [init] function that takes a "param" argument. The non-init variety is equivalent to
    the init variety with [init] equal to [return] and a [unit] "param"
    argument. Similarly, [Map_reduce_function] modules must be created using the
    [Make_map_combine_function] or [Make_map_combine_function_with_init] functors. *)

module type Map_function = sig
  module Param : Binable
  module Input : Binable
  module Output : Binable

  module Worker : Worker
    with type param_type = Param.t
     and type run_input_type = Input.t
     and type run_output_type = Output.t
end

module type Map_function_with_init_spec = sig
  type state_type
  module Param : Binable
  module Input : Binable
  module Output : Binable

  val init : Param.t -> state_type Deferred.t
  val map : state_type -> Input.t -> Output.t Deferred.t
end

module Make_map_function_with_init(S : Map_function_with_init_spec) : Map_function
  with type Param.t = S.Param.t
   and type Input.t = S.Input.t
   and type Output.t = S.Output.t

module type Map_function_spec = sig
  module Input : Binable
  module Output : Binable

  val map : Input.t -> Output.t Deferred.t
end

module Make_map_function(S : Map_function_spec) : Map_function
  with type Param.t = unit
   and type Input.t = S.Input.t
   and type Output.t = S.Output.t

(** The [map_unordered] operation takes ['a Pipe.Reader.t] along with a [Map_function] and
    sends the ['a] values to workers for mapping. Each pair in the resulting [('b * int)
    Pipe.Reader.t] contains the mapped value and the index of the value in the input
    pipe. *)
val map_unordered
  :  Config.t
  -> 'a Pipe.Reader.t
  -> m : (module Map_function
           with type Param.t = 'param
            and type Input.t = 'a
            and type Output.t = 'b)
  -> param : 'param
  -> ('b * int) Pipe.Reader.t Deferred.t

(** The [map] operation is similar to [map_unordered], but the result is a ['b
    Pipe.Reader.t] where the mapped values are guaranteed to be in the same order as the
    input values. *)
val map
  :  Config.t
  -> 'a Pipe.Reader.t
  -> m : (module Map_function
           with type Param.t = 'param
            and type Input.t = 'a
            and type Output.t = 'b)
  -> param : 'param
  -> 'b Pipe.Reader.t Deferred.t

(** The [find_map] operation takes ['a Pipe.Reader.t] along with a [Map_function] that
    returns ['b option] values. As soon as [map] returns [Some value], all workers are
    stopped and [Some value] is returned. If [map] never returns [Some value] then [None]
    is returned. If more than one worker returns [Some value], one value is chosen
    arbitrarily and returned. *)
val find_map
  :  Config.t
  -> 'a Pipe.Reader.t
  -> m : (module Map_function
           with type Param.t = 'param
            and type Input.t = 'a
            and type Output.t = 'b option)
  -> param : 'param
  -> 'b option Deferred.t


(** {4 Map-reduce} functions *)

module type Map_reduce_function = sig
  module Param : Binable
  module Accum : Binable
  module Input : Binable

  module Worker : Worker
    with type param_type = Param.t
     and type run_input_type =
           [ `Map of Input.t
           | `Combine of Accum.t * Accum.t
           | `Map_right_combine of Accum.t * Input.t (* combine accum (map input) *)
           ]
     and type run_output_type = Accum.t
end

module type Map_reduce_function_with_init_spec = sig
  type state_type
  module Param : Binable
  module Accum : Binable
  module Input : Binable

  val init : Param.t -> state_type Deferred.t
  val map : state_type -> Input.t -> Accum.t Deferred.t
  val combine : state_type -> Accum.t -> Accum.t -> Accum.t Deferred.t
end

module Make_map_reduce_function_with_init(S : Map_reduce_function_with_init_spec)
  : Map_reduce_function
    with type Param.t = S.Param.t
     and type Accum.t = S.Accum.t
     and type Input.t = S.Input.t

module type Map_reduce_function_spec = sig
  module Accum : Binable
  module Input : Binable

  val map : Input.t -> Accum.t Deferred.t
  val combine : Accum.t -> Accum.t -> Accum.t Deferred.t
end

module Make_map_reduce_function(S : Map_reduce_function_spec) : Map_reduce_function
  with type Param.t = unit
   and type Accum.t = S.Accum.t
   and type Input.t = S.Input.t

(** The [map_reduce_commutative] operation takes ['a Pipe.Reader.t] along with a
    [Map_reduce_function] and applies the [map] function to ['a] values (in an unspecified
    order), resulting in ['accum] values. The [combine] function is then called to combine
    the ['accum] values (in an unspecified order) into a single ['accum]
    value. Commutative map-reduce assumes that [combine] is associative and
    commutative. *)
val map_reduce_commutative
  :  Config.t
  -> 'a Pipe.Reader.t
  -> m : (module Map_reduce_function
           with type Param.t = 'param
            and type Accum.t = 'accum
            and type Input.t = 'a)
  -> param : 'param
  -> 'accum option Deferred.t

(** The [map_reduce] operation makes strong guarantees about the order in which the values
    are processed by [combine]. For a list a_0, a_1, a_2, ..., a_n of ['a] values, the
    noncommutative map-reduce operation applies the [map] function to produce
    [acc_{i,i+1}] from each [a_i]. The [combine] function is used to compute [combine
    acc_{i,j} acc_{j,k}] for i<j<k, producing [acc_{i,k}]. The [map] and [combine]
    functions are called repeatedly until the entire list is reduced to a single
    [acc_{0,n+1}] value. Noncommutative map-reduce assumes that [combine] is
    associative. *)
val map_reduce
  :  Config.t
  -> 'a Pipe.Reader.t
  -> m : (module Map_reduce_function
           with type Param.t = 'param
            and type Accum.t = 'accum
            and type Input.t = 'a)
  -> param : 'param
  -> 'accum option Deferred.t
