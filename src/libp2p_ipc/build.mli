(** DSL for building capnp messages. *)
open Ipc

module type Struct_builder_intf = sig
  type struct_t

  type t = struct_t builder_t

  val init_root : ?message_size:int -> unit -> t

  val to_reader : t -> struct_t reader_t
end

type 'a op = 'a builder_t -> unit

val noop : 'a op

val op : ('a builder_t -> 'b -> unit) -> 'b -> 'a op

val list_op :
     ('a builder_t -> 'b list -> ('cap, 'b, Builder.array_t) Capnp.Array.t)
  -> 'b list
  -> 'a op

val reader_op :
  ('a builder_t -> 'b reader_t -> 'b builder_t) -> 'b reader_t -> 'a op

val builder_op :
  ('a builder_t -> 'b builder_t -> 'b builder_t) -> 'b builder_t -> 'a op

val optional :
     (('a builder_t -> 'b -> 'c) -> 'b -> 'a op)
  -> ('a builder_t -> 'b -> 'c)
  -> 'b option
  -> 'a op

val ( *> ) : 'a op -> 'a op -> 'a op

val build' :
  (module Struct_builder_intf with type struct_t = 'a) -> 'a op -> 'a builder_t

val build :
  (module Struct_builder_intf with type struct_t = 'a) -> 'a op -> 'a reader_t
