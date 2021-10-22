module Backend = Zexe_backend.Pasta.Vesta_based_plonk
module Other_backend = Zexe_backend.Pasta.Pallas_based_plonk

module Impl = Pickles.Impls.Step
module Other_impl = Pickles.Impls.Wrap
module Challenge = Limb_vector.Challenge.Make (Impl)
module Sc =
  Pickles.Scalar_challenge.Make (Impl) (Pickles.Step_main_inputs.Inner_curve)
    (Challenge)
    (Pickles.Endo.Step_inner_curve)
open Js_of_ocaml

let raise_errorf fmt =
  Core_kernel.ksprintf
    (fun s -> Js.raise_js_error (new%js Js.error_constr (Js.string s)))
    fmt

class type field_class =
  object
    method value : Impl.Field.t Js.prop

    method toString : Js.js_string Js.t Js.meth

    method toJSON : < .. > Js.t Js.meth

    method toFieldElements : field_class Js.t Js.js_array Js.t Js.meth
  end

and bool_class =
  object
    method value : Impl.Boolean.var Js.prop

    method toBoolean : bool Js.t Js.meth

    method toField : field_class Js.t Js.meth

    method toJSON : < .. > Js.t Js.meth

    method toFieldElements : field_class Js.t Js.js_array Js.t Js.meth
  end

module As_field = struct
  (* number | string | boolean | field_class | cvar *)
  type t

  open Impl

  let of_field (x : Field.t) : t = Obj.magic x

  let of_field_obj (x : field_class Js.t) : t = Obj.magic x

  let value (value : t) : Field.t =
    match Js.to_string (Js.typeof (Obj.magic value)) with
    | "number" ->
        let value = Js.float_of_number (Obj.magic value) in
        if Float.is_integer value then
          let value = Float.to_int value in
          if value >= 0 then Field.of_int value
          else Field.negate (Field.of_int (-value))
        else raise_errorf "Cannot convert a float to a field element"
    | "boolean" ->
        let value = Js.to_bool (Obj.magic value) in
        if value then Field.one else Field.zero
    | "string" -> (
        let value : Js.js_string Js.t = Obj.magic value in
        let s = Js.to_string value in
        try
          Field.constant
            ( if
              Char.equal s.[0] '0'
              && Char.equal (Char.lowercase_ascii s.[1]) 'x'
            then Zexe_backend.Pasta.Fp.(of_bigint (Bigint.of_hex_string s))
            else Field.Constant.of_string s )
        with Failure e -> raise_errorf "%s" e )
    | "object" ->
        let is_array = Js.to_bool (Js.Unsafe.global ##. Array##isArray value) in
        if is_array then
          (* Cvar case *)
          (* TODO: Check this works *)
          Obj.magic value
        else
          (* Object case *)
          Js.Optdef.get
            (Obj.magic value)##.value
            (fun () -> raise_errorf "Expected object with property \"value\"")
    | s ->
        raise_errorf "Type \"%s\" cannot be converted to a field element" s

  let field_class : < .. > Js.t =
    let f =
      (* We could construct this using Js.wrap_meth_callback, but that returns a
         function that behaves weirdly (from the point-of-view of JS) when partially applied. *)
      Js.Unsafe.eval_string
        {js|
        (function(asFieldValue) {
          return function(x) {
            this.value = asFieldValue(x);
            return this;
          };
        })
      |js}
    in
    Js.Unsafe.(fun_call f [| inject (Js.wrap_callback value) |])

  let field_constr : (t -> field_class Js.t) Js.constr = Obj.magic field_class

  let to_field_obj (x : t) : field_class Js.t =
    match Js.to_string (Js.typeof (Obj.magic value)) with
    | "object" ->
        let is_array = Js.to_bool (Js.Unsafe.global ##. Array##isArray value) in
        if is_array then (* Cvar case *)
          new%js field_constr x else Obj.magic x
    | _ ->
        new%js field_constr x
end

let field_class = As_field.field_class

let field_constr = As_field.field_constr

open Core_kernel

let bool_constant (b : Impl.Boolean.var) =
  match (b :> Impl.Field.t) with
  | Constant b ->
      Some Impl.Field.Constant.(equal one b)
  | _ ->
      None

module As_bool = struct
  (* boolean | bool_class | Boolean.var *)
  type t

  open Impl

  let of_boolean (x : Boolean.var) : t = Obj.magic x

  let of_bool_obj (x : bool_class Js.t) : t = Obj.magic x

  let of_js_bool (b : bool Js.t) : t = Obj.magic b

  let value (value : t) : Boolean.var =
    match Js.to_string (Js.typeof (Obj.magic value)) with
    | "boolean" ->
        let value = Js.to_bool (Obj.magic value) in
        Boolean.var_of_value value
    | "object" ->
        let is_array = Js.to_bool (Js.Unsafe.global ##. Array##isArray value) in
        if is_array then
          (* Cvar case *)
          (* TODO: Check this works *)
          Obj.magic value
        else
          (* Object case *)
          Js.Optdef.get
            (Obj.magic value)##.value
            (fun () -> raise_errorf "Expected object with property \"value\"")
    | s ->
        raise_errorf "Type \"%s\" cannot be converted to a boolean" s
end

let bool_class : < .. > Js.t =
  let f =
    Js.Unsafe.eval_string
      {js|
      (function(asBoolValue) {
        return function(x) {
          this.value = asBoolValue(x);
          return this;
        }
      })
    |js}
  in
  Js.Unsafe.(fun_call f [| inject (Js.wrap_callback As_bool.value) |])

let bool_constr : (As_bool.t -> bool_class Js.t) Js.constr =
  Obj.magic bool_class

(* TODO: Extend prototype for number to allow for field element methods *)

open Impl

let singleton_array (type a) (x : a) : a Js.js_array Js.t =
  let arr = new%js Js.array_empty in
  arr##push x |> ignore ;
  arr

let handle_constants f f_constant (x : Field.t) =
  match x with Constant x -> f_constant x | _ -> f x

let handle_constants2 f f_constant (x : Field.t) (y : Field.t) =
  match (x, y) with Constant x, Constant y -> f_constant x y | _ -> f x y

let array_get_exn xs i =
  Js.Optdef.get (Js.array_get xs i) (fun () ->
      raise_errorf "array_get_exn: index=%d, length=%d" i xs##.length)

let array_check_length xs n =
  if xs##.length <> n then raise_errorf "Expected array of length %d" n ()

let method_ class_ (name : string) (f : _ Js.t -> _) =
  let prototype = Js.Unsafe.get class_ (Js.string "prototype") in
  Js.Unsafe.set prototype (Js.string name) (Js.wrap_meth_callback f)

let optdef_arg_method (type a) class_ (name : string)
    (f : _ Js.t -> a Js.Optdef.t -> _) =
  let prototype = Js.Unsafe.get class_ (Js.string "prototype") in
  let meth =
    let wrapper =
      Js.Unsafe.eval_string
        {js|
        (function(f) {
          return function(xOptdef) {
            return f(this, xOptdef);
          };
        })|js}
    in
    Js.Unsafe.(fun_call wrapper [| inject (Js.wrap_callback f) |])
  in
  Js.Unsafe.set prototype (Js.string name) meth

let () =
  let method_ name (f : field_class Js.t -> _) = method_ field_class name f in
  let to_string (x : Field.t) =
    ( match x with
    | Constant x ->
        x
    | x ->
        (* TODO: Put good error message here. *)
        As_prover.read_var x )
    |> Field.Constant.to_string |> Js.string
  in
  let mk x : field_class Js.t = new%js field_constr (As_field.of_field x) in
  let add_op1 name (f : Field.t -> Field.t) =
    method_ name (fun this : field_class Js.t -> mk (f this##.value))
  in
  let add_op2 name (f : Field.t -> Field.t -> Field.t) =
    method_ name (fun this (y : As_field.t) : field_class Js.t ->
        mk (f this##.value (As_field.value y)))
  in
  let sub =
    handle_constants2 Field.sub (fun x y ->
        Field.constant (Field.Constant.sub x y))
  in
  let div =
    handle_constants2 Field.div (fun x y ->
        Field.constant (Field.Constant.( / ) x y))
  in
  let sqrt =
    handle_constants Field.sqrt (fun x ->
        Field.constant (Field.Constant.sqrt x))
  in
  add_op2 "add" Field.add ;
  add_op2 "sub" sub ;
  add_op2 "div" div ;
  add_op2 "mul" Field.mul ;
  add_op1 "neg" Field.negate ;
  add_op1 "inv" Field.inv ;
  add_op1 "square" Field.square ;
  add_op1 "sqrt" sqrt ;
  method_ "toString" (fun this : Js.js_string Js.t -> to_string this##.value) ;
  method_ "sizeInFieldElements" (fun _this : int -> 1) ;
  method_ "toFieldElements" (fun this : field_class Js.t Js.js_array Js.t ->
      singleton_array this) ;
  ((* TODO: Make this work with arbitrary bit length *)
   let bit_length = Field.size_in_bits - 2 in
   let cmp_method (name, f) =
     method_ name (fun this (y : As_field.t) : unit ->
         f ~bit_length this##.value (As_field.value y))
   in
   let bool_cmp_method (name, f) =
     method_ name (fun this (y : As_field.t) : bool_class Js.t ->
         new%js bool_constr
           (As_bool.of_boolean
              (f (Field.compare ~bit_length this##.value (As_field.value y)))))
   in
   (List.iter ~f:bool_cmp_method)
     [ ("lt", fun { less; _ } -> less)
     ; ("lte", fun { less_or_equal; _ } -> less_or_equal)
     ; ("gt", fun { less_or_equal; _ } -> Boolean.not less_or_equal)
     ; ("gte", fun { less; _ } -> Boolean.not less)
     ] ;
   let open Field.Assert in
   List.iter ~f:cmp_method
     [ ("assertLt", lt)
     ; ("assertLte", lte)
     ; ("assertGt", gt)
     ; ("assertGte", gte)
     ]) ;
  method_ "assertEquals" (fun this (y : As_field.t) : unit ->
      Field.Assert.equal this##.value (As_field.value y)) ;
  method_ "assertBoolean" (fun this : unit ->
      assert_ (Constraint.boolean this##.value)) ;
  method_ "isZero" (fun this : bool_class Js.t ->
      new%js bool_constr
        (As_bool.of_boolean (Field.equal this##.value Field.zero))) ;
  optdef_arg_method field_class "toBits"
    (fun this (length : int Js.Optdef.t) : bool_class Js.t Js.js_array Js.t ->
      let length = Js.Optdef.get length (fun () -> Field.size_in_bits) in
      let k f bits =
        let arr = new%js Js.array_empty in
        List.iter bits ~f:(fun x ->
            arr##push (new%js bool_constr (As_bool.of_boolean (f x))) |> ignore) ;
        arr
      in
      handle_constants
        (fun v -> k Fn.id (Field.choose_preimage_var ~length v))
        (fun x ->
          let bits = Field.Constant.unpack x in
          let bits, high_bits = List.split_n bits length in
          if List.exists high_bits ~f:Fn.id then
            raise_errorf "Value %s did not fit in %d bits"
              (Field.Constant.to_string x)
              length ;
          k Boolean.var_of_value bits)
        this##.value) ;
  method_ "equals" (fun this (y : As_field.t) : bool_class Js.t ->
      new%js bool_constr
        (As_bool.of_boolean (Field.equal this##.value (As_field.value y)))) ;
  let static_op1 name (f : Field.t -> Field.t) =
    Js.Unsafe.set field_class (Js.string name)
      (Js.wrap_callback (fun (x : As_field.t) : field_class Js.t ->
           mk (f (As_field.value x))))
  in
  let static_op2 name (f : Field.t -> Field.t -> Field.t) =
    Js.Unsafe.set field_class (Js.string name)
      (Js.wrap_callback
         (fun (x : As_field.t) (y : As_field.t) : field_class Js.t ->
           mk (f (As_field.value x) (As_field.value y))))
  in
  field_class##.one := mk Field.one ;
  field_class##.zero := mk Field.zero ;
  field_class##.random :=
    Js.wrap_callback (fun () : field_class Js.t ->
        mk (Field.constant (Field.Constant.random ()))) ;
  static_op2 "add" Field.add ;
  static_op2 "sub" sub ;
  static_op2 "mul" Field.mul ;
  static_op2 "div" div ;
  static_op1 "neg" Field.negate ;
  static_op1 "inv" Field.inv ;
  static_op1 "square" Field.square ;
  static_op1 "sqrt" sqrt ;
  field_class##.toString :=
    Js.wrap_callback (fun (x : As_field.t) : Js.js_string Js.t ->
        to_string (As_field.value x)) ;
  field_class##.sizeInFieldElements := Js.wrap_callback (fun () : int -> 1) ;
  field_class##.toFieldElements
  := Js.wrap_callback
       (fun (x : As_field.t) : field_class Js.t Js.js_array Js.t ->
         (As_field.to_field_obj x)##toFieldElements) ;
  field_class##.ofFieldElements
  := Js.wrap_callback
       (fun (xs : field_class Js.t Js.js_array Js.t) : field_class Js.t ->
         array_check_length xs 1 ; array_get_exn xs 0) ;
  field_class##.assertEqual :=
    Js.wrap_callback (fun (x : As_field.t) (y : As_field.t) : unit ->
        Field.Assert.equal (As_field.value x) (As_field.value y)) ;
  field_class##.assertBoolean
  := Js.wrap_callback (fun (x : As_field.t) : unit ->
         assert_ (Constraint.boolean (As_field.value x))) ;
  field_class##.isZero :=
    Js.wrap_callback (fun (x : As_field.t) : bool_class Js.t ->
        new%js bool_constr
          (As_bool.of_boolean (Field.equal (As_field.value x) Field.zero))) ;
  field_class##.ofBits :=
    Js.wrap_callback
      (fun (bs : As_bool.t Js.js_array Js.t) : field_class Js.t ->
        try
          Array.map (Js.to_array bs) ~f:(fun b ->
              match (As_bool.value b :> Impl.Field.t) with
              | Constant b ->
                  Impl.Field.Constant.(equal one b)
              | _ ->
                  failwith "non-constant")
          |> Array.to_list |> Field.Constant.project |> Field.constant |> mk
        with _ ->
          mk
            (Field.pack
               (List.init bs##.length ~f:(fun i ->
                    Js.Optdef.case (Js.array_get bs i)
                      (fun () -> assert false)
                      As_bool.value)))) ;
  (field_class##.toBits :=
     let wrapper =
       Js.Unsafe.eval_string
         {js|
          (function(toField) {
            return function(x, length) {
              return toField(x).toBits(length);
            };
          })|js}
     in
     Js.Unsafe.(
       fun_call wrapper [| inject (Js.wrap_callback As_field.to_field_obj) |])) ;
  field_class##.equal :=
    Js.wrap_callback (fun (x : As_field.t) (y : As_field.t) : bool_class Js.t ->
        new%js bool_constr
          (As_bool.of_boolean
             (Field.equal (As_field.value x) (As_field.value y)))) ;
  let static_method name f =
    Js.Unsafe.set field_class (Js.string name) (Js.wrap_callback f)
  in
  static_method "toConstant"
    (fun (this : field_class Js.t) : field_class Js.t ->
      let x =
        match this##.value with Constant x -> x | x -> As_prover.read_var x
      in
      mk (Field.constant x)) ;
  method_ "toJSON" (fun (this : field_class Js.t) : < .. > Js.t ->
      this##toString) ;
  static_method "toJSON" (fun (this : field_class Js.t) : < .. > Js.t ->
      this##toJSON) ;
  static_method "fromJSON"
    (fun (value : Js.Unsafe.any) : field_class Js.t Js.Opt.t ->
      let return x =
        Js.Opt.return (new%js field_constr (As_field.of_field x))
      in
      match Js.to_string (Js.typeof (Js.Unsafe.coerce value)) with
      | "number" ->
          let value = Js.float_of_number (Obj.magic value) in
          if Caml.Float.is_integer value then
            return (Field.of_int (Float.to_int value))
          else Js.Opt.empty
      | "boolean" ->
          let value = Js.to_bool (Obj.magic value) in
          return (if value then Field.one else Field.zero)
      | "string" -> (
          let value : Js.js_string Js.t = Obj.magic value in
          let s = Js.to_string value in
          try
            return
              (Field.constant
                 ( if
                   Char.equal s.[0] '0' && Char.equal (Char.lowercase s.[1]) 'x'
                 then Zexe_backend.Pasta.Fp.(of_bigint (Bigint.of_hex_string s))
                 else Field.Constant.of_string s ))
          with Failure _ -> Js.Opt.empty )
      | _ ->
          Js.Opt.empty)

let () =
  let handle_constants2 f f_constant (x : Boolean.var) (y : Boolean.var) =
    match ((x :> Field.t), (y :> Field.t)) with
    | Constant x, Constant y ->
        f_constant x y
    | _ ->
        f x y
  in
  let equal =
    handle_constants2 Boolean.equal (fun x y ->
        Boolean.var_of_value (Field.Constant.equal x y))
  in
  let mk x : bool_class Js.t = new%js bool_constr (As_bool.of_boolean x) in
  let method_ name (f : bool_class Js.t -> _) = method_ bool_class name f in
  let add_op1 name (f : Boolean.var -> Boolean.var) =
    method_ name (fun this : bool_class Js.t -> mk (f this##.value))
  in
  let add_op2 name (f : Boolean.var -> Boolean.var -> Boolean.var) =
    method_ name (fun this (y : As_bool.t) : bool_class Js.t ->
        mk (f this##.value (As_bool.value y)))
  in
  method_ "toField" (fun this : field_class Js.t ->
      new%js field_constr (As_field.of_field (this##.value :> Field.t))) ;
  add_op1 "not" Boolean.not ;
  add_op2 "and" Boolean.( &&& ) ;
  add_op2 "or" Boolean.( ||| ) ;
  method_ "assertEquals" (fun this (y : As_bool.t) : unit ->
      Boolean.Assert.( = ) this##.value (As_bool.value y)) ;
  add_op2 "equals" equal ;
  add_op1 "isTrue" Fn.id ;
  add_op1 "isFalse" Boolean.not ;
  method_ "toBoolean" (fun this : bool Js.t ->
      match (this##.value :> Field.t) with
      | Constant x ->
          Js.bool Field.Constant.(equal one x)
      | _ -> (
          try Js.bool (As_prover.read Boolean.typ this##.value)
          with _ ->
            raise_errorf
              "Bool.toBoolean can only be called on non-witness values." )) ;
  method_ "sizeInFieldElements" (fun _this : int -> 1) ;
  method_ "toString" (fun this ->
      let x =
        match (this##.value :> Field.t) with
        | Constant x ->
            x
        | x ->
            As_prover.read_var x
      in
      if Field.Constant.(equal one) x then "true" else "false") ;
  method_ "toFieldElements" (fun this : field_class Js.t Js.js_array Js.t ->
      let arr = new%js Js.array_empty in
      arr##push this##toField |> ignore ;
      arr) ;
  let static_method name f =
    Js.Unsafe.set bool_class (Js.string name) (Js.wrap_callback f)
  in
  let static_op1 name (f : Boolean.var -> Boolean.var) =
    static_method name (fun (x : As_bool.t) : bool_class Js.t ->
        mk (f (As_bool.value x)))
  in
  let static_op2 name (f : Boolean.var -> Boolean.var -> Boolean.var) =
    static_method name (fun (x : As_bool.t) (y : As_bool.t) : bool_class Js.t ->
        mk (f (As_bool.value x) (As_bool.value y)))
  in
  static_method "toField" (fun (x : As_bool.t) ->
      new%js field_constr (As_field.of_field (As_bool.value x :> Field.t))) ;
  Js.Unsafe.set bool_class (Js.string "Unsafe")
    (object%js
       method ofField (x : As_field.t) : bool_class Js.t =
         new%js bool_constr
           (As_bool.of_boolean (Boolean.Unsafe.of_cvar (As_field.value x)))
    end) ;
  static_op1 "not" Boolean.not ;
  static_op2 "and" Boolean.( &&& ) ;
  static_op2 "or" Boolean.( ||| ) ;
  static_method "assertEqual" (fun (x : As_bool.t) (y : As_bool.t) : unit ->
      Boolean.Assert.( = ) (As_bool.value x) (As_bool.value y)) ;
  static_op2 "equal" equal ;
  static_op1 "isTrue" Fn.id ;
  static_op1 "isFalse" Boolean.not ;
  static_method "count"
    (fun (bs : As_bool.t Js.js_array Js.t) : field_class Js.t ->
      new%js field_constr
        (As_field.of_field
           (Field.sum
              (List.init bs##.length ~f:(fun i ->
                   ( Js.Optdef.case (Js.array_get bs i)
                       (fun () -> assert false)
                       As_bool.value
                     :> Field.t )))))) ;
  static_method "sizeInFieldElements" (fun () : int -> 1) ;
  static_method "toFieldElements"
    (fun (x : As_bool.t) : field_class Js.t Js.js_array Js.t ->
      singleton_array
        (new%js field_constr (As_field.of_field (As_bool.value x :> Field.t)))) ;
  static_method "ofFieldElements"
    (fun (xs : field_class Js.t Js.js_array Js.t) : bool_class Js.t ->
      if xs##.length = 1 then
        Js.Optdef.case (Js.array_get xs 0)
          (fun () -> assert false)
          (fun x -> mk (Boolean.Unsafe.of_cvar x##.value))
      else raise_errorf "Expected array of length 1") ;
  static_method "check" (fun (x : bool_class Js.t) : unit ->
      assert_ (Constraint.boolean (x##.value :> Field.t))) ;
  method_ "toJSON" (fun (this : bool_class Js.t) : < .. > Js.t ->
      Js.Unsafe.coerce this##toBoolean) ;
  static_method "toJSON" (fun (this : bool_class Js.t) : < .. > Js.t ->
      this##toJSON) ;
  static_method "fromJSON"
    (fun (value : Js.Unsafe.any) : bool_class Js.t Js.Opt.t ->
      match Js.to_string (Js.typeof (Js.Unsafe.coerce value)) with
      | "boolean" ->
          Js.Opt.return
            (new%js bool_constr (As_bool.of_js_bool (Js.Unsafe.coerce value)))
      | _ ->
          Js.Opt.empty)

type coords = < x : As_field.t Js.prop ; y : As_field.t Js.prop > Js.t

let group_class : < .. > Js.t =
  let f =
    Js.Unsafe.eval_string
      {js|
      (function(toFieldObj) {
        return function() {
          var err = 'Group constructor expects either 2 arguments (x, y) or a single argument object { x, y }';
          if (arguments.length == 1) {
            var t = arguments[0];
            if (t.x === undefined || t.y === undefined) {
              throw (Error(err));
            } else {
              this.x = toFieldObj(t.x);
              this.y = toFieldObj(t.y);
            }
          } else if (arguments.length == 2) {
            this.x = toFieldObj(arguments[0]);
            this.y = toFieldObj(arguments[1]);
          } else {
            throw (Error(err));
          }
          return this;
        }
      })
      |js}
  in
  Js.Unsafe.fun_call f
    [| Js.Unsafe.inject (Js.wrap_callback As_field.to_field_obj) |]

class type scalar_class =
  object
    method value : Boolean.var array Js.prop

    method constantValue : Other_impl.Field.Constant.t Js.Optdef.t Js.prop

    method toJSON : < .. > Js.t Js.meth
  end

class type endo_scalar_class =
  object
    method value : Boolean.var list Js.prop
  end

module As_group = struct
  (* { x: as_field, y : as_field } | group_class *)
  type t

  class type group_class =
    object
      method x : field_class Js.t Js.prop

      method y : field_class Js.t Js.prop

      method add : group_class Js.t -> group_class Js.t Js.meth

      method add_ : t -> group_class Js.t Js.meth

      method sub_ : t -> group_class Js.t Js.meth

      method neg : group_class Js.t Js.meth

      method scale : scalar_class Js.t -> group_class Js.t Js.meth

      method endoScale : endo_scalar_class Js.t -> group_class Js.t Js.meth

      method assertEquals : t -> unit Js.meth

      method equals : t -> bool_class Js.t Js.meth

      method toJSON : < .. > Js.t Js.meth

      method toFieldElements : field_class Js.t Js.js_array Js.t Js.meth
    end

  let group_constr : (As_field.t -> As_field.t -> group_class Js.t) Js.constr =
    Obj.magic group_class

  let to_coords (t : t) : coords = Obj.magic t

  let value (t : t) =
    let t = to_coords t in
    (As_field.value t##.x, As_field.value t##.y)

  let of_group_obj (t : group_class Js.t) : t = Obj.magic t

  let to_group_obj (t : t) : group_class Js.t =
    if Js.instanceof (Obj.magic t) group_constr then Obj.magic t
    else
      let t = to_coords t in
      new%js group_constr t##.x t##.y
end

class type group_class = As_group.group_class

let group_constr = As_group.group_constr

let scalar_shift =
  Pickles_types.Shifted_value.Shift.create (module Other_backend.Field)

let to_constant_scalar (bs : Boolean.var array) :
    Other_backend.Field.t Js.Optdef.t =
  with_return (fun { return } ->
      let bs =
        Array.map bs ~f:(fun b ->
            match (b :> Field.t) with
            | Constant b ->
                Impl.Field.Constant.(equal one b)
            | _ ->
                return Js.Optdef.empty)
      in
      Js.Optdef.return
        (Pickles_types.Shifted_value.to_field
           (module Other_backend.Field)
           ~shift:scalar_shift
           (Shifted_value (Other_backend.Field.of_bits (Array.to_list bs)))))

let scalar_class : < .. > Js.t =
  let f =
    Js.Unsafe.eval_string
      {js|
      (function(toConstantFieldElt) {
        return function(bits, constantValue) {
          this.value = bits;
          if (constantValue !== undefined) {
            this.constantValue = constantValue;
            return this;
          }
          let c = toConstantFieldElt(bits);
          if (c !== undefined) {
            this.constantValue = c;
          }
          return this;
        };
      })
    |js}
  in
  Js.Unsafe.(fun_call f [| inject (Js.wrap_callback to_constant_scalar) |])

let scalar_constr : (Boolean.var array -> scalar_class Js.t) Js.constr =
  Obj.magic scalar_class

let scalar_constr_const :
    (Boolean.var array -> Other_backend.Field.t -> scalar_class Js.t) Js.constr
    =
  Obj.magic scalar_class

let () =
  let num_bits = Field.size_in_bits in
  let method_ name (f : scalar_class Js.t -> _) = method_ scalar_class name f in
  let static_method name f =
    Js.Unsafe.set scalar_class (Js.string name) (Js.wrap_callback f)
  in
  let ( ! ) name x =
    Js.Optdef.get x (fun () ->
        raise_errorf "Scalar.%s can only be called on non-witness values." name)
  in
  let bits x =
    let (Shifted_value x) =
      Pickles_types.Shifted_value.of_field ~shift:scalar_shift
        (module Other_backend.Field)
        x
    in
    Array.of_list_map (Other_backend.Field.to_bits x) ~f:Boolean.var_of_value
  in
  let constant_op1 name (f : Other_backend.Field.t -> Other_backend.Field.t) =
    method_ name (fun x : scalar_class Js.t ->
        let z = f (!name x##.constantValue) in
        new%js scalar_constr_const (bits z) z)
  in
  let constant_op2 name
      (f :
        Other_backend.Field.t -> Other_backend.Field.t -> Other_backend.Field.t)
      =
    let ( ! ) = !name in
    method_ name (fun x (y : scalar_class Js.t) : scalar_class Js.t ->
        let z = f !(x##.constantValue) !(y##.constantValue) in
        new%js scalar_constr_const (bits z) z)
  in

  (* It is not necessary to boolean constrain the bits of a scalar for the following
     reasons:

     The only type-safe functions which can be called with a scalar value are

     - if
     - assertEqual
     - equal
     - Group.scale

     The only one of these whose behavior depends on the bit values of the input scalars
     is Group.scale, and that function boolean constrains the scalar input itself.
  *)
  constant_op1 "neg" Other_backend.Field.negate ;
  constant_op2 "add" Other_backend.Field.add ;
  constant_op2 "mul" Other_backend.Field.mul ;
  constant_op2 "sub" Other_backend.Field.sub ;
  constant_op2 "div" Other_backend.Field.div ;
  method_ "toFieldElements" (fun x : field_class Js.t Js.js_array Js.t ->
      Array.map x##.value ~f:(fun b ->
          new%js field_constr (As_field.of_field (b :> Field.t)))
      |> Js.array) ;
  static_method "toFieldElements"
    (fun (x : scalar_class Js.t) : field_class Js.t Js.js_array Js.t ->
      (Js.Unsafe.coerce x)##toFieldElements) ;
  static_method "sizeInFieldElements" (fun () : int -> num_bits) ;
  static_method "ofFieldElements"
    (fun (xs : field_class Js.t Js.js_array Js.t) : scalar_class Js.t ->
      new%js scalar_constr
        (Array.map (Js.to_array xs) ~f:(fun x ->
             Boolean.Unsafe.of_cvar x##.value))) ;
  static_method "random" (fun () : scalar_class Js.t ->
      let x = Other_backend.Field.random () in
      new%js scalar_constr_const (bits x) x) ;
  static_method "ofBits"
    (fun (bits : bool_class Js.t Js.js_array Js.t) : scalar_class Js.t ->
      new%js scalar_constr
        (Array.map (Js.to_array bits) ~f:(fun b ->
             As_bool.(value (of_bool_obj b))))) ;
  method_ "toJSON" (fun (s : scalar_class Js.t) : < .. > Js.t ->
      let s =
        Js.Optdef.case s##.constantValue
          (fun () ->
            Js.Optdef.get
              (to_constant_scalar s##.value)
              (fun () -> raise_errorf "Cannot convert in-circuit value to JSON"))
          Fn.id
      in
      Js.string (Other_impl.Field.Constant.to_string s)) ;
  static_method "toJSON" (fun (s : scalar_class Js.t) : < .. > Js.t ->
      s##toJSON) ;
  static_method "fromJSON"
    (fun (value : Js.Unsafe.any) : scalar_class Js.t Js.Opt.t ->
      let return x = Js.Opt.return (new%js scalar_constr_const (bits x) x) in
      match Js.to_string (Js.typeof (Js.Unsafe.coerce value)) with
      | "number" ->
          let value = Js.float_of_number (Obj.magic value) in
          if Caml.Float.is_integer value then
            return (Other_backend.Field.of_int (Float.to_int value))
          else Js.Opt.empty
      | "boolean" ->
          let value = Js.to_bool (Obj.magic value) in
          return Other_backend.(if value then Field.one else Field.zero)
      | "string" -> (
          let value : Js.js_string Js.t = Obj.magic value in
          let s = Js.to_string value in
          try
            return
              ( if Char.equal s.[0] '0' && Char.equal (Char.lowercase s.[1]) 'x'
              then Zexe_backend.Pasta.Fq.(of_bigint (Bigint.of_hex_string s))
              else Other_impl.Field.Constant.of_string s )
          with Failure _ -> Js.Opt.empty )
      | _ ->
          Js.Opt.empty)

let () =
  let mk (x, y) : group_class Js.t =
    new%js group_constr (As_field.of_field x) (As_field.of_field y)
  in
  let method_ name (f : group_class Js.t -> _) = method_ group_class name f in
  let static name x = Js.Unsafe.set group_class (Js.string name) x in
  let static_method name f = static name (Js.wrap_callback f) in
  let constant (x, y) = mk Field.(constant x, constant y) in
  method_ "add"
    (fun (p1 : group_class Js.t) (p2 : As_group.t) : group_class Js.t ->
      let p1, p2 =
        (As_group.value (As_group.of_group_obj p1), As_group.value p2)
      in
      let open Pickles.Step_main_inputs in
      match (p1, p2) with
      | (Constant x1, Constant y1), (Constant x2, Constant y2) ->
          constant (Inner_curve.Constant.( + ) (x1, y1) (x2, y2))
      | _ ->
          (* TODO: Make this handle the edge cases *)
          Ops.add_fast p1 p2 |> mk) ;
  method_ "neg" (fun (p1 : group_class Js.t) : group_class Js.t ->
      Pickles.Step_main_inputs.Inner_curve.negate
        (As_group.value (As_group.of_group_obj p1))
      |> mk) ;
  method_ "sub"
    (fun (p1 : group_class Js.t) (p2 : As_group.t) : group_class Js.t ->
      p1##add (As_group.to_group_obj p2)##neg) ;
  method_ "scale"
    (fun (p1 : group_class Js.t) (s : scalar_class Js.t) : group_class Js.t ->
      let open Pickles.Step_main_inputs in
      match
        ( As_group.(value (of_group_obj p1))
        , Js.Optdef.to_option s##.constantValue )
      with
      | (Constant x, Constant y), Some s ->
          Inner_curve.Constant.scale (x, y) s |> constant
      | _ ->
          Ops.scale_fast
            (As_group.value (As_group.of_group_obj p1))
            (`Plus_two_to_len s##.value)
          |> mk) ;
  method_ "endoScale"
    (fun (p1 : group_class Js.t) (s : endo_scalar_class Js.t) : group_class Js.t
    ->
      Sc.endo
        (As_group.value (As_group.of_group_obj p1))
        (Scalar_challenge s##.value)
      |> mk) ;
  method_ "assertEquals"
    (fun (p1 : group_class Js.t) (p2 : As_group.t) : unit ->
      let x1, y1 = As_group.value (As_group.of_group_obj p1) in
      let x2, y2 = As_group.value p2 in
      Field.Assert.equal x1 x2 ; Field.Assert.equal y1 y2) ;
  method_ "equals"
    (fun (p1 : group_class Js.t) (p2 : As_group.t) : bool_class Js.t ->
      let x1, y1 = As_group.value (As_group.of_group_obj p1) in
      let x2, y2 = As_group.value p2 in
      new%js bool_constr
        (As_bool.of_boolean
           (Boolean.all [ Field.equal x1 x2; Field.equal y1 y2 ]))) ;
  static "generator"
    (mk Pickles.Step_main_inputs.Inner_curve.one : group_class Js.t) ;
  static_method "add"
    (fun (p1 : As_group.t) (p2 : As_group.t) : group_class Js.t ->
      (As_group.to_group_obj p1)##add_ p2) ;
  static_method "sub"
    (fun (p1 : As_group.t) (p2 : As_group.t) : group_class Js.t ->
      (As_group.to_group_obj p1)##sub_ p2) ;
  static_method "sub"
    (fun (p1 : As_group.t) (p2 : As_group.t) : group_class Js.t ->
      (As_group.to_group_obj p1)##sub_ p2) ;
  static_method "neg" (fun (p1 : As_group.t) : group_class Js.t ->
      (As_group.to_group_obj p1)##neg) ;
  static_method "scale"
    (fun (p1 : As_group.t) (s : scalar_class Js.t) : group_class Js.t ->
      (As_group.to_group_obj p1)##scale s) ;
  static_method "assertEqual" (fun (p1 : As_group.t) (p2 : As_group.t) : unit ->
      (As_group.to_group_obj p1)##assertEquals p2) ;
  static_method "equal"
    (fun (p1 : As_group.t) (p2 : As_group.t) : bool_class Js.t ->
      (As_group.to_group_obj p1)##equals p2) ;
  method_ "toFieldElements"
    (fun (p1 : group_class Js.t) : field_class Js.t Js.js_array Js.t ->
      let arr = singleton_array p1##.x in
      arr##push p1##.y |> ignore ;
      arr) ;
  static_method "toFieldElements" (fun (p1 : group_class Js.t) ->
      p1##toFieldElements) ;
  static_method "ofFieldElements"
    (fun (xs : field_class Js.t Js.js_array Js.t) ->
      array_check_length xs 2 ;
      new%js group_constr
        (As_field.of_field_obj (array_get_exn xs 0))
        (As_field.of_field_obj (array_get_exn xs 1))) ;
  static_method "sizeInFieldElements" (fun () : int -> 2) ;
  static_method "check" (fun (p : group_class Js.t) : unit ->
      let open Pickles.Step_main_inputs in
      Inner_curve.assert_on_curve
        Field.((p##.x##.value :> t), (p##.y##.value :> t))) ;
  method_ "toJSON" (fun (p : group_class Js.t) : < .. > Js.t ->
      object%js
        val x = (Obj.magic field_class)##toJSON p##.x

        val y = (Obj.magic field_class)##toJSON p##.y
      end) ;
  static_method "toJSON" (fun (p : group_class Js.t) : < .. > Js.t -> p##toJSON) ;
  static_method "fromJSON"
    (fun (value : Js.Unsafe.any) : group_class Js.t Js.Opt.t ->
      let get field_name =
        Js.Optdef.case
          (Js.Unsafe.get value (Js.string field_name))
          (fun () -> Js.Opt.empty)
          (fun x -> field_class##fromJSON x)
      in
      Js.Opt.bind (get "x") (fun x ->
          Js.Opt.map (get "y") (fun y ->
              new%js group_constr
                (As_field.of_field_obj x) (As_field.of_field_obj y))))

let poseidon =
  object%js
    method hash (xs : field_class Js.t Js.js_array Js.t) : field_class Js.t =
      let open Pickles.Step_main_inputs in
      let s = Sponge.create sponge_params in
      for i = 0 to xs##.length - 1 do
        Sponge.absorb s (`Field (array_get_exn xs i)##.value)
      done ;
      new%js field_constr (As_field.of_field (Sponge.squeeze_field s))
  end

class type ['a] as_field_elements =
  object
    method toFieldElements : 'a -> field_class Js.t Js.js_array Js.t Js.meth

    method ofFieldElements : field_class Js.t Js.js_array Js.t -> 'a Js.meth

    method sizeInFieldElements : int Js.meth
  end

let array_iter t1 ~f =
  for i = 0 to t1##.length - 1 do
    f (array_get_exn t1 i)
  done

let array_iter2 t1 t2 ~f =
  for i = 0 to t1##.length - 1 do
    f (array_get_exn t1 i) (array_get_exn t2 i)
  done

let array_map t1 ~f =
  let res = new%js Js.array_empty in
  array_iter t1 ~f:(fun x1 -> res##push (f x1) |> ignore) ;
  res

let array_map2 t1 t2 ~f =
  let res = new%js Js.array_empty in
  array_iter2 t1 t2 ~f:(fun x1 x2 -> res##push (f x1 x2) |> ignore) ;
  res

class type verification_key_class =
  object
    method value : Verification_key.t Js.prop

    method verify :
      Js.Unsafe.any Js.js_array Js.t -> proof_class Js.t -> bool Js.t Js.meth
  end

and proof_class =
  object
    method value : Backend.Proof.t Js.prop
  end

class type keypair_class =
  object
    method value : Keypair.t Js.prop
  end

let keypair_class : < .. > Js.t =
  Js.Unsafe.eval_string {js|(function(v) { this.value = v; return this })|js}

let keypair_constr : (Keypair.t -> keypair_class Js.t) Js.constr =
  Obj.magic keypair_class

let verification_key_class : < .. > Js.t =
  Js.Unsafe.eval_string {js|(function(v) { this.value = v; return this })|js}

let verification_key_constr :
    (Verification_key.t -> verification_key_class Js.t) Js.constr =
  Obj.magic verification_key_class

let proof_class : < .. > Js.t =
  Js.Unsafe.eval_string {js|(function(v) { this.value = v; return this })|js}

let proof_constr : (Backend.Proof.t -> proof_class Js.t) Js.constr =
  Obj.magic proof_class

module Circuit = struct
  let check_lengths s t1 t2 =
    if t1##.length <> t2##.length then
      raise_errorf "%s: Got mismatched lengths, %d != %d" s t1##.length
        t2##.length
    else ()

  let wrap name ~pre_args ~post_args ~explicit ~implicit =
    let total_implicit = pre_args + post_args in
    let total_explicit = 1 + total_implicit in
    let wrapped =
      let err =
        if pre_args > 0 then
          sprintf
            "%s: Must be called with %d arguments, or, if passing constructor \
             explicitly, with %d arguments, followed by the constructor, \
             followed by %d arguments"
            name total_implicit pre_args post_args
        else
          sprintf
            "%s: Must be called with %d arguments, or, if passing constructor \
             explicitly, with the constructor as the first argument, followed \
             by %d arguments"
            name total_implicit post_args
      in
      ksprintf Js.Unsafe.eval_string
        {js|
        (function(explicit, implicit) {
          return function() {
            var err = '%s';
            if (arguments.length === %d) {
              return explicit.apply(this, arguments);
            } else if (arguments.length === %d) {
              return implicit.apply(this, arguments);
            } else {
              throw (Error(err));
            }
          }
        } )
      |js}
        err total_explicit total_implicit
    in
    Js.Unsafe.(
      fun_call wrapped
        [| inject (Js.wrap_callback explicit)
         ; inject (Js.wrap_callback implicit)
        |])

  let if_array b t1 t2 =
    check_lengths "if" t1 t2 ;
    array_map2 t1 t2 ~f:(fun x1 x2 ->
        new%js field_constr
          (As_field.of_field (Field.if_ b ~then_:x1##.value ~else_:x2##.value)))

  let js_equal (type b) (x : b) (y : b) : bool =
    let f = Js.Unsafe.eval_string "(function(x, y) { return x === y; })" in
    Js.to_bool Js.Unsafe.(fun_call f [| inject x; inject y |])

  let keys (type a) (a : a) : Js.js_string Js.t Js.js_array Js.t =
    Js.Unsafe.global ##. Object##keys a

  let check_type name t =
    let t = Js.to_string t in
    let ok =
      match t with
      | "object" ->
          true
      | "function" ->
          false
      | "number" ->
          false
      | "boolean" ->
          false
      | "string" ->
          false
      | _ ->
          false
    in
    if ok then ()
    else raise_errorf "Type \"%s\" cannot be used with function \"%s\"" t name

  let rec to_field_elts_magic :
      type a. a Js.t -> field_class Js.t Js.js_array Js.t =
    fun (type a) (t1 : a Js.t) : field_class Js.t Js.js_array Js.t ->
     let t1_is_array = Js.Unsafe.global ##. Array##isArray t1 in
     check_type "toFieldElements" (Js.typeof t1) ;
     match t1_is_array with
     | true ->
         let arr = array_map (Obj.magic t1) ~f:to_field_elts_magic in
         (Obj.magic arr)##flat
     | false -> (
         let ctor1 : _ Js.Optdef.t = (Obj.magic t1)##.constructor in
         let has_methods ctor =
           let has s = Js.to_bool (ctor##hasOwnProperty (Js.string s)) in
           has "toFieldElements" && has "ofFieldElements"
         in
         match Js.Optdef.(to_option ctor1) with
         | Some ctor1 when has_methods ctor1 ->
             ctor1##toFieldElements t1
         | Some _ ->
             let arr =
               array_map
                 (keys t1)##sort_asStrings
                 ~f:(fun k -> to_field_elts_magic (Js.Unsafe.get t1 k))
             in
             (Obj.magic arr)##flat
         | None ->
             raise_errorf
               "toFieldElements: Argument did not have a constructor." )

  let assert_equal =
    let f t1 t2 =
      (* TODO: Have better error handling here that throws at proving time
         for the specific position where they differ. *)
      check_lengths "assertEqual" t1 t2 ;
      for i = 0 to t1##.length - 1 do
        Field.Assert.equal
          (array_get_exn t1 i)##.value
          (array_get_exn t2 i)##.value
      done
    in
    let implicit
        (t1 :
          < toFieldElements : field_class Js.t Js.js_array Js.t Js.meth > Js.t
          as
          'a) (t2 : 'a) : unit =
      f (to_field_elts_magic t1) (to_field_elts_magic t2)
    in
    let explicit
        (ctor :
          < toFieldElements : 'a -> field_class Js.t Js.js_array Js.t Js.meth >
          Js.t) (t1 : 'a) (t2 : 'a) : unit =
      f (ctor##toFieldElements t1) (ctor##toFieldElements t2)
    in
    wrap "assertEqual" ~pre_args:0 ~post_args:2 ~explicit ~implicit

  let equal =
    let f t1 t2 =
      check_lengths "equal" t1 t2 ;
      (* TODO: Have better error handling here that throws at proving time
         for the specific position where they differ. *)
      new%js bool_constr
        ( Boolean.Array.all
            (Array.init t1##.length ~f:(fun i ->
                 Field.equal
                   (array_get_exn t1 i)##.value
                   (array_get_exn t2 i)##.value))
        |> As_bool.of_boolean )
    in
    let _implicit
        (t1 :
          < toFieldElements : field_class Js.t Js.js_array Js.t Js.meth > Js.t
          as
          'a) (t2 : 'a) : bool_class Js.t =
      f t1##toFieldElements t2##toFieldElements
    in
    let implicit t1 t2 = f (to_field_elts_magic t1) (to_field_elts_magic t2) in
    let explicit
        (ctor :
          < toFieldElements : 'a -> field_class Js.t Js.js_array Js.t Js.meth >
          Js.t) (t1 : 'a) (t2 : 'a) : bool_class Js.t =
      f (ctor##toFieldElements t1) (ctor##toFieldElements t2)
    in
    wrap "equal" ~pre_args:0 ~post_args:2 ~explicit ~implicit

  let if_explicit (type a) (b : As_bool.t) (ctor : a as_field_elements Js.t)
      (x1 : a) (x2 : a) =
    let b = As_bool.value b in
    match (b :> Field.t) with
    | Constant b ->
        if Field.Constant.(equal one b) then x1 else x2
    | _ ->
        let t1 = ctor##toFieldElements x1 in
        let t2 = ctor##toFieldElements x2 in
        let arr = if_array b t1 t2 in
        ctor##ofFieldElements arr

  let rec if_magic : type a. As_bool.t -> a Js.t -> a Js.t -> a Js.t =
    fun (type a) (b : As_bool.t) (t1 : a Js.t) (t2 : a Js.t) : a Js.t ->
     check_type "if" (Js.typeof t1) ;
     check_type "if" (Js.typeof t2) ;
     let t1_is_array = Js.Unsafe.global ##. Array##isArray t1 in
     let t2_is_array = Js.Unsafe.global ##. Array##isArray t2 in
     match (t1_is_array, t2_is_array) with
     | false, true | true, false ->
         raise_errorf "if: Mismatched argument types"
     | true, true ->
         array_map2 (Obj.magic t1) (Obj.magic t2) ~f:(fun x1 x2 ->
             if_magic b x1 x2)
         |> Obj.magic
     | false, false -> (
         let ctor1 : _ Js.Optdef.t = (Obj.magic t1)##.constructor in
         let ctor2 : _ Js.Optdef.t = (Obj.magic t2)##.constructor in
         let has_methods ctor =
           let has s = Js.to_bool (ctor##hasOwnProperty (Js.string s)) in
           has "toFieldElements" && has "ofFieldElements"
         in
         if not (js_equal ctor1 ctor2) then
           raise_errorf "if: Mismatched argument types" ;
         match Js.Optdef.(to_option ctor1, to_option ctor2) with
         | Some ctor1, Some _ when has_methods ctor1 ->
             if_explicit b ctor1 t1 t2
         | Some ctor1, Some _ ->
             (* Try to match them as generic objects *)
             let ks1 = (keys t1)##sort_asStrings in
             let ks2 = (keys t2)##sort_asStrings in
             check_lengths
               (sprintf "if (%s vs %s)"
                  (Js.to_string (ks1##join (Js.string ", ")))
                  (Js.to_string (ks2##join (Js.string ", "))))
               ks1 ks2 ;
             array_iter2 ks1 ks2 ~f:(fun k1 k2 ->
                 if not (js_equal k1 k2) then
                   raise_errorf "if: Arguments had mismatched types") ;
             let result = new%js ctor1 in
             array_iter ks1 ~f:(fun k ->
                 Js.Unsafe.set result k
                   (if_magic b (Js.Unsafe.get t1 k) (Js.Unsafe.get t2 k))) ;
             Obj.magic result
         | Some _, None | None, Some _ ->
             assert false
         | None, None ->
             raise_errorf "if: Arguments did not have a constructor." )

  let if_ =
    wrap "if" ~pre_args:1 ~post_args:2 ~explicit:if_explicit ~implicit:if_magic

  let typ_ (type a) (typ : a as_field_elements Js.t) : (a, a) Typ.t =
    let to_array conv a =
      Js.to_array (typ##toFieldElements a)
      |> Array.map ~f:(fun x -> conv x##.value)
    in
    let of_array conv xs =
      typ##ofFieldElements
        (Js.array
           (Array.map xs ~f:(fun x ->
                new%js field_constr (As_field.of_field (conv x)))))
    in
    Typ.transport
      (Typ.array ~length:typ##sizeInFieldElements Field.typ)
      ~there:(to_array (fun x -> Option.value_exn (Field.to_constant x)))
      ~back:(of_array Field.constant)
    |> Typ.transport_var ~there:(to_array Fn.id) ~back:(of_array Fn.id)

  let witness (type a) (typ : a as_field_elements Js.t)
      (f : (unit -> a) Js.callback) : a =
    let a =
      exists (typ_ typ) ~compute:(fun () : a -> Js.Unsafe.fun_call f [||])
    in
    if Js.Optdef.test (Js.Unsafe.coerce typ)##.check then
      (Js.Unsafe.coerce typ)##check a ;
    a

  module Circuit_main = struct
    type ('w, 'p) t =
      < snarkyMain : ('w -> 'p -> unit) Js.callback Js.prop
      ; snarkyWitnessTyp : 'w as_field_elements Js.t Js.prop
      ; snarkyPublicTyp : 'p as_field_elements Js.t Js.prop >
      Js.t
  end

  let main_and_input (type w p) (c : (w, p) Circuit_main.t) =
    let main ?(w : w option) (public : p) () =
      let w : w =
        witness c##.snarkyWitnessTyp
          (Js.wrap_callback (fun () -> Option.value_exn w))
      in
      Js.Unsafe.(fun_call c##.snarkyMain [| inject w; inject public |])
    in
    (main, Data_spec.[ typ_ c##.snarkyPublicTyp ])

  let generate_keypair (type w p) (c : (w, p) Circuit_main.t) :
      keypair_class Js.t =
    let main, spec = main_and_input c in
    new%js keypair_constr (generate_keypair ~exposing:spec (fun x -> main x))

  let prove (type w p) (c : (w, p) Circuit_main.t) (priv : w) (pub : p) kp :
      proof_class Js.t =
    let main, spec = main_and_input c in
    let pk = Keypair.pk kp in
    let p =
      generate_witness_conv
        ~f:(fun { Proof_inputs.auxiliary_inputs; public_inputs } ->
          Backend.Proof.create pk ~auxiliary:auxiliary_inputs
            ~primary:public_inputs)
        spec (main ~w:priv) () pub
    in
    new%js proof_constr p

  let circuit = Js.Unsafe.eval_string {js|(function() { return this })|js}

  let () =
    let array (type a) (typ : a as_field_elements Js.t) (length : int) :
        a Js.js_array Js.t as_field_elements Js.t =
      let elt_len = typ##sizeInFieldElements in
      let len = length * elt_len in
      object%js
        method sizeInFieldElements = len

        method toFieldElements (xs : a Js.js_array Js.t) =
          let res = new%js Js.array_empty in
          for i = 0 to xs##.length - 1 do
            let x = typ##toFieldElements (array_get_exn xs i) in
            for j = 0 to x##.length - 1 do
              res##push (array_get_exn x j) |> ignore
            done
          done ;
          res

        method ofFieldElements (xs : field_class Js.t Js.js_array Js.t) =
          let res = new%js Js.array_empty in
          for i = 0 to length - 1 do
            let a = new%js Js.array_empty in
            let offset = i * elt_len in
            for j = 0 to elt_len - 1 do
              a##push (array_get_exn xs (offset + j)) |> ignore
            done ;
            res##push (typ##ofFieldElements a) |> ignore
          done ;
          res
      end
    in
    circuit##.asProver :=
      Js.wrap_callback (fun (f : (unit -> unit) Js.callback) : unit ->
          as_prover (fun () -> Js.Unsafe.fun_call f [||])) ;
    circuit##.witness := Js.wrap_callback witness ;
    circuit##.array := Js.wrap_callback array ;
    circuit##.generateKeypair :=
      Js.wrap_meth_callback
        (fun (this : _ Circuit_main.t) : keypair_class Js.t ->
          generate_keypair this) ;
    circuit##.prove :=
      Js.wrap_meth_callback
        (fun (this : _ Circuit_main.t) w p (kp : keypair_class Js.t) ->
          prove this w p kp##.value) ;
    (circuit##.verify :=
       fun (pub : Js.Unsafe.any Js.js_array Js.t)
           (vk : verification_key_class Js.t) (pi : proof_class Js.t) :
           bool Js.t ->
         vk##verify pub pi) ;
    circuit##.assertEqual := assert_equal ;
    circuit##.equal := equal ;
    circuit##.toFieldElements := Js.wrap_callback to_field_elts_magic ;
    Js.Unsafe.set circuit (Js.string "if") if_
end

let () =
  let method_ name (f : keypair_class Js.t -> _) =
    method_ keypair_class name f
  in
  method_ "verificationKey"
    (fun (this : keypair_class Js.t) : verification_key_class Js.t ->
      new%js verification_key_constr (Keypair.vk this##.value))

let () =
  let method_ name (f : verification_key_class Js.t -> _) =
    method_ verification_key_class name f
  in
  method_ "verify"
    (fun
      (this : verification_key_class Js.t)
      (pub : Js.Unsafe.any Js.js_array Js.t)
      (pi : proof_class Js.t)
      :
      bool Js.t
    ->
      let open Backend.Field.Vector in
      let v = create () in
      array_iter (Circuit.to_field_elts_magic pub) ~f:(fun x ->
          match x##.value with
          | Constant x ->
              emplace_back v x
          | _ ->
              raise_errorf "verify: Expected non-circuit values for input") ;
      Backend.Proof.verify pi##.value this##.value v |> Js.bool)

let () =
  let method_ name (f : proof_class Js.t -> _) = method_ proof_class name f in
  method_ "verify"
    (fun
      (this : proof_class Js.t)
      (vk : verification_key_class Js.t)
      (pub : Js.Unsafe.any Js.js_array Js.t)
      :
      bool Js.t
    -> vk##verify pub this)

let export () =
  Js.export "Field" field_class ;
  Js.export "Scalar" scalar_class ;
  Js.export "Bool" bool_class ;
  Js.export "Group" group_class ;
  Js.export "Poseidon" poseidon ;
  Js.export "Circuit" Circuit.circuit

let export_global () =
  let snarky_obj =
    Js.Unsafe.(
      let i = inject in
      obj
        [| ("Field", i field_class)
         ; ("Scalar", i scalar_class)
         ; ("Bool", i bool_class)
         ; ("Group", i group_class)
         ; ("Poseidon", i poseidon)
         ; ("Circuit", i Circuit.circuit)
        |])
  in
  Js.Unsafe.(set global (Js.string "__snarky") snarky_obj)
