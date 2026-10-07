open Core_kernel

module MapRep = struct
  module type S = sig
    type ('k, 'v) t
  end

  module Alist = struct
    type ('k, 'v) rep = ('k * 'v) list
  end

  module HMap = struct
    type ('k, 'v) rep = ('k, 'v) Hashtbl.t
  end

  module Strings = struct
    type ('k, 'v) rep = string

    type format = { inner_delim : string; entry_delim : string }
  end

  type schema =
    [ `Alist | `HMap | `Strings of Strings.format | `Advanced of string ]
end

module ListRep = struct
  module type S = sig
    type 'a t
  end

  module List : S = struct
    type 'a t = 'a list
  end

  module Array : S = struct
    type 'a t = 'a array
  end

  type schema = [ `List | `Advanced ]
end

module BytesRep = struct
  module type S = sig
    type t
  end

  module Bytes = struct
    type t = bytes
  end

  type schema = [ `Bytes | `Advanced of string ]
end

module DataModel = struct
  type kinds =
    [ `Boolean
    | `Integer
    | `Float
    | `Map
    | `List
    | `String
    | `Null
    | `Bytes
    | `Link ]

  type index = [ `List of int | `Map of string ]

  module Ipld (Cid : Cid.S) (M : MapRep.S) (L : ListRep.S) = struct
    type ipld =
      [ `Boolean of bool
      | `Integer of int64
      | `Float of float
      | `Map of (index, ipld) M.t (* todo: don't use an alist *)
      | `List of ipld L.t
      | `String of string
      | `Null
      | `Bytes of bytes
      | `Link of Cid.t ]

    type scalar =
      [ `Boolean of bool
      | `Integer of int
      | `Float of float
      | `String of string
      | `Null
      | `Bytes of bytes
      | `Link of Cid.t ]
  end
end

module UnionRep = struct
  type envelope =
    { discriminant_key : string
    ; content_key : string
    ; discriminant_table : (string * string) list
    }

  type inline =
    { discriminant_key : string; discriminant_table : (string * string) list }

  type byte_prefix = { discriminant_table : (string * int) list }

  type schema =
    [ `Kinded of (DataModel.kinds * string) list
    | `Keyed of (string * string) list
    | `Envelop of envelope
    | `Inline of inline
    | `BytePrefix of byte_prefix ]
end

module StructRep = struct
  type field = { rename : string option; implicit : DataModel.scalar option }

  type string_join = { sep : string; field_order : string list }

  type schema =
    [ `Map of (string * field) list
    | `Tuple of string list
    | `StringPairs of MapRep.Strings.format
    | `StringJoin of string_join
    | `ListPairs ]
end

module EnumRep = struct
  type schema =
    [ `String of (string * string) list | `Int of (string * int) list ]
end

module Schema = struct
  [@@@ocaml.warning "-30"]

  type adl = [ `Unimplemented ]

  type typ =
    [ `Boolean
    | `Integer
    | `Float
    | `Map of map_typ
    | `List of list_typ
    | `String
    | `Null
    | `Bytes of BytesRep.schema
    | `Link of typ
    | `Union of UnionRep.schema
    | `Struct of struct_typ
    | `Enum of EnumRep.schema
    | `Copy of [ `Named of string ] ]

  and term =
    [ `Named of string | `Inline of [ `Map of map_typ | `List of list_typ ] ]

  and map_typ =
    { key_type : [ `Named of string ]
    ; value_type : term
    ; nullable : bool
    ; rep : MapRep.schema
    }

  and list_typ = { list_typ : term; nullable : bool; rep : ListRep.schema }

  and struct_typ = { fields : (string * field) list; rep : StructRep.schema }

  and field = { typ : term; optional : bool; nullable : bool }

  type t = { types : (string * typ) list; advanced : (string * adl) list }

  let to_string { types; _ } =
    let scalar_to_string = function
      | `Boolean b ->
          Bool.to_string b
      | `Integer i ->
          Int.to_string i
      | `Float f ->
          Float.to_string f
      | `String s ->
          s
      | `Bytes b ->
          failwith "TODO: encode bytes"
    and typ_to_string = function
      | `Boolean ->
          "boolean"
      | `Integer ->
          "integer"
      | `Float ->
          "float"
      | `Map m ->
          failwith "TODO: encode map"
      | `List l ->
          failwith "TODO: encode list"
      | `String ->
          "string"
      | `Null ->
          "null"
      | `Bytes b ->
          "bytes"
      | `Link l ->
          failwith "TODO: encode link"
      | `Union u ->
          failwith "TODO: encode union"
      | `Struct s ->
          failwith "TODO: encode struct"
      | `Enum e ->
          failwith "TODO: encode enum"
      | `Copy c ->
          failwith "TODO: encode copy"
    in
    String.concat ~sep:"\n\n"
      (List.map types ~f:(fun (name, typ) ->
           Printf.sprintf "type %s %s" name (typ_to_string typ) ) )
end
