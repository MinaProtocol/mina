open Core
open Unsigned

module Location : sig
  type t

  include Comparable.S with type t := t

  include Sexpable.S with type t := t

  val create : unit -> t
end = struct
  include Int

  let create =
    let r = ref 0 in
    fun () ->
      let x = !r in
      incr r ; x
end

module Pointer = struct
  type 'a t = Pointer of Location.t | Array_pointer of Location.t * int

  let sexp_of_t = function
    | Pointer loc -> Sexp.List [Atom "pointer"; Location.sexp_of_t loc]
    | Array_pointer (loc, index) ->
        Sexp.List
          [Atom "array_pointer"; Location.sexp_of_t loc; Int.sexp_of_t index]
end

module Function = struct
  type ('a, 'b) t = 'a -> 'b
end

module Elem = struct
  type ('a, 's) t =
    | Here : ('a, 'a * 'b) t
    | There: ('a, 's) t -> ('a, 'b * 's) t

  let rec index : type a b. (a, b) t -> int = function
    | Here -> 0
    | There t -> 1 + index t
end

module Type = struct
  module rec T : sig
    type _ t =
      | Uint32 : uint32 t
      | Bool : bool t
      | Pointer: 'a t -> 'a Pointer.t t
      | Array: 'a t -> 'a array t
      | Struct: 'a List.t -> 'a t
      | Function: 'a List.t * 'b t -> ('a List.t, 'b) Function.t t
      | Type : unit t
      | Label : unit t
      | Void : unit t
  end = T
  
  and List : sig
    type _ t = [] : unit t | ( :: ): 'a T.t * 'b t -> ('a * 'b) t

    type 'b mapper = {f: 'a. 'a T.t -> 'b}

    val map : 'a t -> 'b mapper -> 'b Core.List.t

    val get : 'a t -> ('b, 'a) Elem.t -> 'b T.t
  end = struct
    type _ t = [] : unit t | ( :: ): 'a T.t * 'b t -> ('a * 'b) t

    type 'b mapper = {f: 'a. 'a T.t -> 'b}

    let rec map : type a. a t -> 'b mapper -> 'b Core.List.t =
     fun ls mapper ->
      match ls with
      | [] -> []
      | h :: t -> Core.List.cons (mapper.f h) (map t mapper)

    let rec get : type a b. a t -> (b, a) Elem.t -> b T.t =
     fun ls elem ->
      match (ls, elem) with
      | h :: _, Elem.Here -> h
      | _ :: t, Elem.There e -> get t e
      | _ -> .
  end

  include T

  type 'a arithmetic_result = 'a * ('a * unit)

  let arithmetic_result = Struct [Uint32; Uint32]

  module E = struct
    module T = struct
      type e = T: 'a t -> e

      type t = e sexp_opaque [@@deriving sexp]

      let compare = compare

      let hash = Hashtbl.hash
    end

    include T
    include Comparable.Make (T)
    module Table = Hashtbl.Make (T)
  end

  let rec to_string : type a. a t -> string = function
    | Uint32 -> "u32"
    | Bool -> "bool"
    | Pointer t -> to_string t ^ "_ptr"
    | Array s -> to_string s ^ "_array"
    | Struct _ -> "struct" (* TODO *)
    | Function _ -> "fn" (* TODO *)
    | Type -> "type"
    | Label -> "label"
    | Void -> "void"

  let is_void : type a. a t -> bool = function Void -> true | _ -> false

  let function_return_type : type args rt.
      (args List.t, rt) Function.t t -> rt t = function
    | Function (_, rt) -> rt
    | _ -> assert false

  let struct_types : type a. a t -> a List.t = function
    | Struct types -> types
    | _ -> assert false

  let struct_elt : type a. a t -> ('b, a) Elem.t -> 'b t = function
    | Struct types -> List.get types
    | _ -> assert false

  let pointer_elt : type a. a Pointer.t t -> a t = function
    | Pointer elt -> elt
    | _ -> assert false

  let array_elt : type a. a array t -> a t = function
    | Array elt -> elt
    | _ -> assert false

  let rec equality : type a b. a t -> b t -> (a, b) Type_equal.t option =
   fun x y ->
    match (x, y) with
    | Pointer a1, Pointer a2 -> (
      match equality a1 a2 with
      | Some Type_equal.T -> Some Type_equal.T
      | None -> None )
    | Uint32, Uint32 -> Some Type_equal.T
    | Bool, Bool -> Some Type_equal.T
    | Array a, Array b -> (
      match equality a b with
      | Some Type_equal.T -> Some Type_equal.T
      | None -> None )
    | _, _ -> None
end

module Id = struct
  module T = struct
    type 'a t = Id: 'a Type.t * string * int -> 'a t
  end

  include T

  module List = struct
    type _ t = [] : unit t | ( :: ): 'a T.t * 'b t -> ('a * 'b) t

    type 'b mapper = {f: 'a. 'a T.t -> 'b}

    let rec map : type a. a t -> 'b mapper -> 'b Core.List.t =
     fun ls mapper ->
      match ls with
      | [] -> []
      | h :: t -> Core.List.cons (mapper.f h) (map t mapper)
  end

  module PointerList = struct
    type _ t = [] : unit t | ( :: ): 'a Pointer.t T.t * 'b t -> ('a * 'b) t

    type 'b mapper = {f: 'a. 'a Pointer.t T.t -> 'b}

    let rec map : type a. a t -> 'b mapper -> 'b Core.List.t =
     fun ls mapper ->
      match ls with
      | [] -> []
      | h :: t -> Core.List.cons (mapper.f h) (map t mapper)
  end

  let sexp_of_t (Id (_, name, value)) =
    Sexp.List
      [Atom "Id"; List [Atom "<opaque>"; Atom name; Atom (string_of_int value)]]

  let typ (Id (typ, _, _)) = typ

  let name (Id (_, name, _)) = name

  let value (Id (_, _, value)) = value

  let pointer typ name value = Id (Type.Pointer typ, name, value)

  let dummy typ value = Id (typ, "dummy", value)
end

module Op = struct
  (* First arg is the result *)
  module Value = struct
    type _ op =
      | Or: bool Id.t * bool Id.t -> bool op
      | Add: uint32 Id.t * uint32 Id.t -> uint32 Type.arithmetic_result op
      | Add_ignore_overflow: uint32 Id.t * uint32 Id.t -> uint32 op
      | Sub: uint32 Id.t * uint32 Id.t -> uint32 Type.arithmetic_result op
      | Sub_ignore_overflow: uint32 Id.t * uint32 Id.t -> uint32 op
      | Mul: uint32 Id.t * uint32 Id.t -> uint32 Type.arithmetic_result op
      | Mul_ignore_overflow: uint32 Id.t * uint32 Id.t -> uint32 op
      | Div_ignore_remainder: uint32 Id.t * uint32 Id.t -> uint32 op
      | Bitwise_or: uint32 Id.t * uint32 Id.t -> uint32 op
      | Less_than: uint32 Id.t * uint32 Id.t -> bool op
      | Equal: uint32 Id.t * uint32 Id.t -> bool op
      | Array_access: 'a array Pointer.t Id.t * uint32 Id.t -> 'a Pointer.t op
      | Struct_get: 's Id.t * ('a, 's) Elem.t -> 'a op
      | Load: 'a Pointer.t Id.t -> 'a op

    type 'a t = {op: 'a op; result_name: string}

    let typ : type a. a op -> a Type.t = function
      | Or _ -> Type.Bool
      | Add _ -> Type.arithmetic_result
      | Add_ignore_overflow _ -> Type.Uint32
      | Sub _ -> Type.arithmetic_result
      | Sub_ignore_overflow _ -> Type.Uint32
      | Mul _ -> Type.arithmetic_result
      | Mul_ignore_overflow _ -> Type.Uint32
      | Div_ignore_remainder _ -> Type.Uint32
      | Bitwise_or _ -> Type.Uint32
      | Less_than _ -> Type.Bool
      | Equal _ -> Type.Bool
      | Array_access (arr, _) ->
          Type.Pointer (Type.array_elt @@ Type.pointer_elt @@ Id.typ arr)
      | Struct_get (id, loc) -> (
        match Id.typ id with
        | Type.Struct spec -> Type.List.get spec loc
        | _ -> assert false )
      | Load ptr -> Type.pointer_elt (Id.typ ptr)
  end

  module Action = struct
    type t = Store: 'a Pointer.t Id.t * 'a Id.t -> t
  end
end

module Arguments_spec = struct
  type ('types, 'f, 'k) t =
    | [] : (unit, 'k, 'k) t
    | ( :: ): 'a Type.t * ('ts, 'b, 'k) t -> ('a * 'ts, 'a Id.t -> 'b, 'k) t

  type 'b id_mapper = {map_id: 'a. 'a Id.t -> 'b}

  let rec map_ids : type types args f k.
      (types, f, k) t -> types Id.List.t -> 'r id_mapper -> 'r list =
   fun t args id_mapper ->
    match (t, args) with
    | [], Id.List.([]) -> []
    | _ :: arg_spec_tail, Id.List.(arg :: arg_tail) ->
        id_mapper.map_id arg :: map_ids arg_spec_tail arg_tail id_mapper

  type generator = {generate: 'a. 'a Type.t -> 'a Id.t}

  let rec apply : type types args f k.
         (types, f, k) t
      -> generator
      -> f
      -> types Type.List.t * types Id.List.t * k =
   fun t gen f ->
    match t with
    | [] -> ([], Id.List.[], f)
    | head :: tail ->
        let c = gen.generate head in
        let ts, ats, k = apply tail gen (f c) in
        (head :: ts, Id.List.(c :: ats), k)
end

module Local_variables_spec = struct
  type ('types, 'f, 'k) t =
    | [] : (unit, unit -> 'k, 'k) t
    | ( :: ):
        'a Type.t * ('vs, 'b, 'k) t
        -> ('a * 'vs, 'a Pointer.t Id.t -> 'b, 'k) t

  type 'b id_mapper = {map_id: 'a. 'a Pointer.t Id.t -> 'b}

  let rec map_ids : type vars f k.
      (vars, f, k) t -> vars Id.PointerList.t -> 'r id_mapper -> 'r list =
   fun t args id_mapper ->
    match (t, args) with
    | [], Id.PointerList.([]) -> []
    | _ :: arg_spec_tail, Id.PointerList.(arg :: arg_tail) ->
        id_mapper.map_id arg :: map_ids arg_spec_tail arg_tail id_mapper

  type generator = {generate: 'a. 'a Type.t -> 'a Pointer.t Id.t}

  let rec apply : type vars f k.
      (vars, f, k) t -> generator -> f -> vars Id.PointerList.t * k =
   fun t gen f ->
    match t with
    | [] -> (Id.PointerList.[], f ())
    | head :: tail ->
        let c = gen.generate head in
        let str, k = apply tail gen (f c) in
        (Id.PointerList.(c :: str), k)
end

module T = struct
  type 'a t =
    | Set_prefix of string * 'a t
    | Declare_function:
        string
        * ('types, 'f, 'g) Arguments_spec.t
        * ('vars, 'g, 'ret Id.t t) Local_variables_spec.t
        * 'ret Type.t
        * 'f
        * (('types Type.List.t, 'ret) Function.t Id.t -> 'a t)
        -> 'a t
    | Call_function:
        ('args Type.List.t, 'ret) Function.t Id.t
        * 'args Id.List.t
        * ('ret Id.t -> 'a t)
        -> 'a t
    | Value_op: 'a Op.Value.t * ('a Id.t -> 'b t) -> 'b t
    | Action_op of Op.Action.t * (unit -> 'a t)
    | Declare_constant: 'a Type.t * 'a * ('a Id.t -> 'b t) -> 'b t
    | For of
        { var_ptr: uint32 Pointer.t Id.t
        ; range: (uint32 Id.t * uint32 Id.t)
        ; body: (uint32 Id.t -> unit Id.t t)
        ; after: (unit -> 'a t) }
    | Do_if:
        { cond: bool Id.t
        ; then_: (unit -> unit Id.t t)
        ; after: (unit -> 'a t) }
        -> 'a t
    | If:
        { cond: bool Id.t
        ; then_: (unit -> 'b Id.t t)
        ; else_: (unit -> 'b Id.t t)
        ; after: ('b Id.t -> 'a t) }
        -> 'a t
    | Pure of 'a

  let rec map t ~f =
    match t with
    | Call_function (id, arg, k) ->
        Call_function (id, arg, fun x -> map (k x) ~f)
    | Declare_function (name, args, vars, ret, body, k) ->
        Declare_function (name, args, vars, ret, body, fun x -> map (k x) ~f)
    | Pure x -> Pure (f x)
    | Set_prefix (s, k) -> Set_prefix (s, map k ~f)
    | Declare_constant (typ, x, k) ->
        Declare_constant (typ, x, fun v -> map (k v) ~f)
    | Action_op (op, k) -> Action_op (op, fun () -> map (k ()) ~f)
    | Value_op (op, k) -> Value_op (op, fun v -> map (k v) ~f)
    | For {var_ptr; range; body; after} ->
        For {var_ptr; range; body; after= (fun ctx -> map (after ctx) ~f)}
    | If {cond; then_; else_; after} ->
        If {cond; then_; else_; after= (fun v -> map (after v) ~f)}
    | Do_if {cond; then_; after} ->
        Do_if {cond; then_; after= (fun x -> map (after x) ~f)}

  let rec bind : type a b. a t -> f:(a -> b t) -> b t =
   fun t ~f ->
    match t with
    | Declare_function (name, args, vars, ret, body, k) ->
        Declare_function (name, args, vars, ret, body, fun x -> bind (k x) ~f)
    | Call_function (id, arg, k) ->
        Call_function (id, arg, fun x -> bind (k x) ~f)
    | Pure x -> f x
    | Set_prefix (s, k) -> Set_prefix (s, bind k ~f)
    | Declare_constant (typ, x, k) ->
        Declare_constant (typ, x, fun v -> bind (k v) ~f)
    | Action_op (op, k) -> Action_op (op, fun () -> bind (k ()) ~f)
    | Value_op (op, k) -> Value_op (op, fun v -> bind (k v) ~f)
    | For {var_ptr; range; body; after} ->
        For {var_ptr; range; body; after= (fun ctx -> bind (after ctx) ~f)}
    | If {cond; then_; else_; after} ->
        If {cond; then_; else_; after= (fun v -> bind (after v) ~f)}
    | Do_if {cond; then_; after} ->
        Do_if {cond; then_; after= (fun x -> bind (after x) ~f)}

  let return x = Pure x
end

include Monad.Make (struct
  include T

  let map = `Custom map
end)

include T
open Let_syntax

let void = Id.Id (Type.Void, "void", 0)

let for_ var_ptr range body =
  For {var_ptr; range; body; after= (fun _ -> return ())}

let if_ cond ~then_ ~else_ = If {cond; then_; else_; after= (fun v -> return v)}

let do_if cond then_ = Do_if {cond; then_; after= (fun v -> return v)}

let set_prefix prefix = Set_prefix (prefix, return ())

let do_value ?name op =
  Value_op ({op; result_name= Option.value ~default:"anonymous" name}, return)

let do_ op = Action_op (op, fun () -> return ())

let constant typ x = Declare_constant (typ, x, return)

let declare_function name ~args ~vars ~returning body =
  Declare_function (name, args, vars, returning, body, return)

let array_access ?name xs i = do_value ?name (Array_access (xs, i))

let struct_get ?name str elem = do_value ?name (Struct_get (str, elem))

let less_than ?name x y = do_value ?name (Less_than (x, y))

let store ptr value = Action_op (Op.Action.Store (ptr, value), return)

let or_ ?name x y = do_value ?name (Or (x, y))

let arith_op op_name k =
  stage (fun x y name ->
      let name = Option.map name ~f:(sprintf "%s_%s_result" op_name) in
      let%bind r = do_value ?name (k x y) in
      let%map low_bits = struct_get r Elem.Here in
      let%map high_bits = struct_get r Elem.(There Here) in
      (low_bits, high_bits) )

let add = unstage (arith_op "add" (fun x y -> Add (x, y)))

let sub = unstage (arith_op "sub" (fun x y -> Sub (x, y)))

let mul = unstage (arith_op "mul" (fun x y -> Mul (x, y)))

let add_ignore_overflow ?name x y =
  do_value ?name (Op.Value.Add_ignore_overflow (x, y))

let bitwise_or ?name x y = do_value ?name (Op.Value.Bitwise_or (x, y))

let equal_uint32 ?name x y = do_value ?name (Op.Value.Equal (x, y))
