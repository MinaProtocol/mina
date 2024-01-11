open Core_kernel
open Ipc

module type Struct_builder_intf = sig
  type struct_t

  type t = struct_t builder_t

  val init_root : ?message_size:int -> unit -> t

  val to_reader : t -> struct_t reader_t
end

type 'a op = 'a builder_t -> unit

let noop : 'a op = Fn.ignore

(* even though all of the `op` functions have the same definition, we define them with separate
   types because the signature `forall a b c. (a -> b -> c)` would unsafely allow us to not fully
   apply functions when constructing the DSL *)
let op (type a b) (op : a builder_t -> b -> unit) (value : b) : a op =
 fun builder -> op builder value

let list_op (type a b cap)
    (op : a builder_t -> b list -> (cap, b, Builder.array_t) Capnp.Array.t)
    (value : b list) : a op =
 fun builder -> ignore (op builder value : _ Capnp.Array.t)

let reader_op (type a b) (op : a builder_t -> b reader_t -> b builder_t)
    (value : b reader_t) : a op =
 fun builder -> ignore (op builder value : b builder_t)

let builder_op (type a b) (op : a builder_t -> b builder_t -> b builder_t)
    (value : b builder_t) : a op =
 fun builder -> ignore (op builder value : b builder_t)

let optional (type a b c) (dsl_op : (a builder_t -> b -> c) -> b -> a op)
    (op : a builder_t -> b -> c) (value : b option) : a op =
 fun builder -> Option.iter value ~f:(fun v -> dsl_op op v builder)

let ( *> ) (type a) (x : a op) (y : a op) : a op =
 fun builder -> x builder ; y builder

let build' (type a) (module B : Struct_builder_intf with type struct_t = a)
    (op : a op) : a builder_t =
  let r = B.init_root () in
  op r ; r

let build (type a) (module B : Struct_builder_intf with type struct_t = a)
    (op : a op) : a reader_t =
  B.to_reader (build' (module B) op)
