open Ctypes
open Foreign

module Views = struct
  open Unsigned

  let bool_to_int =
    view
      ~read:(fun i -> i <> 0)
      ~write:(function true -> 1 | false -> 0)
      int

  let bool_to_uchar =
    view
      ~read:(fun u -> u <> UChar.zero)
      ~write:(function true -> UChar.one | false -> UChar.zero)
      uchar

  let int_to_size_t =
    view
      ~read:Size_t.to_int
      ~write:Size_t.of_int
      size_t

  let int_to_uint_t =
    view
      ~read:UInt.to_int
      ~write:UInt.of_int
      uint

  let int_to_uint32_t =
    view
      ~read:UInt32.to_int
      ~write:UInt32.of_int
      uint32_t

  let int_to_uint64_t =
    view
      ~read:UInt64.to_int
      ~write:UInt64.of_int
      uint64_t
end

let free =
  foreign
    "free"
    (ptr void @-> returning void)

module type RocksType =
  sig
    val name : string
    val constructor : string
    val destructor : string
    val setter_prefix : string
  end

module type RocksType' =
  sig
    val name : string
  end

type t =  {
  ptr : unit ptr;
  mutable valid : bool;
}

let get_pointer t = t.ptr

exception OperationOnInvalidObject

let t : t typ =
  view
    ~read:(fun ptr -> { ptr; valid = true; })
    ~write:(
      fun { ptr; valid; } ->
        if valid
        then ptr
        else raise OperationOnInvalidObject)
    (ptr void)

let make_destroy t destructor =
  let inner =
    foreign
      destructor
      (t @-> returning void) in
  fun t ->
  inner t;
  t.valid <- false

let finalize f finalizer =
  match f () with
  | a -> finalizer ();
         a
  | exception exn -> finalizer ();
                     raise exn

module type S = sig
  type t

  val t : t Ctypes.typ
  val get_pointer : t -> unit Ctypes.ptr
  val type_name : string

  val create : unit -> t
  val create_no_gc : unit -> t
  val destroy : t -> unit
  val with_t : (t -> 'a) -> 'a

  val create_setter : string -> 'a Ctypes.typ -> t -> 'a -> unit
end

module CreateConstructors(T : RocksType) = struct

  type nonrec t = t
  let t = t

  let get_pointer = get_pointer

  let type_name = T.name

  let create_no_gc =
    foreign
      T.constructor
      (void @-> returning t)

  let destroy = make_destroy t T.destructor

  let create () =
    let t = create_no_gc () in
    Gc.finalise destroy t;
    t

  let with_t f =
    let t = create_no_gc () in
    finalize
      (fun () -> f t)
      (fun () -> destroy t)

  let create_setter property_name property_typ =
    foreign
      (T.setter_prefix ^ property_name)
      (t @-> property_typ @-> returning void)
end

module CreateConstructors_(T : RocksType') = struct
  include CreateConstructors(struct
      let name = T.name
      let constructor = "rocksdb_" ^ T.name ^ "_create"
      let destructor  = "rocksdb_" ^ T.name ^ "_destroy"
      let setter_prefix = "rocksdb_" ^ T.name ^ "_"
    end)
end
