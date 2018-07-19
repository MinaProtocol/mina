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
      incr r;
      x
end

module Pointer = struct
  type 'a t = Pointer of Location.t

  let sexp_of_t (Pointer loc) =
    Sexp.List [ Atom "pointer"; Location.sexp_of_t loc ]
end

module Function = struct
  type ('a, 'b) t = 'a -> 'b
end

module Arith_result = struct
  type 'a t =
    { low_bits : 'a
    ; high_bits : 'a
    }
end

module PolyTuple = struct
  type 'a t =
    | [] : unit t
    | (::) : 'a * 'b t -> ('a * 'b) t
end

module Struct_location = struct
  type ('a, 's) t =
    | Here : ('a, 'a * 'b) t
    | There : ('a, 's) t -> ('a, 'b * 's) t
end

module Type = struct
  module Scalar = struct
    type 'a t =
      | Uint32 : uint32 t
      | Bool : bool t
    [@@deriving hash]

    let to_string : type a. a t -> string = function
      | Uint32 -> "u32"
      | Bool -> "bool"

    let equality : type a b. a t -> b t -> (a, b) Type_equal.t option =
      fun x y ->
        match x, y with
        | Uint32, Uint32 -> Some Type_equal.T
        | Bool, Bool -> Some Type_equal.T
        | _, _ -> None

    let equal : type a b. a t -> b t -> bool =
      fun x y -> Option.is_some (equality x y)
  end

  type _ t =
    | Scalar  : 'a Scalar.t -> 'a t
    | Pointer : 'a t -> 'a Pointer.t t
    | Array   : 'a Scalar.t -> 'a array t
    | Tuple2  : 'a Scalar.t * 'b Scalar.t -> ('a * 'b) t
    | Arith_result  : uint32 Arith_result.t t
    | Struct : 'a list -> 'a list t
    | Function : 'a list * 'b t -> ('a list, 'b) Function.t t
    | Type : unit t
    | Label : unit t
    | Void : unit t
  and _ list =
    | [] : unit list
    | (::) : 'a t * 'b list -> ('a * 'b) list

  type 'b mapper = { f : 'a. 'a t -> 'b }

  let rec map : type a. a list -> 'b mapper -> 'b List.t =
    fun ls mapper ->
      match ls with
        | [] -> []
        | h :: t -> List.cons (mapper.f h) (map t mapper)

  let rec to_string : type a. a t -> string = function
    | Scalar s -> Scalar.to_string s
    | Pointer t -> to_string t ^ "_ptr"
    | Array s -> Scalar.to_string s ^ "_array"
    | Tuple2 (s0, s1) -> "tuple2_" ^ Scalar.to_string s0 ^ "_" ^ Scalar.to_string s1
    | Arith_result -> "u32_arith_result"
    | Struct _ -> "struct" (* TODO *)
    | Function _ -> "fn" (* TODO *)
    | Type -> "type"
    | Label -> "label"
    | Void -> "void"

  module Enum = struct
    module T = struct
      type e =
        | T : 'a t -> e
      type t = e sexp_opaque [@@deriving sexp]

      let compare = compare
      let hash = Hashtbl.hash
    end

    include T
    include Comparable.Make(T)
    module Table = Hashtbl.Make(T)
  end

  let fst : type a b. (a * b) t -> a t = function
    | Tuple2 (x,_) -> Scalar x
    | _ -> assert false

  let snd : type a b. (a * b) t -> b t = function
    | Tuple2 (x, y) -> Scalar y
    | _ -> assert false

  let pointer_elt : type a. a Pointer.t t -> a t = function
    | Pointer elt -> elt
    | _ -> assert false

  let array_elt : type a. a array t -> a t = function
    | Array scalar -> Scalar scalar
    | _ -> assert false

  let rec equality : type a b. a t -> b t -> (a, b) Type_equal.t option =
    fun x y ->
      match x, y with
      | Pointer a1, Pointer a2 ->
        begin match equality a1 a2 with
        | Some Type_equal.T -> Some Type_equal.T
        | None -> None
        end
      | Arith_result, Arith_result -> Some Type_equal.T
      | Tuple2 (a1, b1), Tuple2 (a2, b2) ->
        begin match Scalar.equality a1 a2, Scalar.equality b1 b2 with
        | Some Type_equal.T, Some Type_equal.T -> Some Type_equal.T
        | _ -> None
        end
      | Scalar a, Scalar b -> Scalar.equality a b
      | Array a, Array b ->
        begin match Scalar.equality a b with
        | Some Type_equal.T -> Some Type_equal.T
        | None -> None
        end
      | _, _ -> None

  let uint32 = Scalar Uint32
  let bool = Scalar Bool
end

module Id = struct
  type 'a t =
    | Id : 'a Type.t * string * int -> 'a t

  let sexp_of_t (Id (_, name, value)) =
    Sexp.List [ Atom "Id"; List [Atom "<opaque>"; Atom name; Atom (string_of_int value)]]

  let typ (Id (typ, _, _)) = typ
  let name (Id (_, name, _)) = name
  let value (Id (_, _, value)) = value

  let pointer typ name value = Id (Type.Pointer typ, name, value)
  let dummy typ value = Id (typ, "dummy", value)
end

module Op = struct
  (* First arg is the result *)
  module Value = struct
    type 'a op =
      | Or : bool Id.t * bool Id.t -> bool op
      | Add : uint32 Id.t * uint32 Id.t -> uint32 Arith_result.t op
      | Add_ignore_overflow : uint32 Id.t * uint32 Id.t -> uint32 op
      | Sub : uint32 Id.t * uint32 Id.t -> uint32 Arith_result.t op
      | Sub_ignore_overflow : uint32 Id.t * uint32 Id.t -> uint32 op
      | Mul : uint32 Id.t * uint32 Id.t -> uint32 Arith_result.t op
      | Mul_ignore_overflow : uint32 Id.t * uint32 Id.t -> uint32 op
      | Div_ignore_remainder : uint32 Id.t * uint32 Id.t -> uint32 op
      | Bitwise_or : uint32 Id.t * uint32 Id.t -> uint32 op
      | Less_than : uint32 Id.t * uint32 Id.t -> bool op
      | Equal : uint32 Id.t * uint32 Id.t -> bool op
      | Array_get : 'b array Id.t * uint32 Id.t -> 'b op
      | Struct_access : 's Type.list Id.t * ('a, 's) Struct_location.t -> 'a op
      | Fst : ('a * 'b) Id.t -> 'a op
      | Snd : ('a * 'b) Id.t -> 'b op
      | High_bits : uint32 Arith_result.t Id.t -> uint32 op
      | Low_bits : uint32 Arith_result.t Id.t -> uint32 op

    type 'a t = { op : 'a op; result_name : string }

    let rec struct_access
      : type a s. s Type.list -> (a, s) Struct_location.t -> a Type.t
      =
      let open Type in
      let open Struct_location in
      fun spec loc ->
        match spec, loc with
        | typ :: _ , Here -> typ
        | _ :: spec, There loc -> struct_access spec loc
        | [], _ -> .

    let typ : type a. a op -> a Type.t = function
      | Or _ -> Type.bool
      | Add _ -> Type.Arith_result
      | Add_ignore_overflow _ -> Type.uint32
      | Sub _ -> Type.Arith_result
      | Sub_ignore_overflow _ -> Type.uint32
      | Mul _ -> Type.Arith_result
      | Mul_ignore_overflow _ -> Type.uint32
      | Div_ignore_remainder _ -> Type.uint32
      | Bitwise_or _ -> Type.uint32
      | Less_than _ -> Type.bool
      | Equal _ -> Type.bool
      | High_bits _ -> Type.uint32
      | Low_bits _ -> Type.uint32
      | Array_get (arr, _) -> Type.array_elt (Id.typ arr)
      | Fst t -> Type.fst (Id.typ t)
      | Snd t -> Type.snd (Id.typ t)
      | Struct_access (id, loc) ->
          begin match Id.typ id with
          | Type.Struct spec -> struct_access spec loc
          | _ -> assert false
          end
  end

  module Action = struct
    type t =
      | Array_set : 'b array Id.t * uint32 Id.t * 'b Id.t -> t
      | Store : 'a Pointer.t Id.t * 'a Id.t -> t
  end
end

module Arguments_spec = struct
  type ('types, 'args, 'f, 'k) t =
    | [] : (unit, unit, 'k, 'k) t
    | (::) : 'a Type.t * ('ts, 'ats, 'b, 'k) t -> ('a * 'ts, 'a Id.t * 'ats, 'a Id.t -> 'b, 'k) t

  type 'b id_mapper = { map_id : 'a. 'a Id.t -> 'b }

  let rec map_ids : type types args f k. (types, args, f, k) t -> args PolyTuple.t -> 'r id_mapper -> 'r list  =
    fun t args id_mapper ->
      match t, args with 
      | ([], PolyTuple.([])) -> []
      | (_ :: arg_spec_tail, PolyTuple.(arg :: arg_tail)) ->
           List.(id_mapper.map_id arg :: map_ids arg_spec_tail arg_tail id_mapper)

  type generator = { generate : 'a. 'a Type.t -> 'a Id.t }

  let rec apply : type types args f k. (types, args, f, k) t -> generator -> f -> types Type.list * args PolyTuple.t * k =
    fun t gen f ->
      match t with
        | [] -> (Type.([]), PolyTuple.([]), f)
        | head :: tail ->
            let c = gen.generate head in
            let (ts, ats, k) = apply tail gen (f c) in
            (Type.(head :: ts), PolyTuple.(c :: ats), k)
end

module Local_variables_spec = struct
  type ('vars, 'f, 'k) t =
    | [] : (unit, unit -> 'k, 'k) t
    | (::) : 'a Type.t * ('vs, 'b, 'k) t -> ('a Pointer.t Id.t * 'vs, 'a Pointer.t Id.t -> 'b, 'k) t

  type 'b id_mapper = { map_id : 'a. 'a Pointer.t Id.t -> 'b }

  let rec map_ids : type vars f k. (vars, f, k) t -> vars PolyTuple.t -> 'r id_mapper -> 'r list  =
    fun t args id_mapper ->
      match t, args with 
      | ([], PolyTuple.([])) -> []
      | (_ :: arg_spec_tail, PolyTuple.(arg :: arg_tail)) ->
           List.(id_mapper.map_id arg :: map_ids arg_spec_tail arg_tail id_mapper)

  type generator = { generate : 'a. 'a Type.t -> 'a Pointer.t Id.t }

  let rec apply : type vars f k. (vars, f, k) t -> generator -> f -> vars PolyTuple.t * k =
    fun t gen f ->
      match t with
        | [] -> (PolyTuple.([]), f ())
        | head :: tail ->
            let c = gen.generate head in
            let (str, k) = apply tail gen (f c) in
            (PolyTuple.(c :: str), k)
end

module T = struct
  type 'a t =
    | Set_prefix of string * 'a t
    | Declare_function
      : string
        * ('types, 'args, 'f, 'g) Arguments_spec.t
        * ('vars, 'g, 'ret t) Local_variables_spec.t
        * 'ret Type.t
        * 'f
        * (('types Type.list, 'ret) Function.t Id.t -> 'a t)
        -> 'a t
    | Call_function
      : ('args, 'ret) Function.t Id.t
        * 'args PolyTuple.t
        * ('ret Id.t -> 'a t)
      -> 'a t
    | Create_pointer
      : 'c Type.t * string
        * ('c Pointer.t Id.t -> 'b t) ->  'b t
    | Load : 'c Pointer.t Id.t * string * ('c Id.t -> 'a t) -> 'a t
    | Value_op : 'a Op.Value.t * ('a Id.t -> 'b t) -> 'b t
    | Action_op of Op.Action.t * (unit -> 'a t)
    | Declare_constant : 'a Type.t * 'a * ('a Id.t -> 'b t) -> 'b t
    | For of
        { var_ptr : uint32 Pointer.t Id.t
        ; range: uint32 Id.t * uint32 Id.t
        ; body : uint32 Id.t -> unit t
        ; after : unit -> 'a t
        }
    | Phi of string list * (unit -> 'a t)
    | Do_if :
        { cond : bool Id.t
        ; then_ : unit t
        ; after : (unit -> 'a t)
        }
        -> 'a t
    | If :
        { cond : bool Id.t
        ; then_ : 'b Id.t
        ; else_ : 'b Id.t
        ; after : ('b Id.t -> 'a t)
        }
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
    | Create_pointer (typ, s, k) ->
      Create_pointer (typ, s, fun v -> map (k v) ~f)
    | Load (ptr, lab, k) ->
      Load (ptr, lab, fun v -> map (k v) ~f)
    | Action_op (op, k) -> Action_op (op, fun () -> map (k ()) ~f)
    | Value_op (op, k) -> Value_op (op, fun v -> map (k v) ~f)
    | For { var_ptr; range; body; after } ->
      For { var_ptr; range; body; after = fun ctx -> map (after ctx) ~f }
    | Phi (vs, k) -> Phi (vs, fun () -> map (k ()) ~f)
    | If { cond; then_; else_; after } ->
      If { cond; then_; else_; after = fun v -> map (after v) ~f }
    | Do_if { cond; then_; after } ->
      Do_if { cond; then_; after = fun x -> map (after x) ~f }

  let rec bind : type a b. a t -> f:(a -> b t) -> b t =
    fun t ~f ->
      match t with
      | Declare_function (name, args, vars, ret, body, k) ->
        Declare_function (name, args, vars, ret, body, fun x -> bind (k x) ~f)
      | Call_function (id, arg, k) ->
        Call_function (id, arg, fun x -> bind (k x) ~f)
      | Pure x -> f x
      | Set_prefix (s, k) -> Set_prefix (s, bind k ~f)
      | Create_pointer (typ, s, k) ->
        Create_pointer (typ, s, fun v -> bind (k v) ~f)
      | Declare_constant (typ, x, k) ->
        Declare_constant (typ, x, fun v -> bind (k v) ~f)
      | Load (ptr, lab, k) ->
        Load (ptr, lab, fun v -> bind (k v) ~f)
      | Action_op (op, k) -> Action_op (op, fun () -> bind (k ()) ~f)
      | Value_op (op, k) -> Value_op (op, fun v -> bind (k v) ~f)
      | For { var_ptr; range; body; after } ->
        For { var_ptr; range; body; after = fun ctx -> bind (after ctx) ~f }
      | Phi (vs, k) -> Phi (vs, fun () -> bind (k ()) ~f)
      | If { cond; then_; else_; after } ->
        If { cond; then_; else_; after = fun v -> bind (after v) ~f }
      | Do_if { cond; then_; after } ->
        Do_if { cond; then_; after = fun x -> bind (after x) ~f }

  let return x = Pure x
end

include Monad.Make(struct
  include T
  let map = `Custom map
end)

include T
open Let_syntax

let for_ var_ptr range body = For { var_ptr; range; body; after = fun _ -> return () }
let if_ cond ~then_ ~else_ = If { cond; then_; else_; after = fun v -> return v }
let do_if cond then_ = Do_if { cond; then_; after = fun v -> return v }

let set_prefix prefix = Set_prefix (prefix, return ())

let array_get result_name arr i =
  Value_op ({ op = Array_get (arr, i); result_name }, return)

let do_value op result_name = Value_op ({ op; result_name }, return)
let do_ op = Action_op (op, fun () -> return ())

let constant typ x =
  Declare_constant (typ, x, return)

let declare_function name ~args ~vars ~returning body =
  Declare_function (name, args, vars, returning, body, return)

let array_get label xs i =
  let open Op.Value in
  do_value (Array_get (xs, i)) label

let array_set xs i x =
  do_ (Array_set (xs, i, x))

let less_than lab x y = do_value (Less_than (x, y)) lab

let create_pointer typ label =
  Create_pointer (typ, label, return)

let load ptr label =
  Load (ptr, label, return)

let store ptr value =
  Action_op (Op.Action.Store (ptr, value), return)

let high_bits x lab = do_value (High_bits x) lab
let low_bits x lab = do_value (Low_bits x) lab

let or_ x y lab = do_value (Or (x, y)) lab

let arith_op name k =
  stage
    (fun x y lab ->
      let%bind r = do_value (k x y) (sprintf "%s_%s_result" lab name) in
      let%map high_bits = high_bits r (lab ^ "_high_bits")
      and low_bits = low_bits r (lab ^ "_low_bits")
      in
      { Arith_result.high_bits; low_bits })

let add = unstage (arith_op "add" (fun x y -> Add (x, y)))
let sub = unstage (arith_op "sub" (fun x y -> Sub (x, y)))
let mul = unstage (arith_op "mul" (fun x y -> Mul (x, y)))

let add_ignore_overflow x y lab =
  do_value (Op.Value.Add_ignore_overflow (x, y)) lab

let bitwise_or x y lab =
  do_value (Op.Value.Bitwise_or (x, y)) lab

let equal_uint32 x y lab =
  do_value (Op.Value.Equal (x, y)) lab
