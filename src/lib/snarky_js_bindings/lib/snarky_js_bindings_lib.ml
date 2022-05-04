module Backend = Kimchi_backend.Pasta.Vesta_based_plonk
module Other_backend = Kimchi_backend.Pasta.Pallas_based_plonk
module Impl = Pickles.Impls.Step
module Other_impl = Pickles.Impls.Wrap
module Challenge = Limb_vector.Challenge.Make (Impl)
module Sc =
  Pickles.Scalar_challenge.Make (Impl) (Pickles.Step_main_inputs.Inner_curve)
    (Challenge)
    (Pickles.Endo.Step_inner_curve)
module Js = Js_of_ocaml.Js

let console_log_string s = Js_of_ocaml.Firebug.console##log (Js.string s)

let console_log s = Js_of_ocaml.Firebug.console##log s

let raise_error s =
  let s = Js.string s in
  Js.raise_js_error (new%js Js.error_constr s)

let raise_errorf fmt = Core_kernel.ksprintf raise_error fmt

class type field_class =
  object
    method value : Impl.Field.t Js.prop

    method toString : Js.js_string Js.t Js.meth

    method toJSON : < .. > Js.t Js.meth

    method toFields : field_class Js.t Js.js_array Js.t Js.meth
  end

and bool_class =
  object
    method value : Impl.Boolean.var Js.prop

    method toBoolean : bool Js.t Js.meth

    method toField : field_class Js.t Js.meth

    method toJSON : < .. > Js.t Js.meth

    method toFields : field_class Js.t Js.js_array Js.t Js.meth
  end

module As_field = struct
  (* number | string | boolean | field_class | cvar *)
  type t

  let of_field (x : Impl.Field.t) : t = Obj.magic x

  let of_field_obj (x : field_class Js.t) : t = Obj.magic x

  let value (value : t) : Impl.Field.t =
    match Js.to_string (Js.typeof (Obj.magic value)) with
    | "number" ->
        let value = Js.float_of_number (Obj.magic value) in
        if Float.is_integer value then
          let value = Float.to_int value in
          if value >= 0 then Impl.Field.of_int value
          else Impl.Field.negate (Impl.Field.of_int (-value))
        else raise_error "Cannot convert a float to a field element"
    | "boolean" ->
        let value = Js.to_bool (Obj.magic value) in
        if value then Impl.Field.one else Impl.Field.zero
    | "string" -> (
        let value : Js.js_string Js.t = Obj.magic value in
        let s = Js.to_string value in
        try
          Impl.Field.constant
            ( if
              String.length s >= 2
              && Char.equal s.[0] '0'
              && Char.equal (Char.lowercase_ascii s.[1]) 'x'
            then Kimchi_pasta.Pasta.Fp.(of_bigint (Bigint.of_hex_string s))
            else Impl.Field.Constant.of_string s )
        with Failure e -> raise_error e )
    | "object" ->
        let is_array = Js.to_bool (Js.Unsafe.global ##. Array##isArray value) in
        if is_array then
          (* Cvar case *)
          (* TODO: Make this conversion more robust by rejecting invalid cases *)
          Obj.magic value
        else
          (* Object case *)
          Js.Optdef.get
            (Obj.magic value)##.value
            (fun () -> raise_error "Expected object with property \"value\"")
    | s ->
        raise_error
          (Core_kernel.sprintf
             "Type \"%s\" cannot be converted to a field element" s)

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

  let of_boolean (x : Impl.Boolean.var) : t = Obj.magic x

  let of_bool_obj (x : bool_class Js.t) : t = Obj.magic x

  let of_js_bool (b : bool Js.t) : t = Obj.magic b

  let value (value : t) : Impl.Boolean.var =
    match Js.to_string (Js.typeof (Obj.magic value)) with
    | "boolean" ->
        let value = Js.to_bool (Obj.magic value) in
        Impl.Boolean.var_of_value value
    | "object" ->
        let is_array = Js.to_bool (Js.Unsafe.global ##. Array##isArray value) in
        if is_array then
          (* Cvar case *)
          (* TODO: Make this conversion more robust by rejecting invalid cases *)
          Obj.magic value
        else
          (* Object case *)
          Js.Optdef.get
            (Obj.magic value)##.value
            (fun () -> raise_error "Expected object with property \"value\"")
    | s ->
        raise_error
          (Core_kernel.sprintf "Type \"%s\" cannot be converted to a boolean" s)
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

module Field = Impl.Field
module Boolean = Impl.Boolean
module As_prover = Impl.As_prover
module Constraint = Impl.Constraint
module Bigint = Impl.Bigint
module Keypair = Impl.Keypair
module Verification_key = Impl.Verification_key
module Typ = Impl.Typ

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
      raise_error (sprintf "array_get_exn: index=%d, length=%d" i xs##.length))

let array_check_length xs n =
  if xs##.length <> n then raise_error (sprintf "Expected array of length %d" n)

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

let to_js_field x : field_class Js.t = new%js field_constr (As_field.of_field x)

let of_js_field (x : field_class Js.t) : Field.t = x##.value

let to_js_field_unchecked x : field_class Js.t =
  x |> Field.constant |> to_js_field

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
  let mk = to_js_field in
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
  method_ "sizeInFields" (fun _this : int -> 1) ;
  method_ "toFields" (fun this : field_class Js.t Js.js_array Js.t ->
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
   List.iter ~f:cmp_method
     [ ("assertLt", Field.Assert.lt)
     ; ("assertLte", Field.Assert.lte)
     ; ("assertGt", Field.Assert.gt)
     ; ("assertGte", Field.Assert.gte)
     ]) ;
  method_ "assertEquals" (fun this (y : As_field.t) : unit ->
      try Field.Assert.equal this##.value (As_field.value y)
      with _ ->
        console_log this ;
        console_log (As_field.to_field_obj y) ;
        let () = raise_error "assertEquals: not equal" in
        ()) ;

  (* TODO: bring back better error msg when .toString works in circuits *)
  (* sprintf "assertEquals: %s != %s"
         (Js.to_string this##toString)
         (Js.to_string (As_field.to_field_obj y)##toString)
     in
     Js.raise_js_error (new%js Js.error_constr (Js.string s))) ; *)
  method_ "assertBoolean" (fun this : unit ->
      Impl.assert_ (Constraint.boolean this##.value)) ;
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
            raise_error
              (sprintf "Value %s did not fit in %d bits"
                 (Field.Constant.to_string x)
                 length) ;
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
  field_class##.sizeInFields := Js.wrap_callback (fun () : int -> 1) ;
  field_class##.toFields :=
    Js.wrap_callback
      (fun (x : As_field.t) : field_class Js.t Js.js_array Js.t ->
        (As_field.to_field_obj x)##toFields) ;
  field_class##.ofFields :=
    Js.wrap_callback
      (fun (xs : field_class Js.t Js.js_array Js.t) : field_class Js.t ->
        array_check_length xs 1 ; array_get_exn xs 0) ;
  field_class##.assertEqual :=
    Js.wrap_callback (fun (x : As_field.t) (y : As_field.t) : unit ->
        Field.Assert.equal (As_field.value x) (As_field.value y)) ;
  field_class##.assertBoolean
  := Js.wrap_callback (fun (x : As_field.t) : unit ->
         Impl.assert_ (Constraint.boolean (As_field.value x))) ;
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
  method_ "seal"
    (let seal = Pickles.Util.seal (module Impl) in
     fun (this : field_class Js.t) : field_class Js.t -> mk (seal this##.value)) ;
  method_ "rangeCheckHelper"
    (fun (this : field_class Js.t) (num_bits : int) : field_class Js.t ->
      match this##.value with
      | Constant v ->
          let n = Bigint.of_field v in
          for i = num_bits to Field.size_in_bits - 1 do
            if Bigint.test_bit n i then
              raise_error
                (sprintf
                   !"rangeCheckHelper: Expected %{sexp:Field.Constant.t} to \
                     fit in %d bits"
                   v num_bits)
          done ;
          this
      | v ->
          let _a, _b, n =
            Pickles.Scalar_challenge.to_field_checked' ~num_bits
              (module Impl)
              { inner = v }
          in
          mk n) ;
  method_ "isConstant" (fun (this : field_class Js.t) : bool Js.t ->
      match this##.value with Constant _ -> Js._true | _ -> Js._false) ;
  method_ "toConstant" (fun (this : field_class Js.t) : field_class Js.t ->
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
                   String.length s > 1
                   && Char.equal s.[0] '0'
                   && Char.equal (Char.lowercase s.[1]) 'x'
                 then Kimchi_pasta.Pasta.Fp.(of_bigint (Bigint.of_hex_string s))
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
  method_ "toBoolean" (fun this : bool Js.t ->
      match (this##.value :> Field.t) with
      | Constant x ->
          Js.bool Field.Constant.(equal one x)
      | _ -> (
          try Js.bool (As_prover.read Boolean.typ this##.value)
          with _ ->
            raise_error
              "Bool.toBoolean can only be called on non-witness values." )) ;
  method_ "sizeInFields" (fun _this : int -> 1) ;
  method_ "toString" (fun this ->
      let x =
        match (this##.value :> Field.t) with
        | Constant x ->
            x
        | x ->
            As_prover.read_var x
      in
      if Field.Constant.(equal one) x then "true" else "false") ;
  method_ "toFields" (fun this : field_class Js.t Js.js_array Js.t ->
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
  static_method "sizeInFields" (fun () : int -> 1) ;
  static_method "toFields"
    (fun (x : As_bool.t) : field_class Js.t Js.js_array Js.t ->
      singleton_array
        (new%js field_constr (As_field.of_field (As_bool.value x :> Field.t)))) ;
  static_method "ofFields"
    (fun (xs : field_class Js.t Js.js_array Js.t) : bool_class Js.t ->
      if xs##.length = 1 then
        Js.Optdef.case (Js.array_get xs 0)
          (fun () -> assert false)
          (fun x -> mk (Boolean.Unsafe.of_cvar x##.value))
      else raise_error "Expected array of length 1") ;
  static_method "check" (fun (x : bool_class Js.t) : unit ->
      Impl.assert_ (Constraint.boolean (x##.value :> Field.t))) ;
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

      method toFields : field_class Js.t Js.js_array Js.t Js.meth
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

let to_js_group (x : Impl.Field.t) (y : Impl.Field.t) : group_class Js.t =
  new%js group_constr
    (As_field.of_field_obj (to_js_field x))
    (As_field.of_field_obj (to_js_field y))

let scalar_shift =
  Pickles_types.Shifted_value.Type1.Shift.create (module Other_backend.Field)

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
        (Pickles_types.Shifted_value.Type1.to_field
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

let scalar_to_bits x =
  let (Shifted_value x) =
    Pickles_types.Shifted_value.Type1.of_field ~shift:scalar_shift
      (module Other_backend.Field)
      x
  in
  Array.of_list_map (Other_backend.Field.to_bits x) ~f:Boolean.var_of_value

let to_js_scalar x = new%js scalar_constr_const (scalar_to_bits x) x

let () =
  let num_bits = Field.size_in_bits in
  let method_ name (f : scalar_class Js.t -> _) = method_ scalar_class name f in
  let static_method name f =
    Js.Unsafe.set scalar_class (Js.string name) (Js.wrap_callback f)
  in
  let ( ! ) name x =
    Js.Optdef.get x (fun () ->
        raise_error
          (sprintf "Scalar.%s can only be called on non-witness values." name))
  in
  let bits = scalar_to_bits in
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
  method_ "toFields" (fun x : field_class Js.t Js.js_array Js.t ->
      Array.map x##.value ~f:(fun b ->
          new%js field_constr (As_field.of_field (b :> Field.t)))
      |> Js.array) ;
  static_method "toFields"
    (fun (x : scalar_class Js.t) : field_class Js.t Js.js_array Js.t ->
      (Js.Unsafe.coerce x)##toFields) ;
  static_method "sizeInFields" (fun () : int -> num_bits) ;
  static_method "ofFields"
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
              (fun () -> raise_error "Cannot convert in-circuit value to JSON"))
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
              then Kimchi_pasta.Pasta.Fq.(of_bigint (Bigint.of_hex_string s))
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
      match (p1, p2) with
      | (Constant x1, Constant y1), (Constant x2, Constant y2) ->
          constant
            (Pickles.Step_main_inputs.Inner_curve.Constant.( + ) (x1, y1)
               (x2, y2))
      | _ ->
          Pickles.Step_main_inputs.Ops.add_fast p1 p2 |> mk) ;
  method_ "neg" (fun (p1 : group_class Js.t) : group_class Js.t ->
      Pickles.Step_main_inputs.Inner_curve.negate
        (As_group.value (As_group.of_group_obj p1))
      |> mk) ;
  method_ "sub"
    (fun (p1 : group_class Js.t) (p2 : As_group.t) : group_class Js.t ->
      p1##add (As_group.to_group_obj p2)##neg) ;
  method_ "scale"
    (fun (p1 : group_class Js.t) (s : scalar_class Js.t) : group_class Js.t ->
      match
        ( As_group.(value (of_group_obj p1))
        , Js.Optdef.to_option s##.constantValue )
      with
      | (Constant x, Constant y), Some s ->
          Pickles.Step_main_inputs.Inner_curve.Constant.scale (x, y) s
          |> constant
      | _ ->
          let bits = Array.copy s##.value in
          (* Have to convert LSB -> MSB *)
          Array.rev_inplace bits ;
          Pickles.Step_main_inputs.Ops.scale_fast_msb_bits
            (As_group.value (As_group.of_group_obj p1))
            (Shifted_value bits)
          |> mk) ;
  (* TODO
     method_ "endoScale"
       (fun (p1 : group_class Js.t) (s : endo_scalar_class Js.t) : group_class Js.t
       ->
         Sc.endo
           (As_group.value (As_group.of_group_obj p1))
           (Scalar_challenge s##.value)
         |> mk) ; *)
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
  method_ "toFields"
    (fun (p1 : group_class Js.t) : field_class Js.t Js.js_array Js.t ->
      let arr = singleton_array p1##.x in
      arr##push p1##.y |> ignore ;
      arr) ;
  static_method "toFields" (fun (p1 : group_class Js.t) -> p1##toFields) ;
  static_method "ofFields" (fun (xs : field_class Js.t Js.js_array Js.t) ->
      array_check_length xs 2 ;
      new%js group_constr
        (As_field.of_field_obj (array_get_exn xs 0))
        (As_field.of_field_obj (array_get_exn xs 1))) ;
  static_method "sizeInFields" (fun () : int -> 2) ;
  static_method "check" (fun (p : group_class Js.t) : unit ->
      Pickles.Step_main_inputs.Inner_curve.assert_on_curve
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

class type ['a] as_field_elements =
  object
    method toFields : 'a -> field_class Js.t Js.js_array Js.t Js.meth

    method ofFields : field_class Js.t Js.js_array Js.t -> 'a Js.meth

    method sizeInFields : int Js.meth
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

module Poseidon_sponge_checked =
  Sponge.Make_sponge (Pickles.Step_main_inputs.Sponge.Permutation)
module Poseidon_sponge =
  Sponge.Make_sponge (Sponge.Poseidon (Pickles.Tick_field_sponge.Inputs))

let sponge_params_checked =
  Sponge.Params.(
    map pasta_p_kimchi ~f:(Fn.compose Field.constant Field.Constant.of_string))

let sponge_params =
  Sponge.Params.(map pasta_p_kimchi ~f:Field.Constant.of_string)

type sponge =
  | Checked of Poseidon_sponge_checked.t
  | Unchecked of Poseidon_sponge.t

let to_unchecked (x : Field.t) =
  match x with Constant y -> y | y -> Impl.As_prover.read_var y

let poseidon =
  object%js
    method hash (xs : field_class Js.t Js.js_array Js.t) : field_class Js.t =
      let input = Array.map (Js.to_array xs) ~f:of_js_field in
      let digest =
        try Random_oracle.Checked.hash input
        with _ ->
          Random_oracle.hash (Array.map ~f:to_unchecked input) |> Field.constant
      in
      to_js_field digest

    (* returns a "sponge" that stays opaque to JS *)
    method spongeCreate () : sponge =
      if Impl.in_checked_computation () then
        Checked
          (Poseidon_sponge_checked.create ?init:None sponge_params_checked)
      else Unchecked (Poseidon_sponge.create ?init:None sponge_params)

    method spongeAbsorb (sponge : sponge) field : unit =
      match sponge with
      | Checked s ->
          Poseidon_sponge_checked.absorb s (of_js_field field)
      | Unchecked s ->
          Poseidon_sponge.absorb s (to_unchecked @@ of_js_field field)

    method spongeSqueeze (sponge : sponge) =
      match sponge with
      | Checked s ->
          Poseidon_sponge_checked.squeeze s |> to_js_field
      | Unchecked s ->
          Poseidon_sponge.squeeze s |> Field.constant |> to_js_field
  end

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
      raise_error
        (sprintf "%s: Got mismatched lengths, %d != %d" s t1##.length
           t2##.length)
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
    else
      raise_error
        (sprintf "Type \"%s\" cannot be used with function \"%s\"" t name)

  let rec to_field_elts_magic :
      type a. a Js.t -> field_class Js.t Js.js_array Js.t =
    fun (type a) (t1 : a Js.t) : field_class Js.t Js.js_array Js.t ->
     let t1_is_array = Js.Unsafe.global ##. Array##isArray t1 in
     check_type "toFields" (Js.typeof t1) ;
     match t1_is_array with
     | true ->
         let arr = array_map (Obj.magic t1) ~f:to_field_elts_magic in
         (Obj.magic arr)##flat
     | false -> (
         let ctor1 : _ Js.Optdef.t = (Obj.magic t1)##.constructor in
         let has_methods ctor =
           let has s = Js.to_bool (ctor##hasOwnProperty (Js.string s)) in
           has "toFields" && has "ofFields"
         in
         match Js.Optdef.(to_option ctor1) with
         | Some ctor1 when has_methods ctor1 ->
             ctor1##toFields t1
         | Some _ ->
             let arr =
               array_map
                 (keys t1)##sort_asStrings
                 ~f:(fun k -> to_field_elts_magic (Js.Unsafe.get t1 k))
             in
             (Obj.magic arr)##flat
         | None ->
             raise_error "toFields: Argument did not have a constructor." )

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
          < toFields : field_class Js.t Js.js_array Js.t Js.meth > Js.t as 'a)
        (t2 : 'a) : unit =
      f (to_field_elts_magic t1) (to_field_elts_magic t2)
    in
    let explicit
        (ctor :
          < toFields : 'a -> field_class Js.t Js.js_array Js.t Js.meth > Js.t)
        (t1 : 'a) (t2 : 'a) : unit =
      f (ctor##toFields t1) (ctor##toFields t2)
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
          < toFields : field_class Js.t Js.js_array Js.t Js.meth > Js.t as 'a)
        (t2 : 'a) : bool_class Js.t =
      f t1##toFields t2##toFields
    in
    let implicit t1 t2 = f (to_field_elts_magic t1) (to_field_elts_magic t2) in
    let explicit
        (ctor :
          < toFields : 'a -> field_class Js.t Js.js_array Js.t Js.meth > Js.t)
        (t1 : 'a) (t2 : 'a) : bool_class Js.t =
      f (ctor##toFields t1) (ctor##toFields t2)
    in
    wrap "equal" ~pre_args:0 ~post_args:2 ~explicit ~implicit

  let if_explicit (type a) (b : As_bool.t) (ctor : a as_field_elements Js.t)
      (x1 : a) (x2 : a) =
    let b = As_bool.value b in
    match (b :> Field.t) with
    | Constant b ->
        if Field.Constant.(equal one b) then x1 else x2
    | _ ->
        let t1 = ctor##toFields x1 in
        let t2 = ctor##toFields x2 in
        let arr = if_array b t1 t2 in
        ctor##ofFields arr

  let rec if_magic : type a. As_bool.t -> a Js.t -> a Js.t -> a Js.t =
    fun (type a) (b : As_bool.t) (t1 : a Js.t) (t2 : a Js.t) : a Js.t ->
     check_type "if" (Js.typeof t1) ;
     check_type "if" (Js.typeof t2) ;
     let t1_is_array = Js.Unsafe.global ##. Array##isArray t1 in
     let t2_is_array = Js.Unsafe.global ##. Array##isArray t2 in
     match (t1_is_array, t2_is_array) with
     | false, true | true, false ->
         raise_error "if: Mismatched argument types"
     | true, true ->
         array_map2 (Obj.magic t1) (Obj.magic t2) ~f:(fun x1 x2 ->
             if_magic b x1 x2)
         |> Obj.magic
     | false, false -> (
         let ctor1 : _ Js.Optdef.t = (Obj.magic t1)##.constructor in
         let ctor2 : _ Js.Optdef.t = (Obj.magic t2)##.constructor in
         let has_methods ctor =
           let has s = Js.to_bool (ctor##hasOwnProperty (Js.string s)) in
           has "toFields" && has "ofFields"
         in
         if not (js_equal ctor1 ctor2) then
           raise_error "if: Mismatched argument types" ;
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
                   raise_error "if: Arguments had mismatched types") ;
             let result = new%js ctor1 in
             array_iter ks1 ~f:(fun k ->
                 Js.Unsafe.set result k
                   (if_magic b (Js.Unsafe.get t1 k) (Js.Unsafe.get t2 k))) ;
             Obj.magic result
         | Some _, None | None, Some _ ->
             assert false
         | None, None ->
             raise_error "if: Arguments did not have a constructor." )

  let if_ =
    wrap "if" ~pre_args:1 ~post_args:2 ~explicit:if_explicit ~implicit:if_magic

  let typ_ (type a) (typ : a as_field_elements Js.t) : (a, a) Typ.t =
    let to_array conv a =
      Js.to_array (typ##toFields a) |> Array.map ~f:(fun x -> conv x##.value)
    in
    let of_array conv xs =
      typ##ofFields
        (Js.array
           (Array.map xs ~f:(fun x ->
                new%js field_constr (As_field.of_field (conv x)))))
    in
    Typ.transport
      (Typ.array ~length:typ##sizeInFields Field.typ)
      ~there:(to_array (fun x -> Option.value_exn (Field.to_constant x)))
      ~back:(of_array Field.constant)
    |> Typ.transport_var ~there:(to_array Fn.id) ~back:(of_array Fn.id)

  let witness (type a) (typ : a as_field_elements Js.t)
      (f : (unit -> a) Js.callback) : a =
    let a =
      Impl.exists (typ_ typ) ~compute:(fun () : a -> Js.Unsafe.fun_call f [||])
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

  module Promise : sig
    type _ t

    val return : 'a -> 'a t

    val map : 'a t -> f:('a -> 'b) -> 'b t
  end = struct
    (* type 'a t = < then_: 'b. ('a -> 'b) Js.callback -> 'b t Js.meth > Js.t *)
    type 'a t = < > Js.t

    let constr = Obj.magic Js.Unsafe.global ##. Promise

    let return (type a) (x : a) : a t =
      new%js constr
        (Js.wrap_callback (fun resolve ->
             Js.Unsafe.(fun_call resolve [| inject x |])))

    let map (type a b) (t : a t) ~(f : a -> b) : b t =
      (Js.Unsafe.coerce t)##then_ (Js.wrap_callback (fun (x : a) -> f x))
  end

  let main_and_input (type w p) (c : (w, p) Circuit_main.t) =
    let main ?(w : w option) (public : p) () =
      let w : w =
        witness c##.snarkyWitnessTyp
          (Js.wrap_callback (fun () -> Option.value_exn w))
      in
      Js.Unsafe.(fun_call c##.snarkyMain [| inject w; inject public |])
    in
    (main, Impl.Data_spec.[ typ_ c##.snarkyPublicTyp ])

  let generate_keypair (type w p) (c : (w, p) Circuit_main.t) :
      keypair_class Js.t =
    let main, spec = main_and_input c in
    let cs = Impl.constraint_system ~exposing:spec (fun x -> main x) in
    let kp = Impl.Keypair.generate cs in
    new%js keypair_constr kp

  let prove (type w p) (c : (w, p) Circuit_main.t) (priv : w) (pub : p) kp :
      proof_class Js.t =
    let main, spec = main_and_input c in
    let pk = Keypair.pk kp in
    let p =
      Impl.generate_witness_conv
        ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs } ->
          Backend.Proof.create pk ~auxiliary:auxiliary_inputs
            ~primary:public_inputs)
        spec (main ~w:priv) pub
    in
    new%js proof_constr p

  let circuit = Js.Unsafe.eval_string {js|(function() { return this })|js}

  let () =
    let array (type a) (typ : a as_field_elements Js.t) (length : int) :
        a Js.js_array Js.t as_field_elements Js.t =
      let elt_len = typ##sizeInFields in
      let len = length * elt_len in
      object%js
        method sizeInFields = len

        method toFields (xs : a Js.js_array Js.t) =
          let res = new%js Js.array_empty in
          for i = 0 to xs##.length - 1 do
            let x = typ##toFields (array_get_exn xs i) in
            for j = 0 to x##.length - 1 do
              res##push (array_get_exn x j) |> ignore
            done
          done ;
          res

        method ofFields (xs : field_class Js.t Js.js_array Js.t) =
          let res = new%js Js.array_empty in
          for i = 0 to length - 1 do
            let a = new%js Js.array_empty in
            let offset = i * elt_len in
            for j = 0 to elt_len - 1 do
              a##push (array_get_exn xs (offset + j)) |> ignore
            done ;
            res##push (typ##ofFields a) |> ignore
          done ;
          res
      end
    in
    let module Run_and_check_deferred = Impl.Run_and_check_deferred (Promise) in
    let call (type b) (f : (unit -> b) Js.callback) =
      Js.Unsafe.(fun_call f [||])
    in
    (* TODO this hasn't been working reliably, reconsider how we should enable async circuits *)
    circuit##.runAndCheck :=
      Js.wrap_callback
        (fun (type a)
             (f : (unit -> (unit -> a) Js.callback Promise.t) Js.callback) :
             a Promise.t ->
          Run_and_check_deferred.run_and_check (fun () ->
              let g : (unit -> a) Js.callback Promise.t = call f in
              Promise.map g ~f:(fun (p : (unit -> a) Js.callback) () -> call p))
          |> Promise.map ~f:Or_error.ok_exn) ;
    circuit##.runAndCheckSync :=
      Js.wrap_callback (fun (f : unit -> 'a) ->
          Impl.run_and_check (fun () -> f) |> Or_error.ok_exn) ;

    circuit##.asProver :=
      Js.wrap_callback (fun (f : (unit -> unit) Js.callback) : unit ->
          Impl.as_prover (fun () -> Js.Unsafe.fun_call f [||])) ;
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
    circuit##.toFields := Js.wrap_callback to_field_elts_magic ;
    circuit##.inProver :=
      Js.wrap_callback (fun () : bool Js.t -> Js.bool (Impl.in_prover ())) ;
    circuit##.inCheckedComputation
    := Js.wrap_callback (fun () : bool Js.t ->
           Js.bool (Impl.in_checked_computation ())) ;
    Js.Unsafe.set circuit (Js.string "if") if_ ;
    circuit##.getVerificationKey
    := fun (vk : Verification_key.t) -> new%js verification_key_constr vk
end

let () =
  let method_ name (f : keypair_class Js.t -> _) =
    method_ keypair_class name f
  in
  method_ "verificationKey"
    (fun (this : keypair_class Js.t) : verification_key_class Js.t ->
      new%js verification_key_constr (Keypair.vk this##.value))

(* TODO: add verificationKey.toString / fromString *)
let () =
  let method_ name (f : verification_key_class Js.t -> _) =
    method_ verification_key_class name f
  in
  (* TODO
     let module M = struct
       type t =
         ( Backend.Field.t
         , Kimchi.Protocol.SRS.Fp. Marlin_plonk_bindings_pasta_fp_urs.t
         , Pasta.Vesta.Affine.Stable.Latest.t
             Marlin_plonk_bindings.Types.Poly_comm.t
         )
         Marlin_plonk_bindings.Types.Plonk_verifier_index.t
       [@@deriving bin_io_unversioned]
     end in
     method_ "toString"
       (fun this : Js.js_string Js.t ->
          Binable.to_string (module Backend.Verification_key) this##.value
        |> Js.string ) ;
  *)
  proof_class##.ofString :=
    Js.wrap_callback (fun (s : Js.js_string Js.t) : proof_class Js.t ->
        new%js proof_constr
          (Js.to_string s |> Binable.of_string (module Backend.Proof))) ;
  method_ "verify"
    (fun
      (this : verification_key_class Js.t)
      (pub : Js.Unsafe.any Js.js_array Js.t)
      (pi : proof_class Js.t)
      :
      bool Js.t
    ->
      let v = Backend.Field.Vector.create () in
      array_iter (Circuit.to_field_elts_magic pub) ~f:(fun x ->
          match x##.value with
          | Constant x ->
              Backend.Field.Vector.emplace_back v x
          | _ ->
              raise_error "verify: Expected non-circuit values for input") ;
      Backend.Proof.verify pi##.value this##.value v |> Js.bool)

let () =
  let method_ name (f : proof_class Js.t -> _) = method_ proof_class name f in
  method_ "toString" (fun this : Js.js_string Js.t ->
      Binable.to_string (module Backend.Proof) this##.value |> Js.string) ;
  proof_class##.ofString :=
    Js.wrap_callback (fun (s : Js.js_string Js.t) : proof_class Js.t ->
        new%js proof_constr
          (Js.to_string s |> Binable.of_string (module Backend.Proof))) ;
  method_ "verify"
    (fun
      (this : proof_class Js.t)
      (vk : verification_key_class Js.t)
      (pub : Js.Unsafe.any Js.js_array Js.t)
      :
      bool Js.t
    -> vk##verify pub this)

(* helpers for pickles_compile *)

type 'a zkapp_statement = { transaction : 'a; at_party : 'a }

let zkapp_statement_to_fields { transaction; at_party } =
  [| transaction; at_party |]

type zkapp_statement_js =
  < transaction : field_class Js.t Js.readonly_prop
  ; atParty : field_class Js.t Js.readonly_prop >
  Js.t

module Zkapp_statement = struct
  type t = Field.t zkapp_statement

  let to_field_elements = zkapp_statement_to_fields

  let to_constant ({ transaction; at_party } : t) =
    { transaction = to_unchecked transaction; at_party = to_unchecked at_party }

  let to_js ({ transaction; at_party } : t) =
    object%js
      val transaction = to_js_field transaction

      val atParty = to_js_field at_party
    end

  let of_js (statement : zkapp_statement_js) =
    { transaction = of_js_field statement##.transaction
    ; at_party = of_js_field statement##.atParty
    }

  module Constant = struct
    type t = Field.Constant.t zkapp_statement

    let to_field_elements = zkapp_statement_to_fields

    let to_js ({ transaction; at_party } : t) =
      to_js
        { transaction = Field.constant transaction
        ; at_party = Field.constant at_party
        }
  end
end

let zkapp_statement_typ =
  let to_hlist { transaction; at_party } = H_list.[ transaction; at_party ] in
  let of_hlist ([ transaction; at_party ] : (unit, _) H_list.t) =
    { transaction; at_party }
  in
  Typ.of_hlistable [ Field.typ; Field.typ ] ~var_to_hlist:to_hlist
    ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let dummy_constraints =
  let module Inner_curve = Kimchi_pasta.Pasta.Pallas in
  let module Step_main_inputs = Pickles.Step_main_inputs in
  let inner_curve_typ : (Field.t * Field.t, Inner_curve.t) Typ.t =
    Typ.transport Step_main_inputs.Inner_curve.typ
      ~there:Inner_curve.to_affine_exn ~back:Inner_curve.of_affine
  in
  fun () ->
    let x =
      Impl.exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3)
    in
    let g = Impl.exists inner_curve_typ ~compute:(fun _ -> Inner_curve.one) in
    ignore
      ( Pickles.Scalar_challenge.to_field_checked'
          (module Impl)
          ~num_bits:16
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t * Field.t ) ;
    ignore
      ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
        : Step_main_inputs.Inner_curve.t ) ;
    ignore
      ( Pickles.Step_verifier.Scalar_challenge.endo g ~num_bits:4
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t )

type ('a_var, 'a_value, 'a_weird) pickles_rule =
  { identifier : string
  ; prevs : 'a_weird list
  ; main : 'a_var list -> 'a_var -> Boolean.var list
  ; main_value : 'a_value list -> 'a_value -> bool list
  }

type pickles_rule_js = Js.js_string Js.t * (zkapp_statement_js -> unit)

let create_pickles_rule ((identifier, main) : pickles_rule_js) =
  { identifier = Js.to_string identifier
  ; prevs = []
  ; main =
      (fun _ statement ->
        dummy_constraints () ;
        main (Zkapp_statement.to_js statement) ;
        [])
  ; main_value = (fun _ _ -> [])
  }

let dummy_rule self =
  { identifier = "dummy"
  ; prevs = [ self; self ]
  ; main_value = (fun _ _ -> [ true; true ])
  ; main =
      (fun _ _ ->
        dummy_constraints () ;
        (* unsatisfiable *)
        let x =
          Impl.exists Field.typ ~compute:(fun () -> Field.Constant.zero)
        in
        Field.(Assert.equal x (x + one)) ;
        Boolean.[ true_; true_ ])
  }

let other_verification_key_constr :
    (Other_impl.Verification_key.t -> verification_key_class Js.t) Js.constr =
  Obj.magic verification_key_class

type proof = (Pickles_types.Nat.N2.n, Pickles_types.Nat.N2.n) Pickles.Proof.t

module Statement_with_proof =
  Pickles_types.Hlist.H3.T (Pickles.Statement_with_proof)

let nat_modules_list : (module Pickles_types.Nat.Intf) list =
  let open Pickles_types.Nat in
  [ (module N0)
  ; (module N1)
  ; (module N2)
  ; (module N3)
  ; (module N4)
  ; (module N5)
  ; (module N6)
  ; (module N7)
  ; (module N8)
  ; (module N9)
  ; (module N10)
  ; (module N11)
  ; (module N12)
  ; (module N13)
  ; (module N14)
  ; (module N15)
  ; (module N16)
  ; (module N17)
  ; (module N18)
  ; (module N19)
  ; (module N20)
  ]

let nat_module (i : int) : (module Pickles_types.Nat.Intf) =
  List.nth_exn nat_modules_list i

let pickles_compile (choices : pickles_rule_js Js.js_array Js.t) =
  let choices = choices |> Js.to_array |> Array.to_list in
  let branches = List.length choices + 1 in
  let choices ~self =
    List.map choices ~f:create_pickles_rule @ [ dummy_rule self ]
  in
  let (module Branches) = nat_module branches in
  (* TODO get rid of Obj.magic for choices *)
  let tag, _cache, p, provers =
    Pickles.compile_promise ~choices:(Obj.magic choices)
      (module Zkapp_statement)
      (module Zkapp_statement.Constant)
      ~typ:zkapp_statement_typ
      ~branches:(module Branches)
      ~max_branching:
        (module Pickles_types.Nat.N2)
        (* ^ TODO make max_branching configurable -- needs refactor in party types *)
      ~name:"smart-contract"
      ~constraint_constants:
        (* TODO these are dummy values *)
        { sub_windows_per_window = 0
        ; ledger_depth = 0
        ; work_delay = 0
        ; block_window_duration_ms = 0
        ; transaction_capacity = Log_2 0
        ; pending_coinbase_depth = 0
        ; coinbase_amount = Unsigned.UInt64.of_int 0
        ; supercharged_coinbase_factor = 0
        ; account_creation_fee = Unsigned.UInt64.of_int 0
        ; fork = None
        }
  in
  let module Proof = (val p) in
  let to_js_prover prover =
    let prove (statement_js : zkapp_statement_js) =
      (* TODO: get rid of Obj.magic, this should be an empty "H3.T" *)
      let prevs = Obj.magic [] in
      let statement = Zkapp_statement.(statement_js |> of_js |> to_constant) in
      prover ?handler:None prevs statement |> Promise_js_helpers.to_js
    in
    prove
  in
  let rec to_js_provers :
      type a b c.
         (a, b, c, Zkapp_statement.Constant.t, proof Promise.t) Pickles.Provers.t
      -> (zkapp_statement_js -> proof Promise_js_helpers.js_promise) list =
    function
    | [] ->
        []
    | p :: ps ->
        to_js_prover p :: to_js_provers ps
  in
  let verify (statement_js : zkapp_statement_js) (proof : proof) =
    let statement = Zkapp_statement.(statement_js |> of_js |> to_constant) in
    Proof.verify_promise [ (statement, proof) ] |> Promise_js_helpers.to_js
  in
  object%js
    val provers = provers |> to_js_provers |> Array.of_list |> Js.array

    val verify = verify

    val getVerificationKeyArtifact =
      fun () ->
        let vk = Pickles.Side_loaded.Verification_key.of_compiled tag in
        Pickles.Side_loaded.Verification_key.to_base58_check vk |> Js.string

    val getVerificationKey =
      fun () ->
        let key = Lazy.force Proof.verification_key in
        new%js other_verification_key_constr
          (Pickles.Verification_key.index key)
  end

let proof_to_string proof =
  proof |> Pickles.Side_loaded.Proof.to_yojson |> Yojson.Safe.to_string
  |> Js.string

let pickles =
  object%js
    val compile = pickles_compile

    val proofToString = proof_to_string
  end

module Ledger = struct
  type js_field = field_class Js.t

  type js_bool = bool_class Js.t

  type js_uint32 = < value : js_field Js.readonly_prop > Js.t

  type js_uint64 = < value : js_field Js.readonly_prop > Js.t

  type 'a or_ignore =
    < check : bool_class Js.t Js.prop ; value : 'a Js.prop > Js.t

  type 'a set_or_keep =
    < set : bool_class Js.t Js.prop ; value : 'a Js.prop > Js.t

  type 'a closed_interval = < lower : 'a Js.prop ; upper : 'a Js.prop > Js.t

  type epoch_ledger_predicate =
    < hash : js_field or_ignore Js.prop
    ; totalCurrency : js_uint64 closed_interval Js.prop >
    Js.t

  type epoch_data_predicate =
    < ledger : epoch_ledger_predicate Js.prop
    ; seed : js_field or_ignore Js.prop
    ; startCheckpoint : js_field or_ignore Js.prop
    ; lockCheckpoint : js_field or_ignore Js.prop
    ; epochLength : js_uint32 closed_interval Js.prop >
    Js.t

  type protocol_state_predicate =
    < snarkedLedgerHash : js_field or_ignore Js.prop
    ; timestamp : js_uint64 closed_interval Js.prop
    ; blockchainLength : js_uint32 closed_interval Js.prop
    ; minWindowDensity : js_uint32 closed_interval Js.prop
    ; lastVrfOutput : js_field or_ignore Js.prop
    ; totalCurrency : js_uint64 closed_interval Js.prop
    ; globalSlotSinceHardFork : js_uint32 closed_interval Js.prop
    ; globalSlotSinceGenesis : js_uint32 closed_interval Js.prop
    ; stakingEpochData : epoch_data_predicate Js.prop
    ; nextEpochData : epoch_data_predicate Js.prop >
    Js.t

  type private_key = < s : scalar_class Js.t Js.prop > Js.t

  type public_key = < g : group_class Js.t Js.prop > Js.t

  type auth_required =
    < constant : js_bool Js.prop
    ; signatureNecessary : js_bool Js.prop
    ; signatureSufficient : js_bool Js.prop >
    Js.t

  type permissions =
    < editState : auth_required Js.prop
    ; send : auth_required Js.prop
    ; receive : auth_required Js.prop
    ; setDelegate : auth_required Js.prop
    ; setPermissions : auth_required Js.prop
    ; setVerificationKey : auth_required Js.prop
    ; setZkappUri : auth_required Js.prop
    ; editSequenceState : auth_required Js.prop
    ; setTokenSymbol : auth_required Js.prop
    ; incrementNonce : auth_required Js.prop
    ; setVotingFor : auth_required Js.prop >
    Js.t

  type party_update =
    < appState : js_field set_or_keep Js.js_array Js.t Js.prop
    ; delegate : public_key set_or_keep Js.prop
    ; permissions : permissions set_or_keep Js.prop
    ; verificationKey : Js.js_string Js.t set_or_keep Js.prop
    ; votingFor : js_field set_or_keep Js.prop >
    Js.t

  type js_int64 = < uint64Value : js_field Js.meth > Js.t

  type timing_info =
    < initialMinimumBalance : js_uint64 Js.prop
    ; cliffTime : js_uint32 Js.prop
    ; cliffAmount : js_uint64 Js.prop
    ; vestingPeriod : js_uint32 Js.prop
    ; vestingIncrement : js_uint64 Js.prop >
    Js.t

  type full_account_precondition =
    < balance : js_uint64 closed_interval Js.prop
    ; nonce : js_uint32 closed_interval Js.prop
    ; receiptChainHash : js_field or_ignore Js.prop
    ; publicKey : public_key or_ignore Js.prop
    ; delegate : public_key or_ignore Js.prop
    ; state : js_field or_ignore Js.js_array Js.t Js.prop
    ; sequenceState : js_field or_ignore Js.prop
    ; provedState : bool_class Js.t or_ignore Js.prop >
    Js.t

  module Account_precondition = struct
    type precondition

    type t =
      < kind : Js.js_string Js.t Js.prop ; value : precondition Js.prop > Js.t
  end

  type party_body =
    < publicKey : public_key Js.prop
    ; update : party_update Js.prop
    ; tokenId : js_field Js.prop
    ; delta : js_int64 Js.prop
    ; events : js_field Js.js_array Js.t Js.js_array Js.t Js.prop
    ; sequenceEvents : js_field Js.js_array Js.t Js.js_array Js.t Js.prop
    ; callData : js_field Js.prop
    ; depth : int Js.prop
    ; protocolState : protocol_state_predicate Js.prop
    ; accountPrecondition : Account_precondition.t Js.prop
    ; useFullCommitment : js_bool Js.prop
    ; incrementNonce : js_bool Js.prop >
    Js.t

  type fee_payer_party_body =
    < publicKey : public_key Js.prop
    ; update : party_update Js.prop
    ; tokenId : js_field Js.prop
    ; delta : js_int64 Js.prop
    ; events : js_field Js.js_array Js.t Js.js_array Js.t Js.prop
    ; sequenceEvents : js_field Js.js_array Js.t Js.js_array Js.t Js.prop
    ; callData : js_field Js.prop
    ; depth : int Js.prop
    ; protocolState : protocol_state_predicate Js.prop
    ; accountPrecondition : js_uint32 Js.prop
    ; useFullCommitment : js_bool Js.prop
    ; incrementNonce : js_bool Js.prop >
    Js.t

  module Party_authorization = struct
    type authorization

    type t =
      < kind : Js.js_string Js.t Js.prop ; value : authorization Js.prop > Js.t
  end

  type party =
    < body : party_body Js.prop
    ; authorization : Party_authorization.t Js.prop >
    Js.t

  type fee_payer_party =
    < body : fee_payer_party_body Js.prop
    ; authorization : Party_authorization.t Js.prop >
    Js.t

  type parties =
    < feePayer : fee_payer_party Js.prop
    ; otherParties : party Js.js_array Js.t Js.prop >
    Js.t

  type zkapp_account =
    < appState : js_field Js.js_array Js.t Js.readonly_prop > Js.t

  type account =
    < publicKey : group_class Js.t Js.readonly_prop
    ; balance : js_uint64 Js.readonly_prop
    ; nonce : js_uint32 Js.readonly_prop
    ; zkapp : zkapp_account Js.readonly_prop >
    Js.t

  let ledger_class : < .. > Js.t =
    Js.Unsafe.eval_string {js|(function(v) { this.value = v; return this })|js}

  let loose_permissions : Mina_base.Permissions.t =
    { edit_state = None
    ; send = None
    ; receive = None
    ; set_delegate = None
    ; set_permissions = None
    ; set_verification_key = None
    ; set_zkapp_uri = None
    ; edit_sequence_state = None
    ; set_token_symbol = None
    ; increment_nonce = None
    ; set_voting_for = None
    }

  module L : Mina_base.Ledger_intf.S = struct
    module Account = Mina_base.Account
    module Account_id = Mina_base.Account_id
    module Ledger_hash = Mina_base.Ledger_hash
    module Token_id = Mina_base.Token_id

    type t_ =
      { next_location : int
      ; accounts : Account.t Int.Map.t
      ; locations : int Account_id.Map.t
      }

    type t = t_ ref

    type location = int

    let get (t : t) (loc : location) : Account.t option =
      Map.find !t.accounts loc

    let location_of_account (t : t) (a : Account_id.t) : location option =
      Map.find !t.locations a

    let set (t : t) (loc : location) (a : Account.t) : unit =
      t := { !t with accounts = Map.set !t.accounts ~key:loc ~data:a }

    let next_location (t : t) : int =
      let loc = !t.next_location in
      t := { !t with next_location = loc + 1 } ;
      loc

    let get_or_create (t : t) (id : Account_id.t) :
        (Mina_base.Ledger_intf.account_state * Account.t * location) Or_error.t
        =
      let loc = location_of_account t id in
      let res =
        match loc with
        | None ->
            let loc = next_location t in
            let a =
              { (Account.create id Currency.Balance.zero) with
                permissions = loose_permissions
              }
            in
            t := { !t with locations = Map.set !t.locations ~key:id ~data:loc } ;
            set t loc a ;
            (`Added, a, loc)
        | Some loc ->
            (`Existed, Option.value_exn (get t loc), loc)
      in
      Ok res

    let create_new_account (t : t) (id : Account_id.t) (a : Account.t) :
        unit Or_error.t =
      match location_of_account t id with
      | Some _ ->
          Or_error.errorf !"account %{sexp: Account_id.t} already present" id
      | None ->
          let loc = next_location t in
          t := { !t with locations = Map.set !t.locations ~key:id ~data:loc } ;
          set t loc a ;
          Ok ()

    let remove_accounts_exn (t : t) (ids : Account_id.t list) : unit =
      let locs = List.filter_map ids ~f:(fun id -> Map.find !t.locations id) in
      t :=
        { !t with
          locations = List.fold ids ~init:!t.locations ~f:Map.remove
        ; accounts = List.fold locs ~init:!t.accounts ~f:Map.remove
        }

    (* TODO *)
    let merkle_root (_ : t) : Ledger_hash.t = Field.Constant.zero

    let empty ~depth:_ () : t =
      ref
        { next_location = 0
        ; accounts = Int.Map.empty
        ; locations = Account_id.Map.empty
        }

    let with_ledger (type a) ~depth ~(f : t -> a) : a = f (empty ~depth ())

    let create_masked (t : t) : t = ref !t

    let apply_mask (t : t) ~(masked : t) = t := !masked
  end

  module T = Mina_transaction_logic.Make (L)

  type ledger_class = < value : L.t Js.prop >

  let ledger_constr : (L.t -> ledger_class Js.t) Js.constr =
    Obj.magic ledger_class

  let create_new_account_exn (t : L.t) account_id account =
    L.create_new_account t account_id account |> Or_error.ok_exn

  module Zkapp_precondition = Mina_base.Zkapp_precondition
  module Party = Mina_base.Party
  module Parties = Mina_base.Parties
  module Zkapp_state = Mina_base.Zkapp_state
  module Token_id = Mina_base.Token_id
  module Zkapp_basic = Mina_base.Zkapp_basic

  let max_uint32 = Field.constant @@ Field.Constant.of_string "4294967295"

  let max_uint64 =
    Field.constant @@ Field.Constant.of_string "18446744073709551615"

  let js_uint_zero =
    object%js
      val value = to_js_field Field.zero
    end

  let js_max_uint32 : js_uint32 =
    object%js
      val value = to_js_field max_uint32
    end

  let js_max_uint64 : js_uint64 =
    object%js
      val value = to_js_field max_uint64
    end

  let max_interval_uint32 : js_uint32 closed_interval =
    object%js
      val mutable lower = js_uint_zero

      val mutable upper = js_max_uint32
    end

  let max_interval_uint64 : js_uint64 closed_interval =
    object%js
      val mutable lower = js_uint_zero

      val mutable upper = js_max_uint64
    end

  let field (x : js_field) : Impl.field =
    match x##.value with Constant x -> x | x -> As_prover.read_var x

  let public_key (pk : public_key) : Signature_lib.Public_key.Compressed.t =
    { x = field pk##.g##.x
    ; is_odd = Bigint.(test_bit (of_field (field pk##.g##.y)) 0)
    }

  let private_key (key : private_key) : Signature_lib.Private_key.t =
    Js.Optdef.case
      key##.s##.constantValue
      (fun () -> failwith "invalid scalar")
      Fn.id

  let uint32 (x : js_uint32) =
    Unsigned.UInt32.of_string (Field.Constant.to_string (field x##.value))

  let uint64 (x : js_uint64) =
    Unsigned.UInt64.of_string (Field.Constant.to_string (field x##.value))

  let int64 (x : js_int64) =
    let x =
      x##uint64Value |> field |> Field.Constant.to_string
      |> Unsigned.UInt64.of_string
      |> (fun x -> x)
      |> Unsigned.UInt64.to_int64
    in
    { Currency.Signed_poly.sgn =
        (if Int64.is_negative x then Sgn.Neg else Sgn.Pos)
    ; magnitude =
        Currency.Amount.of_uint64 (Unsigned.UInt64.of_int64 (Int64.abs x))
    }

  let bool (x : js_bool) = Js.to_bool x##toBoolean

  let or_ignore (type a) elt (x : a or_ignore) =
    if Js.to_bool x##.check##toBoolean then
      Zkapp_basic.Or_ignore.Check (elt x##.value)
    else Ignore

  let closed_interval f (c : 'a closed_interval) :
      _ Zkapp_precondition.Closed_interval.t =
    { lower = f c##.lower; upper = f c##.upper }

  let epoch_data (e : epoch_data_predicate) :
      Zkapp_precondition.Protocol_state.Epoch_data.t =
    let ( ^ ) = Fn.compose in
    { ledger =
        { hash = or_ignore field e##.ledger##.hash
        ; total_currency =
            Check
              (closed_interval
                 (Currency.Amount.of_uint64 ^ uint64)
                 e##.ledger##.totalCurrency)
        }
    ; seed = or_ignore field e##.seed
    ; start_checkpoint = or_ignore field e##.startCheckpoint
    ; lock_checkpoint = or_ignore field e##.lockCheckpoint
    ; epoch_length =
        Check
          (closed_interval
             (Mina_numbers.Length.of_uint32 ^ uint32)
             e##.epochLength)
    }

  let predicate (t : Account_precondition.t) : Party.Account_precondition.t =
    match Js.to_string t##.kind with
    | "accept" ->
        Accept
    | "nonce" ->
        Nonce
          (Mina_numbers.Account_nonce.of_uint32
             (uint32 (Obj.magic t##.value : js_uint32)))
    | "full" ->
        let p : full_account_precondition = Obj.magic t##.value in
        Full
          { balance =
              Check
                (closed_interval
                   (Fn.compose Currency.Balance.of_uint64 uint64)
                   p##.balance)
          ; nonce =
              Check
                (closed_interval
                   (Fn.compose Mina_numbers.Account_nonce.of_uint32 uint32)
                   p##.nonce)
          ; receipt_chain_hash = or_ignore field p##.receiptChainHash
          ; delegate = or_ignore public_key p##.delegate
          ; state =
              Pickles_types.Vector.init Zkapp_state.Max_state_size.n
                ~f:(fun i -> or_ignore field (array_get_exn p##.state i))
          ; sequence_state = or_ignore field p##.sequenceState
          ; proved_state =
              or_ignore (fun x -> Js.to_bool x##toBoolean) p##.provedState
          }
    | s ->
        failwithf "bad predicate type: %s" s ()

  let protocol_state (p : protocol_state_predicate) :
      Zkapp_precondition.Protocol_state.t =
    let ( ^ ) = Fn.compose in
    { snarked_ledger_hash = or_ignore field p##.snarkedLedgerHash
    ; timestamp =
        Ignore
        (* Check (closed_interval (Block_time.of_uint64 ^ uint64) p##.timestamp) *)
    ; blockchain_length =
        Check
          (closed_interval
             (Mina_numbers.Length.of_uint32 ^ uint32)
             p##.blockchainLength)
    ; min_window_density =
        Check
          (closed_interval
             (Mina_numbers.Length.of_uint32 ^ uint32)
             p##.minWindowDensity)
    ; last_vrf_output = ()
    ; total_currency =
        Check
          (closed_interval
             (Currency.Amount.of_uint64 ^ uint64)
             p##.totalCurrency)
    ; global_slot_since_hard_fork =
        Check
          (closed_interval
             (Mina_numbers.Global_slot.of_uint32 ^ uint32)
             p##.globalSlotSinceHardFork)
    ; global_slot_since_genesis =
        Check
          (closed_interval
             (Mina_numbers.Global_slot.of_uint32 ^ uint32)
             p##.globalSlotSinceGenesis)
    ; staking_epoch_data = epoch_data p##.stakingEpochData
    ; next_epoch_data = epoch_data p##.nextEpochData
    }

  let set_or_keep (type a) elt (x : a set_or_keep) =
    if Js.to_bool x##.set##toBoolean then
      Zkapp_basic.Set_or_keep.Set (elt x##.value)
    else Keep

  let verification_key_with_hash (vk_artifact : Js.js_string Js.t) =
    let vk =
      Pickles.Side_loaded.Verification_key.of_base58_check_exn
        (Js.to_string vk_artifact)
    in
    { With_hash.data = vk; hash = Mina_base.Zkapp_account.digest_vk vk }

  let auth_required (auth : auth_required) :
      Mina_base.Permissions.Auth_required.t =
    match
      ( bool auth##.constant
      , bool auth##.signatureNecessary
      , bool auth##.signatureSufficient )
    with
    | true, _, false ->
        Impossible
    | true, _, true ->
        None
    | false, false, false ->
        Proof
    | false, true, true ->
        Signature
    | false, false, true ->
        Either
    | false, true, false ->
        failwith
          "Permissions: Found encoding of Both, but Both is not an exposed \
           option"

  let permissions (p : permissions) : Mina_base.Permissions.t =
    { edit_state = auth_required p##.editState
    ; send = auth_required p##.send
    ; receive = auth_required p##.receive
    ; set_delegate = auth_required p##.setDelegate
    ; set_permissions = auth_required p##.setPermissions
    ; set_verification_key = auth_required p##.setVerificationKey
    ; set_zkapp_uri = auth_required p##.setZkappUri
    ; edit_sequence_state = auth_required p##.editSequenceState
    ; set_token_symbol = auth_required p##.setTokenSymbol
    ; increment_nonce = auth_required p##.incrementNonce
    ; set_voting_for = auth_required p##.setVotingFor
    }

  let update (u : party_update) : Party.Update.t =
    { app_state =
        Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
            set_or_keep field (array_get_exn u##.appState i))
    ; delegate = set_or_keep public_key u##.delegate
    ; verification_key =
        set_or_keep verification_key_with_hash u##.verificationKey
    ; permissions = set_or_keep permissions u##.permissions
    ; zkapp_uri = Keep (* TODO *)
    ; token_symbol = Keep (* TODO *)
    ; timing = Keep (* TODO *)
    ; voting_for = Keep (* TODO *)
    }

  let body (b : party_body) : Party.Body.t =
    { public_key = public_key b##.publicKey
    ; update = update b##.update
    ; token_id = Token_id.of_field (field b##.tokenId)
    ; balance_change = int64 b##.delta
    ; events =
        Array.map
          (Js.to_array b##.events)
          ~f:(fun a -> Array.map (Js.to_array a) ~f:field)
        |> Array.to_list
    ; sequence_events =
        Array.map
          (Js.to_array b##.sequenceEvents)
          ~f:(fun a -> Array.map (Js.to_array a) ~f:field)
        |> Array.to_list
    ; call_data = field b##.callData
    ; call_depth = b##.depth
    ; increment_nonce = bool b##.incrementNonce
    ; use_full_commitment = bool b##.useFullCommitment
    ; protocol_state_precondition = protocol_state b##.protocolState
    ; account_precondition = predicate b##.accountPrecondition
    ; caller = (* TODO *)
               Token_id.default
    }

  let fee_payer_body (b : fee_payer_party_body) : Party.Body.Fee_payer.t =
    { public_key = public_key b##.publicKey
    ; update = update b##.update
    ; token_id = ()
    ; balance_change = Currency.Amount.to_fee (int64 b##.delta).magnitude
    ; events =
        Array.map
          (Js.to_array b##.events)
          ~f:(fun a -> Array.map (Js.to_array a) ~f:field)
        |> Array.to_list
    ; sequence_events =
        Array.map
          (Js.to_array b##.sequenceEvents)
          ~f:(fun a -> Array.map (Js.to_array a) ~f:field)
        |> Array.to_list
    ; call_data = field b##.callData
    ; call_depth = b##.depth
    ; increment_nonce = ()
    ; use_full_commitment = ()
    ; protocol_state_precondition = protocol_state b##.protocolState
    ; account_precondition =
        uint32 b##.accountPrecondition |> Mina_numbers.Account_nonce.of_uint32
    ; caller = ()
    }

  let predicate (t : Account_precondition.t) : Party.Account_precondition.t =
    match Js.to_string t##.kind with
    | "accept" ->
        Accept
    | "nonce" ->
        Nonce
          (Mina_numbers.Account_nonce.of_uint32
             (uint32 (Obj.magic t##.value : js_uint32)))
    | "full" ->
        let p : full_account_precondition = Obj.magic t##.value in
        Full
          { balance =
              Check
                (closed_interval
                   (Fn.compose Currency.Balance.of_uint64 uint64)
                   p##.balance)
          ; nonce =
              Check
                (closed_interval
                   (Fn.compose Mina_numbers.Account_nonce.of_uint32 uint32)
                   p##.nonce)
          ; receipt_chain_hash = or_ignore field p##.receiptChainHash
          ; delegate = or_ignore public_key p##.delegate
          ; state =
              Pickles_types.Vector.init Zkapp_state.Max_state_size.n
                ~f:(fun i -> or_ignore field (array_get_exn p##.state i))
          ; sequence_state = or_ignore field p##.sequenceState
          ; proved_state =
              or_ignore (fun x -> Js.to_bool x##toBoolean) p##.provedState
          }
    | s ->
        failwithf "bad predicate type: %s" s ()

  let party_body (party : party) : Party.Body.t = body party##.body

  let fee_payer_party_body (party : fee_payer_party) : Party.Body.Fee_payer.t =
    fee_payer_body party##.body

  let token_id (str : Js.js_string Js.t) : Token_id.t =
    Token_id.of_string (Js.to_string str)

  let authorization (a : Party_authorization.t) : Mina_base.Control.t =
    match Js.to_string a##.kind with
    | "none" ->
        None_given
    | "signature" ->
        let signature : Js.js_string Js.t = Obj.magic a##.value in
        Signature
          (Mina_base.Signature.of_base58_check_exn (Js.to_string signature))
    | "proof" -> (
        let proof_string = Js.to_string @@ Obj.magic a##.value in
        let proof_yojson = Yojson.Safe.from_string proof_string in
        match Pickles.Side_loaded.Proof.of_yojson proof_yojson with
        | Ppx_deriving_yojson_runtime.Result.Ok p ->
            Proof p
        | Ppx_deriving_yojson_runtime.Result.Error s ->
            failwith s )
    | s ->
        failwithf "bad authorization type: %s" s ()

  let fee_payer_authorization (a : Party_authorization.t) :
      Mina_base.Signature.t =
    match Js.to_string a##.kind with
    | "none" ->
        Mina_base.Signature.dummy
    | "signature" ->
        let signature : Js.js_string Js.t = Obj.magic a##.value in
        Mina_base.Signature.of_base58_check_exn (Js.to_string signature)
    | s ->
        failwithf "bad authorization type: %s" s ()

  let parties (parties : parties) : Parties.t =
    { fee_payer =
        { body = fee_payer_party_body parties##.feePayer
        ; authorization =
            fee_payer_authorization parties##.feePayer##.authorization
        }
    ; other_parties =
        Js.to_array parties##.otherParties
        |> Array.map ~f:(fun p : Party.t ->
               { body = body p##.body
               ; authorization = authorization p##.authorization
               })
        |> Array.to_list
        |> Parties.Call_forest.of_parties_list
             ~party_depth:(fun (p : Party.t) -> p.body.call_depth)
        |> Parties.Call_forest.accumulate_hashes
             ~hash_party:(fun (p : Party.t) -> Parties.Digest.Party.create p)
    ; memo = Mina_base.Signed_command_memo.empty
    }

  let account_id pk =
    Mina_base.Account_id.create (public_key pk) Token_id.default

  let max_state_size = Pickles_types.Nat.to_int Zkapp_state.Max_state_size.n

  (*
     TODO: to de-scope initial version, the following types are converted
     by just assuming them to be constant and introducing witnesses out of thin air

     * public_key
     various hashes:
     * receipt_chain_hash in predicate
     * seed, start_checkpoint, lock_checkpoint in epoch_data
     * ledger_hash

     TODO: some set_or_keep types are not fully implemented yet, and we use keep with a dummy value
     see: party update
  *)
  module Checked = struct
    let field_value = field

    let field (x : js_field) = x##.value

    let bool (x : bool_class Js.t) = x##.value

    let public_key (pk : public_key) : Signature_lib.Public_key.Compressed.var =
      (* TODO this should work but seems inefficient.. should the checked public key really be compressed? *)
      (* Signature_lib.Public_key.Uncompressed.compress_var
         (field pk##.g##.x, field pk##.g##.y) *)
      { x = field pk##.g##.x
      ; is_odd =
          Impl.Boolean.var_of_value
            Bigint.(test_bit (of_field (field_value pk##.g##.y)) 0)
          (* TODO not checked ^^^ *)
      }

    let public_key_dummy () : Signature_lib.Public_key.Compressed.var =
      { x = Field.zero; is_odd = Boolean.false_ }

    let uint32 (x : js_uint32) : Field.t = field x##.value

    let uint64 (x : js_uint64) : Field.t = field x##.value

    let int64 (x : js_int64) =
      (* TODO replace with proper int64 impl which has a sign; rename these functions to signed_amount *)
      Currency.Amount.Signed.create_var
        ~magnitude:
          (Currency.Amount.Checked.Unsafe.of_field @@ field x##uint64Value)
        ~sgn:Sgn.Checked.pos

    let or_ignore (type a b) (transform : a -> b) (x : a or_ignore) =
      Zkapp_basic.Or_ignore.Checked.make_unsafe_explicit
        x##.check##.value
        (transform x##.value)

    let ignore (dummy : 'a) =
      Zkapp_basic.Or_ignore.Checked.make_unsafe_explicit Boolean.false_ dummy

    let numeric (type a b) (transform : a -> b) (x : a closed_interval) =
      Zkapp_basic.Or_ignore.Checked.make_unsafe_implicit
        { Zkapp_precondition.Closed_interval.lower = transform x##.lower
        ; upper = transform x##.upper
        }

    let numeric_equal (type a b) (transform : a -> b) (x : a) =
      let x' = transform x in
      Zkapp_basic.Or_ignore.Checked.make_unsafe_implicit
        { Zkapp_precondition.Closed_interval.lower = x'; upper = x' }

    let set_or_keep (type a b) (transform : a -> b) (x : a set_or_keep) :
        b Zkapp_basic.Set_or_keep.Checked.t =
      Zkapp_basic.Set_or_keep.Checked.make_unsafe
        x##.set##.value
        (transform x##.value)

    let keep dummy : 'a Zkapp_basic.Set_or_keep.Checked.t =
      Zkapp_basic.Set_or_keep.Checked.make_unsafe Boolean.false_ dummy

    let amount x = Currency.Amount.Checked.Unsafe.of_field @@ uint64 x

    let balance x = Currency.Balance.Checked.Unsafe.of_field @@ uint64 x

    let nonce x = Mina_numbers.Account_nonce.Checked.Unsafe.of_field @@ uint32 x

    let global_slot x =
      Mina_numbers.Global_slot.Checked.Unsafe.of_field @@ uint32 x

    let token_id x = Token_id.Checked.of_field @@ field x

    let ledger_hash x =
      (* TODO: assumes constant *)
      Mina_base.Frozen_ledger_hash.var_of_t @@ field_value x

    let epoch_data (e : epoch_data_predicate) :
        Zkapp_precondition.Protocol_state.Epoch_data.Checked.t =
      let ( ^ ) = Fn.compose in
      { ledger =
          { hash = or_ignore ledger_hash e##.ledger##.hash
          ; total_currency = numeric amount e##.ledger##.totalCurrency
          }
      ; (* TODO: next three all assume constant *)
        seed = or_ignore (Mina_base.Epoch_seed.var_of_t ^ field_value) e##.seed
      ; start_checkpoint =
          or_ignore
            (Mina_base.State_hash.var_of_t ^ field_value)
            e##.startCheckpoint
      ; lock_checkpoint =
          or_ignore
            (Mina_base.State_hash.var_of_t ^ field_value)
            e##.lockCheckpoint
      ; epoch_length =
          numeric
            (Mina_numbers.Length.Checked.Unsafe.of_field ^ uint32)
            e##.epochLength
      }

    let protocol_state (p : protocol_state_predicate) :
        Zkapp_precondition.Protocol_state.Checked.t =
      let ( ^ ) = Fn.compose in

      { snarked_ledger_hash = or_ignore ledger_hash p##.snarkedLedgerHash
      ; timestamp =
          numeric (Block_time.Checked.Unsafe.of_field ^ uint64) p##.timestamp
      ; blockchain_length =
          numeric
            (Mina_numbers.Length.Checked.Unsafe.of_field ^ uint32)
            p##.blockchainLength
      ; min_window_density =
          numeric
            (Mina_numbers.Length.Checked.Unsafe.of_field ^ uint32)
            p##.minWindowDensity
      ; last_vrf_output = ()
      ; total_currency = numeric amount p##.totalCurrency
      ; global_slot_since_hard_fork =
          numeric global_slot p##.globalSlotSinceHardFork
      ; global_slot_since_genesis =
          numeric global_slot p##.globalSlotSinceGenesis
      ; staking_epoch_data = epoch_data p##.stakingEpochData
      ; next_epoch_data = epoch_data p##.nextEpochData
      }

    let predicate_accept () : Party.Account_precondition.Checked.t =
      let pk_dummy = public_key_dummy () in
      { balance = numeric balance max_interval_uint64
      ; nonce = numeric nonce max_interval_uint32
      ; receipt_chain_hash =
          ignore (Mina_base.Receipt.Chain_hash.var_of_hash_packed Field.zero)
      ; delegate = ignore pk_dummy
      ; state =
          Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun _ ->
              ignore Field.zero)
      ; sequence_state = ignore Field.zero
      ; proved_state = ignore Boolean.false_
      }

    let predicate (t : Account_precondition.t) :
        Party.Account_precondition.Checked.t =
      match Js.to_string t##.kind with
      | "accept" ->
          predicate_accept ()
      | "nonce" ->
          let nonce_js : js_uint32 = Obj.magic t##.value in
          { (predicate_accept ()) with nonce = numeric_equal nonce nonce_js }
      | "full" ->
          let ( ^ ) = Fn.compose in
          let p : full_account_precondition = Obj.magic t##.value in
          { balance = numeric balance p##.balance
          ; nonce = numeric nonce p##.nonce
          ; receipt_chain_hash =
              or_ignore
                (* TODO: assumes constant *)
                (Mina_base.Receipt.Chain_hash.var_of_t ^ field_value)
                p##.receiptChainHash
          ; delegate = or_ignore public_key p##.delegate
          ; state =
              Pickles_types.Vector.init Zkapp_state.Max_state_size.n
                ~f:(fun i -> or_ignore field (array_get_exn p##.state i))
          ; sequence_state = or_ignore field p##.sequenceState
          ; proved_state = or_ignore bool p##.provedState
          }
      | s ->
          failwithf "bad predicate type: %s" s ()

    let timing_info_dummy () : Party.Update.Timing_info.Checked.t =
      { initial_minimum_balance =
          Currency.Balance.Checked.Unsafe.of_field Field.zero
      ; cliff_time = Mina_numbers.Global_slot.Checked.Unsafe.of_field Field.zero
      ; cliff_amount = Currency.Amount.Checked.Unsafe.of_field Field.zero
      ; vesting_period =
          Mina_numbers.Global_slot.Checked.Unsafe.of_field Field.zero
      ; vesting_increment = Currency.Amount.Checked.Unsafe.of_field Field.zero
      }

    let events (js_events : js_field Js.js_array Js.t Js.js_array Js.t) =
      let events =
        Impl.exists Mina_base.Zkapp_account.Events.typ ~compute:(fun () -> [])
      in
      let push_event js_event =
        let event = Array.map (Js.to_array js_event) ~f:field in
        let _ = Mina_base.Zkapp_account.Events.push_checked events event in
        ()
      in
      Array.iter (Js.to_array js_events) ~f:push_event ;
      events

    let body (b : party_body) : Party.Body.Checked.t =
      let update : Party.Update.Checked.t =
        let u = b##.update in
        { app_state =
            Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
                set_or_keep field (array_get_exn u##.appState i))
        ; delegate = set_or_keep public_key u##.delegate
        ; (* TODO *) verification_key =
            keep
              { Zkapp_basic.Flagged_option.is_some = Boolean.false_
              ; data =
                  Mina_base.Data_as_hash.make_unsafe
                    (Field.constant @@ Mina_base.Zkapp_account.dummy_vk_hash ())
                    (As_prover.Ref.create (fun () ->
                         { With_hash.data = None; hash = Field.Constant.zero }))
              }
        ; permissions = keep Mina_base.Permissions.(Checked.constant empty)
        ; zkapp_uri =
            keep
              (Mina_base.Data_as_hash.make_unsafe Field.zero
                 (As_prover.Ref.create (fun () -> "")))
        ; token_symbol = keep Field.zero
        ; timing = keep (timing_info_dummy ())
        ; voting_for =
            Zkapp_basic.Set_or_keep.Checked.map
              (set_or_keep field u##.votingFor)
              ~f:Mina_base.State_hash.var_of_hash_packed
        }
      in
      { public_key = public_key b##.publicKey
      ; update
      ; token_id = token_id b##.tokenId
      ; balance_change = int64 b##.delta
      ; events = events b##.events
      ; sequence_events = events b##.sequenceEvents
      ; call_data = field b##.callData
      ; call_depth = As_prover.Ref.create (fun () -> b##.depth)
      ; increment_nonce = bool b##.incrementNonce
      ; use_full_commitment = bool b##.useFullCommitment
      ; protocol_state_precondition = protocol_state b##.protocolState
      ; account_precondition = predicate b##.accountPrecondition
      ; caller = (*TODO*) Token_id.Checked.constant Token_id.default
      }

    let fee_payer_body (b : fee_payer_party_body) : Party.Body.Checked.t =
      let account_precondition =
        let nonce_js : js_uint32 = Obj.magic b##.accountPrecondition##.value in
        { (predicate_accept ()) with nonce = numeric_equal nonce nonce_js }
      in
      (*TODO: duplicated most of the function body above*)
      let update : Party.Update.Checked.t =
        let u = b##.update in
        { app_state =
            Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
                set_or_keep field (array_get_exn u##.appState i))
        ; delegate = set_or_keep public_key u##.delegate
        ; (* TODO *) verification_key =
            keep
              { Zkapp_basic.Flagged_option.is_some = Boolean.false_
              ; data =
                  Mina_base.Data_as_hash.make_unsafe
                    (Field.constant @@ Mina_base.Zkapp_account.dummy_vk_hash ())
                    (As_prover.Ref.create (fun () ->
                         { With_hash.data = None; hash = Field.Constant.zero }))
              }
        ; permissions = keep Mina_base.Permissions.(Checked.constant empty)
        ; zkapp_uri =
            keep
              (Mina_base.Data_as_hash.make_unsafe Field.zero
                 (As_prover.Ref.create (fun () -> "")))
        ; token_symbol = keep Field.zero
        ; timing = keep (timing_info_dummy ())
        ; voting_for =
            Zkapp_basic.Set_or_keep.Checked.map
              (set_or_keep field u##.votingFor)
              ~f:Mina_base.State_hash.var_of_hash_packed
        }
      in
      { public_key = public_key b##.publicKey
      ; update
      ; token_id = token_id b##.tokenId
      ; balance_change = int64 b##.delta
      ; events = events b##.events
      ; sequence_events = events b##.sequenceEvents
      ; call_data = field b##.callData
      ; call_depth = As_prover.Ref.create (fun () -> b##.depth)
      ; increment_nonce = bool b##.incrementNonce
      ; use_full_commitment = bool b##.useFullCommitment
      ; protocol_state_precondition = protocol_state b##.protocolState
      ; account_precondition
      ; caller = (*TODO*) Token_id.Checked.constant Token_id.default
      }

    let fee_payer_party (party : fee_payer_party) : Party.Checked.t =
      (* TODO: is it OK that body is the same for fee_payer as for party?
           what about fee vs. delta and other differences in the unchecked version?*)
      fee_payer_body party##.body

    let party (party : party) : Party.Checked.t = body party##.body
  end

  module To_js = struct
    let field x = to_js_field @@ Field.constant x

    let uint32 n =
      object%js
        val value =
          Unsigned.UInt32.to_string n |> Field.Constant.of_string |> field
      end

    let uint64 n =
      object%js
        val value =
          Unsigned.UInt64.to_string n |> Field.Constant.of_string |> field
      end

    let app_state (a : Mina_base.Account.t) =
      let xs = new%js Js.array_empty in
      ( match a.zkapp with
      | Some s ->
          Pickles_types.Vector.iter s.app_state ~f:(fun x ->
              ignore (xs##push (field x)))
      | None ->
          for _ = 0 to max_state_size - 1 do
            xs##push (field Field.Constant.zero) |> ignore
          done ) ;
      xs

    let public_key (pk : Signature_lib.Public_key.Compressed.t) =
      let x, y = Signature_lib.Public_key.decompress_exn pk in
      to_js_group (Field.constant x) (Field.constant y)

    let private_key (sk : Signature_lib.Private_key.t) = to_js_scalar sk

    let signature (sg : Signature_lib.Schnorr.Chunked.Signature.t) =
      let r, s = sg in
      object%js
        val r = to_js_field_unchecked r

        val s = to_js_scalar s
      end

    let account (a : Mina_base.Account.t) : account =
      object%js
        val publicKey = public_key a.public_key

        val balance = uint64 (Currency.Balance.to_uint64 a.balance)

        val nonce = uint32 (Mina_numbers.Account_nonce.to_uint32 a.nonce)

        val zkapp =
          object%js
            val appState = app_state a
          end
      end

    let option (transform : 'a -> 'b) (x : 'a option) =
      Js.Optdef.option (Option.map x ~f:transform)
  end

  (* TODO hash two parties together in the correct way *)

  let hash_party (p : party) =
    let party =
      (*using dummy authorization to construct Party.t. Alternatively, one
        could use Party.Body.digest which is what Party.digest calls*)
      { Party.body = p |> party_body
      ; authorization = Signature Mina_base.Signature.dummy
      }
    in
    Party.digest party |> Field.constant |> to_js_field

  let hash_party_checked p =
    p |> Checked.party |> Party.Checked.digest |> to_js_field

  let hash_protocol_state (p : protocol_state_predicate) =
    p |> protocol_state |> Zkapp_precondition.Protocol_state.digest
    |> Field.constant |> to_js_field

  let hash_protocol_state_checked (p : protocol_state_predicate) =
    p |> Checked.protocol_state
    |> Zkapp_precondition.Protocol_state.Checked.digest |> to_js_field

  let forest_digest_of_field : Field.Constant.t -> Parties.Digest.Forest.t =
    Obj.magic

  let forest_digest_of_field_checked :
      Field.t -> Parties.Digest.Forest.Checked.t =
    Obj.magic

  let hash_transaction other_parties_hash =
    let other_parties_hash =
      other_parties_hash |> of_js_field |> to_unchecked
      |> forest_digest_of_field
    in
    Parties.Transaction_commitment.create ~other_parties_hash
    |> Field.constant |> to_js_field

  let hash_transaction_checked other_parties_hash =
    let other_parties_hash =
      other_parties_hash |> of_js_field |> forest_digest_of_field_checked
    in
    Parties.Transaction_commitment.Checked.create ~other_parties_hash
    |> to_js_field

  type party_index = Fee_payer | Other_party of int

  let transaction_commitment
      ({ fee_payer; other_parties; memo } as tx : Parties.t)
      (party_index : party_index) =
    let commitment = Parties.commitment tx in
    let full_commitment =
      Parties.Transaction_commitment.create_complete commitment
        ~memo_hash:(Mina_base.Signed_command_memo.hash memo)
        ~fee_payer_hash:
          (Parties.Digest.Party.create (Party.of_fee_payer fee_payer))
    in
    let use_full_commitment =
      match party_index with
      | Fee_payer ->
          true
      | Other_party i ->
          (List.nth_exn (Parties.Call_forest.to_parties_list other_parties) i)
            .body
            .use_full_commitment
    in
    if use_full_commitment then full_commitment else commitment

  let transaction_commitments (tx_json : Js.js_string Js.t) =
    let tx =
      Parties.of_json @@ Yojson.Safe.from_string @@ Js.to_string tx_json
    in
    let commitment = Parties.commitment tx in
    let full_commitment =
      Parties.Transaction_commitment.create_complete commitment
        ~memo_hash:(Mina_base.Signed_command_memo.hash tx.memo)
        ~fee_payer_hash:
          (Parties.Digest.Party.create (Party.of_fee_payer tx.fee_payer))
    in
    object%js
      val commitment = to_js_field_unchecked commitment

      val fullCommitment = to_js_field_unchecked full_commitment
    end

  let transaction_statement (tx_json : Js.js_string Js.t) (party_index : int) =
    let tx =
      Parties.of_json @@ Yojson.Safe.from_string @@ Js.to_string tx_json
    in
    let at_party =
      let ps = List.drop tx.other_parties party_index in
      (Parties.Call_forest.hash ps :> Impl.field)
    in
    let transaction = transaction_commitment tx (Other_party party_index) in
    Zkapp_statement.Constant.to_js { transaction; at_party }

  let sign_field_element (x : js_field) (key : private_key) =
    Signature_lib.Schnorr.Chunked.sign (private_key key)
      (Random_oracle.Input.Chunked.field (x |> of_js_field |> to_unchecked))
    |> Mina_base.Signature.to_base58_check |> Js.string

  let sign_party (tx_json : Js.js_string Js.t) (key : private_key)
      (party_index : party_index) =
    let tx =
      Parties.of_json @@ Yojson.Safe.from_string @@ Js.to_string tx_json
    in
    let signature =
      Signature_lib.Schnorr.Chunked.sign (private_key key)
        (Random_oracle.Input.Chunked.field
           (transaction_commitment tx party_index))
    in
    ( match party_index with
    | Fee_payer ->
        { tx with fee_payer = { tx.fee_payer with authorization = signature } }
    | Other_party i ->
        { tx with
          other_parties =
            Parties.Call_forest.mapi tx.other_parties
              ~f:(fun i' (p : Party.t) ->
                if i' = i then { p with authorization = Signature signature }
                else p)
        } )
    |> Parties.to_json |> Yojson.Safe.to_string |> Js.string

  let sign_fee_payer tx_json key = sign_party tx_json key Fee_payer

  let sign_other_party tx_json key i = sign_party tx_json key (Other_party i)

  let check_party_signatures parties =
    let ({ fee_payer; other_parties; memo } : Parties.t) = parties in
    let tx_commitment = Parties.commitment parties in
    let full_tx_commitment =
      Parties.Transaction_commitment.create_complete tx_commitment
        ~memo_hash:(Mina_base.Signed_command_memo.hash memo)
        ~fee_payer_hash:
          (Parties.Digest.Party.create (Party.of_fee_payer fee_payer))
    in
    let key_to_string = Signature_lib.Public_key.Compressed.to_base58_check in
    let check_signature who s pk msg =
      match Signature_lib.Public_key.decompress pk with
      | None ->
          failwith
            (sprintf "Check signature: Invalid key on %s: %s" who
               (key_to_string pk))
      | Some pk_ ->
          if
            not
              (Signature_lib.Schnorr.Chunked.verify s
                 (Kimchi_pasta.Pasta.Pallas.of_affine pk_)
                 (Random_oracle_input.Chunked.field msg))
          then
            failwith
              (sprintf "Check signature: Invalid signature on %s for key %s" who
                 (key_to_string pk))
          else ()
    in

    check_signature "fee payer" fee_payer.authorization
      fee_payer.body.public_key full_tx_commitment ;
    List.iteri (Parties.Call_forest.to_parties_list other_parties)
      ~f:(fun i p ->
        let commitment =
          if p.body.use_full_commitment then full_tx_commitment
          else tx_commitment
        in
        match p.authorization with
        | Signature s ->
            check_signature (sprintf "party %d" i) s p.body.public_key
              commitment
        | Proof _ | None_given ->
            ())

  let public_key_to_string (pk : public_key) : Js.js_string Js.t =
    pk |> public_key |> Signature_lib.Public_key.Compressed.to_base58_check
    |> Js.string

  let public_key_of_string (pk_base58 : Js.js_string Js.t) : group_class Js.t =
    pk_base58 |> Js.to_string
    |> Signature_lib.Public_key.Compressed.of_base58_check_exn
    |> To_js.public_key

  let private_key_to_string (sk : private_key) : Js.js_string Js.t =
    sk |> private_key |> Signature_lib.Private_key.to_base58_check |> Js.string

  let private_key_of_string (sk_base58 : Js.js_string Js.t) : scalar_class Js.t
      =
    sk_base58 |> Js.to_string |> Signature_lib.Private_key.of_base58_check_exn
    |> To_js.private_key

  let add_account_exn (l : L.t) pk (balance : string) =
    let account_id = account_id pk in
    let bal_u64 = Unsigned.UInt64.of_string balance in
    let balance = Currency.Balance.of_uint64 bal_u64 in
    let a : Mina_base.Account.t =
      { (Mina_base.Account.create account_id balance) with
        permissions = loose_permissions
      }
    in
    create_new_account_exn l account_id a

  let create
      (genesis_accounts :
        < publicKey : public_key Js.prop ; balance : Js.js_string Js.t Js.prop >
        Js.t
        Js.js_array
        Js.t) : ledger_class Js.t =
    let l = L.empty ~depth:20 () in
    array_iter genesis_accounts ~f:(fun a ->
        add_account_exn l a##.publicKey (Js.to_string a##.balance)) ;
    new%js ledger_constr l

  let get_account l (pk : public_key) : account Js.optdef =
    let loc = L.location_of_account l##.value (account_id pk) in
    let account = Option.bind loc ~f:(L.get l##.value) in
    To_js.option To_js.account account

  let add_account l (pk : public_key) (balance : Js.js_string Js.t) =
    add_account_exn l##.value pk (Js.to_string balance)

  let dummy_state_view : Zkapp_precondition.Protocol_state.View.t =
    let epoch_data =
      { Zkapp_precondition.Protocol_state.Epoch_data.Poly.ledger =
          { Mina_base.Epoch_ledger.Poly.hash = Field.Constant.zero
          ; total_currency = Currency.Amount.zero
          }
      ; seed = Field.Constant.zero
      ; start_checkpoint = Field.Constant.zero
      ; lock_checkpoint = Field.Constant.zero
      ; epoch_length = Mina_numbers.Length.zero
      }
    in
    { snarked_ledger_hash = Field.Constant.zero
    ; timestamp = Block_time.zero
    ; blockchain_length = Mina_numbers.Length.zero
    ; min_window_density = Mina_numbers.Length.zero
    ; last_vrf_output = ()
    ; total_currency = Currency.Amount.zero
    ; global_slot_since_hard_fork = Mina_numbers.Global_slot.zero
    ; global_slot_since_genesis = Mina_numbers.Global_slot.zero
    ; staking_epoch_data = epoch_data
    ; next_epoch_data = epoch_data
    }

  let deriver () = Parties.deriver @@ Fields_derivers_zkapps.Derivers.o ()

  let parties_to_json ps =
    parties ps |> !((deriver ())#to_json) |> Yojson.Safe.to_string |> Js.string

  let apply_parties_transaction l (txn : Parties.t)
      (account_creation_fee : string) =
    check_party_signatures txn ;
    let ledger = l##.value in
    let applied_exn =
      T.apply_parties_unchecked ~state_view:dummy_state_view
        ~constraint_constants:
          { Genesis_constants.Constraint_constants.compiled with
            account_creation_fee = Currency.Fee.of_string account_creation_fee
          }
        ledger txn
    in
    let applied, _ = Or_error.ok_exn applied_exn in
    let T.Transaction_applied.Parties_applied.{ accounts; command; _ } =
      applied
    in
    let () =
      match command.status with
      | Applied ->
          ()
      | Failed failures ->
          raise_error
            ( Mina_base.Transaction_status.Failure.Collection.to_yojson failures
            |> Yojson.Safe.to_string )
    in
    let account_list =
      List.map accounts ~f:(fun (_, a) -> To_js.option To_js.account a)
    in
    Js.array @@ Array.of_list account_list

  let apply_js_transaction l (p : parties)
      (account_creation_fee : Js.js_string Js.t) =
    apply_parties_transaction l (parties p) (Js.to_string account_creation_fee)

  let apply_json_transaction l (tx_json : Js.js_string Js.t)
      (account_creation_fee : Js.js_string Js.t) =
    let txn =
      Parties.of_json @@ Yojson.Safe.from_string @@ Js.to_string tx_json
    in
    apply_parties_transaction l txn (Js.to_string account_creation_fee)

  let () =
    let static_method name f =
      Js.Unsafe.set ledger_class (Js.string name) (Js.wrap_callback f)
    in
    let method_ name (f : ledger_class Js.t -> _) =
      method_ ledger_class name f
    in
    static_method "create" create ;

    static_method "hashParty" hash_party ;
    static_method "hashProtocolState" hash_protocol_state ;
    static_method "hashTransaction" hash_transaction ;

    static_method "hashPartyChecked" hash_party_checked ;
    static_method "hashProtocolStateChecked" hash_protocol_state_checked ;
    static_method "hashTransactionChecked" hash_transaction_checked ;

    static_method "transactionCommitments" transaction_commitments ;
    static_method "transactionStatement" transaction_statement ;
    static_method "signFieldElement" sign_field_element ;
    static_method "signFeePayer" sign_fee_payer ;
    static_method "signOtherParty" sign_other_party ;
    static_method "publicKeyToString" public_key_to_string ;
    static_method "publicKeyOfString" public_key_of_string ;
    static_method "privateKeyToString" private_key_to_string ;
    static_method "privateKeyOfString" private_key_of_string ;

    method_ "getAccount" get_account ;
    method_ "addAccount" add_account ;
    method_ "applyPartiesTransaction" apply_js_transaction ;
    method_ "applyJsonTransaction" apply_json_transaction ;

    static_method "partiesToJson" parties_to_json ;
    let rec yojson_to_gql (y : Yojson.Safe.t) : string =
      match y with
      | `Assoc kv ->
          let kv_to_string (k, v) =
            sprintf "%s:%s" (Fields_derivers.under_to_camel k) (yojson_to_gql v)
          in
          sprintf "{%s}" (List.map kv ~f:kv_to_string |> String.concat ~sep:",")
      | `List xs ->
          sprintf "[%s]" (List.map xs ~f:yojson_to_gql |> String.concat ~sep:",")
      | x ->
          Yojson.Safe.to_string x
    in
    let parties_to_graphql ps =
      parties ps |> !((deriver ())#to_json) |> yojson_to_gql |> Js.string
    in
    static_method "partiesToGraphQL" parties_to_graphql
end

let export () =
  Js.export "Field" field_class ;
  Js.export "Scalar" scalar_class ;
  Js.export "Bool" bool_class ;
  Js.export "Group" group_class ;
  Js.export "Poseidon" poseidon ;
  Js.export "Circuit" Circuit.circuit ;
  Js.export "Ledger" Ledger.ledger_class ;
  Js.export "Pickles" pickles

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
         ; ("Ledger", i Ledger.ledger_class)
         ; ("Pickles", i pickles)
        |])
  in
  Js.Unsafe.(set global (Js.string "__snarky") snarky_obj)
