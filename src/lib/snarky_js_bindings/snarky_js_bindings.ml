module Backend = Zexe_backend_js.Pasta.Vesta_based_plonk

let () = Backend.Keypair.set_urs_info []

module Impl =
  Snarky_backendless.Snark.Run.Make
    (Zexe_backend_js.Pasta.Pallas_based_plonk)
    (Unit)
open Js_of_ocaml

module As_field = struct
  (* number | string | boolean | field_class | cvar *)
  type t

  open Impl

  let of_field (x : Field.t) : t = Obj.magic x

  let value (value : t) : Field.t =
    match Js.to_string (Js.typeof (Obj.magic value)) with
    | "number" ->
        let value = Js.float_of_number (Obj.magic value) in
        if Float.is_integer value then Field.of_int (Float.to_int value)
        else failwith "Cannot convert a float to a field element"
    | "boolean" ->
        let value = Js.to_bool (Obj.magic value) in
        if value then Field.one else Field.zero
    | "string" ->
        Field.constant
          (Field.Constant.of_string (Js.to_string (Obj.magic value)))
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
            (fun () -> failwith "Expected object with property \"value\"")
    | s ->
        Core_kernel.failwithf "Type %s cannot be converted to a field element" s
          ()
end

open Core_kernel

module As_bool = struct
  (* boolean | bool_class | Boolean.var *)
  type t

  open Impl

  let of_boolean (x : Boolean.var) : t = Obj.magic x

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
            (fun () -> failwith "Expected object with property \"value\"")
    | s ->
        Core_kernel.failwithf "Type %s cannot be converted to a field element" s
          ()
end

class type field_class =
  object
    method value : Impl.Field.t Js.prop
  end

class type bool_class =
  object
    method value : Impl.Boolean.var Js.prop

    method toField : field_class Js.t Js.meth
  end

let field_class : < .. > Js.t =
  Js.wrap_meth_callback (fun (this : field_class Js.t) (value : As_field.t) ->
      this##.value := As_field.value value ;
      this)
  |> Obj.magic

let bool_class =
  Js.wrap_meth_callback (fun (this : bool_class Js.t) (value : As_bool.t) ->
      this##.value := As_bool.value value)

let field_constr : (As_field.t -> field_class Js.t) Js.constr =
  Obj.magic field_class

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

let () =
  let add_method name (f : field_class Js.t -> _) =
    let prototype = Js.Unsafe.get field_class (Js.string "prototype") in
    Js.Unsafe.set prototype (Js.string name) (Js.wrap_meth_callback f)
  in
  let to_string (x : Field.t) =
    (match x with Constant x -> x | x -> As_prover.read_var x)
    |> Field.Constant.to_string |> Js.string
  in
  let mk x : field_class Js.t = new%js field_constr (As_field.of_field x) in
  let add_op1 name (f : Field.t -> Field.t) =
    add_method name (fun this : field_class Js.t -> mk (f this##.value))
  in
  let add_op2 name (f : Field.t -> Field.t -> Field.t) =
    add_method name (fun this (y : As_field.t) : field_class Js.t ->
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
  add_method "toString" (fun this : Js.js_string Js.t -> to_string this##.value) ;
  add_method "sizeInFieldElements" (fun _this : int -> 1) ;
  add_method "toFieldElements" (fun this : field_class Js.t Js.js_array Js.t ->
      singleton_array this) ;
  add_method "assertEqual" (fun this (y : As_field.t) : unit ->
      Field.Assert.equal this##.value (As_field.value y)) ;
  add_method "assertBoolean" (fun this : unit ->
      assert_ (Constraint.boolean this##.value)) ;
  add_method "isZero" (fun this : bool_class Js.t ->
      new%js bool_constr
        (As_bool.of_boolean (Field.equal this##.value Field.zero))) ;
  (* TODO: toBool *)
  add_method "unpack" (fun this : bool_class Js.t Js.js_array Js.t ->
      let arr = new%js Js.array_empty in
      List.iter
        (Field.unpack ~length:Field.size_in_bits this##.value)
        ~f:(fun x ->
          arr##push (new%js bool_constr (As_bool.of_boolean x)) |> ignore) ;
      arr) ;
  add_method "equals" (fun this (y : As_field.t) : bool_class Js.t ->
      new%js bool_constr
        (As_bool.of_boolean (Field.equal this##.value (As_field.value y)))) ;
  let add_static_op1 name (f : Field.t -> Field.t) =
    Js.Unsafe.set field_class (Js.string name)
      (Js.wrap_callback (fun (x : As_field.t) : field_class Js.t ->
           mk (f (As_field.value x))))
  in
  let add_static_op2 name (f : Field.t -> Field.t -> Field.t) =
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
  add_static_op2 "add" Field.add ;
  add_static_op2 "sub" sub ;
  add_static_op2 "mul" Field.mul ;
  add_static_op2 "div" div ;
  add_static_op1 "neg" Field.negate ;
  add_static_op1 "inv" Field.inv ;
  add_static_op1 "square" Field.square ;
  add_static_op1 "sqrt" sqrt ;
  field_class##.toString :=
    Js.wrap_callback (fun (x : As_field.t) : Js.js_string Js.t ->
        to_string (As_field.value x)) ;
  field_class##.sizeInFieldElements := Js.wrap_callback (fun () : int -> 1) ;
  field_class##.toFieldElements
  := Js.wrap_callback
       (fun (x : As_field.t) : field_class Js.t Js.js_array Js.t ->
         (* TODO: Don't allocate a new object if it's already a field_class object, rather than calling mk. *)
         singleton_array (mk (As_field.value x))) ;
  field_class##.ofFieldElements
  := Js.wrap_callback
       (fun (xs : field_class Js.t Js.js_array Js.t) : field_class Js.t ->
         if xs##.length = 1 then
           Js.Optdef.get (Js.array_get xs 0) (fun () -> assert false)
         else failwith "Expected array of length 1") ;
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
  field_class##.pack :=
    Js.wrap_callback
      (fun (bs : As_bool.t Js.js_array Js.t) : field_class Js.t ->
        mk
          (Field.pack
             (List.init bs##.length ~f:(fun i ->
                  Js.Optdef.case (Js.array_get bs i)
                    (fun () -> assert false)
                    As_bool.value)))) ;
  field_class##.unpack :=
    Js.wrap_callback (fun (x : As_field.t) : bool_class Js.t Js.js_array Js.t ->
        let arr = new%js Js.array_empty in
        List.iter
          (Field.unpack ~length:Field.size_in_bits (As_field.value x))
          ~f:(fun b ->
            arr##push (new%js bool_constr (As_bool.of_boolean b)) |> ignore) ;
        arr) ;
  field_class##.equals :=
    Js.wrap_callback (fun (x : As_field.t) (y : As_field.t) : bool_class Js.t ->
        new%js bool_constr
          (As_bool.of_boolean
             (Field.equal (As_field.value x) (As_field.value y))))

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
  let add_method name (f : bool_class Js.t -> _) =
    let prototype = Js.Unsafe.get bool_class (Js.string "prototype") in
    Js.Unsafe.set prototype (Js.string name) (Js.wrap_meth_callback f)
  in
  let add_op1 name (f : Boolean.var -> Boolean.var) =
    add_method name (fun this : bool_class Js.t -> mk (f this##.value))
  in
  let add_op2 name (f : Boolean.var -> Boolean.var -> Boolean.var) =
    add_method name (fun this (y : As_bool.t) : bool_class Js.t ->
        mk (f this##.value (As_bool.value y)))
  in
  add_method "toField" (fun this : field_class Js.t ->
      new%js field_constr (As_field.of_field (this##.value :> Field.t))) ;
  add_op1 "not" Boolean.not ;
  add_op2 "and" Boolean.( &&& ) ;
  add_op2 "or" Boolean.( ||| ) ;
  add_method "assertEqual" (fun this (y : As_bool.t) : unit ->
      Boolean.Assert.( = ) this##.value (As_bool.value y)) ;
  add_op2 "equals" equal ;
  add_op1 "isTrue" Fn.id ;
  add_op1 "isFalse" Boolean.not ;
  add_method "sizeInFieldElements" (fun _this : int -> 1) ;
  add_method "toFieldElements" (fun this : field_class Js.t Js.js_array Js.t ->
      let arr = new%js Js.array_empty in
      arr##push this##toField |> ignore ;
      arr) ;
  let add_static_method name f =
    Js.Unsafe.set bool_class (Js.string name) (Js.wrap_callback f)
  in
  let add_static_op1 name (f : Boolean.var -> Boolean.var) =
    add_static_method name (fun (x : As_bool.t) : bool_class Js.t ->
        mk (f (As_bool.value x)))
  in
  let add_static_op2 name (f : Boolean.var -> Boolean.var -> Boolean.var) =
    add_static_method name
      (fun (x : As_bool.t) (y : As_bool.t) : bool_class Js.t ->
        mk (f (As_bool.value x) (As_bool.value y)))
  in
  add_static_method "toField" (fun (x : As_bool.t) ->
      new%js field_constr (As_field.of_field (As_bool.value x :> Field.t))) ;
  Js.Unsafe.set bool_class (Js.string "Unsafe")
    (object%js
       method ofField (x : As_field.t) : bool_class Js.t =
         new%js bool_constr
           (As_bool.of_boolean (Boolean.Unsafe.of_cvar (As_field.value x)))
    end) ;
  add_static_op1 "not" Boolean.not ;
  add_static_op2 "and" Boolean.( &&& ) ;
  add_static_op2 "or" Boolean.( ||| ) ;
  add_static_method "assertEqual" (fun (x : As_bool.t) (y : As_bool.t) : unit ->
      Boolean.Assert.( = ) (As_bool.value x) (As_bool.value y)) ;
  add_static_op2 "equals" equal ;
  add_static_op1 "isTrue" Fn.id ;
  add_static_op1 "isFalse" Boolean.not ;
  add_static_method "count"
    (fun (bs : As_bool.t Js.js_array Js.t) : field_class Js.t ->
      new%js field_constr
        (As_field.of_field
           (Field.sum
              (List.init bs##.length ~f:(fun i ->
                   ( Js.Optdef.case (Js.array_get bs i)
                       (fun () -> assert false)
                       As_bool.value
                     :> Field.t )))))) ;
  add_static_method "sizeInFieldElements" (fun () : int -> 1) ;
  add_static_method "toFieldElements"
    (fun (x : As_bool.t) : field_class Js.t Js.js_array Js.t ->
      singleton_array
        (new%js field_constr (As_field.of_field (As_bool.value x :> Field.t)))) ;
  add_static_method "ofFieldElements"
    (fun (xs : field_class Js.t Js.js_array Js.t) : bool_class Js.t ->
      if xs##.length = 1 then
        Js.Optdef.case (Js.array_get xs 0)
          (fun () -> assert false)
          (fun x -> mk (Boolean.Unsafe.of_cvar x##.value))
      else failwith "Expected array of length 1")

let () = Js.export "Field" field_class

let () = Js.export "Bool" bool_class
