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
  Js_of_ocaml.Js_error.(
    raise_ @@ of_error (new%js Js.error_constr (Js.string s)))

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

  let of_number_exn (value : t) : Impl.Field.t =
    let number : Js.number Js.t = Obj.magic value in
    let float = Js.float_of_number number in
    if Float.is_integer float then
      if float >= 0. then
        Impl.Field.(
          constant @@ Constant.of_string @@ Js.to_string @@ number##toString)
      else
        let number : Js.number Js.t = Obj.magic (-.float) in
        Impl.Field.negate
          Impl.Field.(
            constant @@ Constant.of_string @@ Js.to_string @@ number##toString)
    else raise_error "Cannot convert a float to a field element"

  let of_boolean (value : t) : Impl.Field.t =
    let value = Js.to_bool (Obj.magic value) in
    if value then Impl.Field.one else Impl.Field.zero

  let of_string_exn (value : t) : Impl.Field.t =
    let value : Js.js_string Js.t = Obj.magic value in
    let s = Js.to_string value in
    try
      Impl.Field.constant
        ( if
          String.length s >= 2
          && Char.equal s.[0] '0'
          && Char.equal (Char.lowercase_ascii s.[1]) 'x'
        then Kimchi_pasta.Pasta.Fp.(of_bigint (Bigint.of_hex_string s))
        else if String.length s >= 1 && Char.equal s.[0] '-' then
          String.sub s 1 (String.length s - 1)
          |> Impl.Field.Constant.of_string |> Impl.Field.Constant.negate
        else Impl.Field.Constant.of_string s )
    with Failure e -> raise_error e

  let of_bigint_exn (value : t) : Impl.Field.t =
    let bigint : < toString : Js.js_string Js.t Js.meth > Js.t =
      Obj.magic value
    in
    bigint##toString |> Obj.magic |> of_string_exn

  let value (value : t) : Impl.Field.t =
    match Js.to_string (Js.typeof (Obj.magic value)) with
    | "number" ->
        of_number_exn value
    | "boolean" ->
        of_boolean value
    | "string" ->
        of_string_exn value
    | "bigint" ->
        of_bigint_exn value
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
             "Type \"%s\" cannot be converted to a field element" s )

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
      raise_error (sprintf "array_get_exn: index=%d, length=%d" i xs##.length) )

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

let to_js_bigint =
  let bigint_constr = Js.Unsafe.eval_string {js|BigInt|js} in
  fun (s : Js.js_string Js.t) ->
    Js.Unsafe.fun_call bigint_constr [| Js.Unsafe.inject s |]

let to_js_field x : field_class Js.t = new%js field_constr (As_field.of_field x)

let of_js_field (x : field_class Js.t) : Field.t = x##.value

let to_js_field_unchecked x : field_class Js.t =
  x |> Field.constant |> to_js_field

let to_unchecked (x : Field.t) =
  match x with Constant y -> y | y -> Impl.As_prover.read_var y

let of_js_field_unchecked (x : field_class Js.t) = to_unchecked @@ of_js_field x

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
        mk (f this##.value (As_field.value y)) )
  in
  let sub =
    handle_constants2 Field.sub (fun x y ->
        Field.constant (Field.Constant.sub x y) )
  in
  let div =
    handle_constants2 Field.div (fun x y ->
        Field.constant (Field.Constant.( / ) x y) )
  in
  let sqrt =
    handle_constants Field.sqrt (fun x ->
        Field.constant (Field.Constant.sqrt x) )
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
      singleton_array this ) ;
  method_ "toBigInt" (fun this -> to_string this##.value |> to_js_bigint) ;
  ((* TODO: Make this work with arbitrary bit length *)
   let bit_length = Field.size_in_bits - 2 in
   let cmp_method (name, f) =
     method_ name (fun this (y : As_field.t) : unit ->
         f ~bit_length this##.value (As_field.value y) )
   in
   let bool_cmp_method (name, f) =
     method_ name (fun this (y : As_field.t) : bool_class Js.t ->
         new%js bool_constr
           (As_bool.of_boolean
              (f (Field.compare ~bit_length this##.value (As_field.value y))) ) )
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
     ] ) ;
  method_ "assertEquals" (fun this (y : As_field.t) : unit ->
      try Field.Assert.equal this##.value (As_field.value y)
      with _ ->
        console_log this ;
        console_log (As_field.to_field_obj y) ;
        let () = raise_error "assertEquals: not equal" in
        () ) ;

  (* TODO: bring back better error msg when .toString works in circuits *)
  (* sprintf "assertEquals: %s != %s"
         (Js.to_string this##toString)
         (Js.to_string (As_field.to_field_obj y)##toString)
     in
     Js.raise_js_error (new%js Js.error_constr (Js.string s))) ; *)
  method_ "assertBoolean" (fun this : unit ->
      Impl.assert_ (Constraint.boolean this##.value) ) ;
  method_ "isZero" (fun this : bool_class Js.t ->
      new%js bool_constr
        (As_bool.of_boolean (Field.equal this##.value Field.zero)) ) ;
  optdef_arg_method field_class "toBits"
    (fun this (length : int Js.Optdef.t) : bool_class Js.t Js.js_array Js.t ->
      let length = Js.Optdef.get length (fun () -> Field.size_in_bits) in
      let k f bits =
        let arr = new%js Js.array_empty in
        List.iter bits ~f:(fun x ->
            arr##push (new%js bool_constr (As_bool.of_boolean (f x))) |> ignore ) ;
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
                 length ) ;
          k Boolean.var_of_value bits )
        this##.value ) ;
  method_ "equals" (fun this (y : As_field.t) : bool_class Js.t ->
      new%js bool_constr
        (As_bool.of_boolean (Field.equal this##.value (As_field.value y))) ) ;
  let static_op1 name (f : Field.t -> Field.t) =
    Js.Unsafe.set field_class (Js.string name)
      (Js.wrap_callback (fun (x : As_field.t) : field_class Js.t ->
           mk (f (As_field.value x)) ) )
  in
  let static_op2 name (f : Field.t -> Field.t -> Field.t) =
    Js.Unsafe.set field_class (Js.string name)
      (Js.wrap_callback
         (fun (x : As_field.t) (y : As_field.t) : field_class Js.t ->
           mk (f (As_field.value x) (As_field.value y)) ) )
  in
  field_class##.one := mk Field.one ;
  field_class##.zero := mk Field.zero ;
  field_class##.minusOne := mk @@ Field.negate Field.one ;
  Js.Unsafe.set field_class (Js.string "ORDER")
    ( to_js_bigint @@ Js.string @@ Pasta_bindings.BigInt256.to_string
    @@ Pasta_bindings.Fp.size () ) ;
  field_class##.random :=
    Js.wrap_callback (fun () : field_class Js.t ->
        mk (Field.constant (Field.Constant.random ())) ) ;
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
        to_string (As_field.value x) ) ;
  field_class##.sizeInFields := Js.wrap_callback (fun () : int -> 1) ;
  field_class##.toFields :=
    Js.wrap_callback
      (fun (x : As_field.t) : field_class Js.t Js.js_array Js.t ->
        (As_field.to_field_obj x)##toFields ) ;
  field_class##.ofFields :=
    Js.wrap_callback
      (fun (xs : field_class Js.t Js.js_array Js.t) : field_class Js.t ->
        array_check_length xs 1 ; array_get_exn xs 0 ) ;
  field_class##.assertEqual :=
    Js.wrap_callback (fun (x : As_field.t) (y : As_field.t) : unit ->
        Field.Assert.equal (As_field.value x) (As_field.value y) ) ;
  field_class##.assertBoolean
  := Js.wrap_callback (fun (x : As_field.t) : unit ->
         Impl.assert_ (Constraint.boolean (As_field.value x)) ) ;
  field_class##.isZero :=
    Js.wrap_callback (fun (x : As_field.t) : bool_class Js.t ->
        new%js bool_constr
          (As_bool.of_boolean (Field.equal (As_field.value x) Field.zero)) ) ;
  field_class##.ofBits :=
    Js.wrap_callback
      (fun (bs : As_bool.t Js.js_array Js.t) : field_class Js.t ->
        try
          Array.map (Js.to_array bs) ~f:(fun b ->
              match (As_bool.value b :> Impl.Field.t) with
              | Constant b ->
                  Impl.Field.Constant.(equal one b)
              | _ ->
                  failwith "non-constant" )
          |> Array.to_list |> Field.Constant.project |> Field.constant |> mk
        with _ ->
          mk
            (Field.project
               (List.init bs##.length ~f:(fun i ->
                    Js.Optdef.case (Js.array_get bs i)
                      (fun () -> assert false)
                      As_bool.value ) ) ) ) ;
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
       fun_call wrapper [| inject (Js.wrap_callback As_field.to_field_obj) |])
  ) ;
  field_class##.equal :=
    Js.wrap_callback (fun (x : As_field.t) (y : As_field.t) : bool_class Js.t ->
        new%js bool_constr
          (As_bool.of_boolean
             (Field.equal (As_field.value x) (As_field.value y)) ) ) ;
  let static_method name f =
    Js.Unsafe.set field_class (Js.string name) (Js.wrap_callback f)
  in
  method_ "seal"
    (let seal = Pickles.Util.seal (module Impl) in
     fun (this : field_class Js.t) : field_class Js.t -> mk (seal this##.value)
    ) ;
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
                   v num_bits )
          done ;
          this
      | v ->
          let _a, _b, n =
            Pickles.Scalar_challenge.to_field_checked' ~num_bits
              (module Impl)
              { inner = v }
          in
          mk n ) ;
  method_ "isConstant" (fun (this : field_class Js.t) : bool Js.t ->
      match this##.value with Constant _ -> Js._true | _ -> Js._false ) ;
  method_ "toConstant" (fun (this : field_class Js.t) : field_class Js.t ->
      let x =
        match this##.value with Constant x -> x | x -> As_prover.read_var x
      in
      mk (Field.constant x) ) ;
  method_ "toJSON" (fun (this : field_class Js.t) : < .. > Js.t ->
      this##toString ) ;
  static_method "toJSON" (fun (this : field_class Js.t) : < .. > Js.t ->
      this##toJSON ) ;
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
                 else Field.Constant.of_string s ) )
          with Failure _ -> Js.Opt.empty )
      | _ ->
          Js.Opt.empty ) ;
  let from f x = new%js field_constr (As_field.of_field (f x)) in
  static_method "fromNumber" (from As_field.of_number_exn) ;
  static_method "fromString" (from As_field.of_string_exn) ;
  static_method "fromBigInt" (from As_field.of_bigint_exn) ;
  static_method "check" (fun _x -> ())

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
        Boolean.var_of_value (Field.Constant.equal x y) )
  in
  let mk x : bool_class Js.t = new%js bool_constr (As_bool.of_boolean x) in
  let method_ name (f : bool_class Js.t -> _) = method_ bool_class name f in
  let add_op1 name (f : Boolean.var -> Boolean.var) =
    method_ name (fun this : bool_class Js.t -> mk (f this##.value))
  in
  let add_op2 name (f : Boolean.var -> Boolean.var -> Boolean.var) =
    method_ name (fun this (y : As_bool.t) : bool_class Js.t ->
        mk (f this##.value (As_bool.value y)) )
  in
  Js.Unsafe.set bool_class (Js.string "true") (mk Boolean.true_) ;
  Js.Unsafe.set bool_class (Js.string "false") (mk Boolean.false_) ;
  method_ "toField" (fun this : field_class Js.t ->
      new%js field_constr (As_field.of_field (this##.value :> Field.t)) ) ;
  add_op1 "not" Boolean.not ;
  add_op2 "and" Boolean.( &&& ) ;
  add_op2 "or" Boolean.( ||| ) ;
  method_ "assertEquals" (fun this (y : As_bool.t) : unit ->
      Boolean.Assert.( = ) this##.value (As_bool.value y) ) ;
  method_ "assertTrue" (fun this : unit -> Boolean.Assert.is_true this##.value) ;
  method_ "assertFalse" (fun this : unit ->
      Boolean.Assert.( = ) this##.value Boolean.false_ ) ;
  add_op2 "equals" equal ;
  method_ "toBoolean" (fun this : bool Js.t ->
      match (this##.value :> Field.t) with
      | Constant x ->
          Js.bool Field.Constant.(equal one x)
      | _ -> (
          try Js.bool (As_prover.read Boolean.typ this##.value)
          with _ ->
            raise_error
              "Bool.toBoolean can only be called on non-witness values." ) ) ;
  method_ "sizeInFields" (fun _this : int -> 1) ;
  method_ "toString" (fun this ->
      let x =
        match (this##.value :> Field.t) with
        | Constant x ->
            x
        | x ->
            As_prover.read_var x
      in
      if Field.Constant.(equal one) x then "true" else "false" ) ;
  method_ "toFields" (fun this : field_class Js.t Js.js_array Js.t ->
      let arr = new%js Js.array_empty in
      arr##push this##toField |> ignore ;
      arr ) ;
  let static_method name f =
    Js.Unsafe.set bool_class (Js.string name) (Js.wrap_callback f)
  in
  let static_op1 name (f : Boolean.var -> Boolean.var) =
    static_method name (fun (x : As_bool.t) : bool_class Js.t ->
        mk (f (As_bool.value x)) )
  in
  let static_op2 name (f : Boolean.var -> Boolean.var -> Boolean.var) =
    static_method name (fun (x : As_bool.t) (y : As_bool.t) : bool_class Js.t ->
        mk (f (As_bool.value x) (As_bool.value y)) )
  in
  static_method "toField" (fun (x : As_bool.t) ->
      new%js field_constr (As_field.of_field (As_bool.value x :> Field.t)) ) ;
  Js.Unsafe.set bool_class (Js.string "Unsafe")
    (object%js
       method ofField (x : As_field.t) : bool_class Js.t =
         new%js bool_constr
           (As_bool.of_boolean (Boolean.Unsafe.of_cvar (As_field.value x)))
    end ) ;
  static_op1 "not" Boolean.not ;
  static_op2 "and" Boolean.( &&& ) ;
  static_op2 "or" Boolean.( ||| ) ;
  static_method "assertEqual" (fun (x : As_bool.t) (y : As_bool.t) : unit ->
      Boolean.Assert.( = ) (As_bool.value x) (As_bool.value y) ) ;
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
                     :> Field.t ) ) ) ) ) ) ;
  static_method "sizeInFields" (fun () : int -> 1) ;
  static_method "toFields"
    (fun (x : As_bool.t) : field_class Js.t Js.js_array Js.t ->
      singleton_array
        (new%js field_constr (As_field.of_field (As_bool.value x :> Field.t))) ) ;
  static_method "ofFields"
    (fun (xs : field_class Js.t Js.js_array Js.t) : bool_class Js.t ->
      if xs##.length = 1 then
        Js.Optdef.case (Js.array_get xs 0)
          (fun () -> assert false)
          (fun x -> mk (Boolean.Unsafe.of_cvar x##.value))
      else raise_error "Expected array of length 1" ) ;
  static_method "check" (fun (x : bool_class Js.t) : unit ->
      Impl.assert_ (Constraint.boolean (x##.value :> Field.t)) ) ;
  method_ "toJSON" (fun (this : bool_class Js.t) : < .. > Js.t ->
      Js.Unsafe.coerce this##toBoolean ) ;
  static_method "toJSON" (fun (this : bool_class Js.t) : < .. > Js.t ->
      this##toJSON ) ;
  static_method "fromJSON"
    (fun (value : Js.Unsafe.any) : bool_class Js.t Js.Opt.t ->
      match Js.to_string (Js.typeof (Js.Unsafe.coerce value)) with
      | "boolean" ->
          Js.Opt.return
            (new%js bool_constr (As_bool.of_js_bool (Js.Unsafe.coerce value)))
      | _ ->
          Js.Opt.empty )

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
                return Js.Optdef.empty )
      in
      Js.Optdef.return
        (Pickles_types.Shifted_value.Type1.to_field
           (module Other_backend.Field)
           ~shift:scalar_shift
           (Shifted_value (Other_backend.Field.of_bits (Array.to_list bs))) ) )

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
          (sprintf "Scalar.%s can only be called on non-witness values." name) )
  in
  let bits = scalar_to_bits in
  let constant_op1 name (f : Other_backend.Field.t -> Other_backend.Field.t) =
    method_ name (fun x : scalar_class Js.t ->
        let z = f (!name x##.constantValue) in
        new%js scalar_constr_const (bits z) z )
  in
  let constant_op2 name
      (f :
        Other_backend.Field.t -> Other_backend.Field.t -> Other_backend.Field.t
        ) =
    let ( ! ) = !name in
    method_ name (fun x (y : scalar_class Js.t) : scalar_class Js.t ->
        let z = f !(x##.constantValue) !(y##.constantValue) in
        new%js scalar_constr_const (bits z) z )
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
  static_method "check" (fun _x -> ()) ;
  constant_op1 "neg" Other_backend.Field.negate ;
  constant_op2 "add" Other_backend.Field.add ;
  constant_op2 "mul" Other_backend.Field.mul ;
  constant_op2 "sub" Other_backend.Field.sub ;
  constant_op2 "div" Other_backend.Field.div ;
  method_ "toFields" (fun x : field_class Js.t Js.js_array Js.t ->
      Array.map x##.value ~f:(fun b ->
          new%js field_constr (As_field.of_field (b :> Field.t)) )
      |> Js.array ) ;
  static_method "toFields"
    (fun (x : scalar_class Js.t) : field_class Js.t Js.js_array Js.t ->
      (Js.Unsafe.coerce x)##toFields ) ;
  static_method "sizeInFields" (fun () : int -> num_bits) ;
  static_method "ofFields"
    (fun (xs : field_class Js.t Js.js_array Js.t) : scalar_class Js.t ->
      new%js scalar_constr
        (Array.map (Js.to_array xs) ~f:(fun x ->
             Boolean.Unsafe.of_cvar x##.value ) ) ) ;
  static_method "random" (fun () : scalar_class Js.t ->
      let x = Other_backend.Field.random () in
      new%js scalar_constr_const (bits x) x ) ;
  static_method "ofBits"
    (fun (bits : bool_class Js.t Js.js_array Js.t) : scalar_class Js.t ->
      new%js scalar_constr
        (Array.map (Js.to_array bits) ~f:(fun b ->
             As_bool.(value (of_bool_obj b)) ) ) ) ;
  method_ "toJSON" (fun (s : scalar_class Js.t) : < .. > Js.t ->
      let s =
        Js.Optdef.case s##.constantValue
          (fun () ->
            Js.Optdef.get
              (to_constant_scalar s##.value)
              (fun () -> raise_error "Cannot convert in-circuit value to JSON")
            )
          Fn.id
      in
      Js.string (Other_impl.Field.Constant.to_string s) ) ;
  static_method "toJSON" (fun (s : scalar_class Js.t) : < .. > Js.t ->
      s##toJSON ) ;
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
          Js.Opt.empty )

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
               (x2, y2) )
      | _ ->
          Pickles.Step_main_inputs.Ops.add_fast p1 p2 |> mk ) ;
  method_ "neg" (fun (p1 : group_class Js.t) : group_class Js.t ->
      Pickles.Step_main_inputs.Inner_curve.negate
        (As_group.value (As_group.of_group_obj p1))
      |> mk ) ;
  method_ "sub"
    (fun (p1 : group_class Js.t) (p2 : As_group.t) : group_class Js.t ->
      p1##add (As_group.to_group_obj p2)##neg ) ;
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
          |> mk ) ;
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
      Field.Assert.equal x1 x2 ; Field.Assert.equal y1 y2 ) ;
  method_ "equals"
    (fun (p1 : group_class Js.t) (p2 : As_group.t) : bool_class Js.t ->
      let x1, y1 = As_group.value (As_group.of_group_obj p1) in
      let x2, y2 = As_group.value p2 in
      new%js bool_constr
        (As_bool.of_boolean
           (Boolean.all [ Field.equal x1 x2; Field.equal y1 y2 ]) ) ) ;
  static "generator"
    (mk Pickles.Step_main_inputs.Inner_curve.one : group_class Js.t) ;
  static_method "add"
    (fun (p1 : As_group.t) (p2 : As_group.t) : group_class Js.t ->
      (As_group.to_group_obj p1)##add_ p2 ) ;
  static_method "sub"
    (fun (p1 : As_group.t) (p2 : As_group.t) : group_class Js.t ->
      (As_group.to_group_obj p1)##sub_ p2 ) ;
  static_method "sub"
    (fun (p1 : As_group.t) (p2 : As_group.t) : group_class Js.t ->
      (As_group.to_group_obj p1)##sub_ p2 ) ;
  static_method "neg" (fun (p1 : As_group.t) : group_class Js.t ->
      (As_group.to_group_obj p1)##neg ) ;
  static_method "scale"
    (fun (p1 : As_group.t) (s : scalar_class Js.t) : group_class Js.t ->
      (As_group.to_group_obj p1)##scale s ) ;
  static_method "assertEqual" (fun (p1 : As_group.t) (p2 : As_group.t) : unit ->
      (As_group.to_group_obj p1)##assertEquals p2 ) ;
  static_method "equal"
    (fun (p1 : As_group.t) (p2 : As_group.t) : bool_class Js.t ->
      (As_group.to_group_obj p1)##equals p2 ) ;
  method_ "toFields"
    (fun (p1 : group_class Js.t) : field_class Js.t Js.js_array Js.t ->
      let arr = singleton_array p1##.x in
      arr##push p1##.y |> ignore ;
      arr ) ;
  static_method "toFields" (fun (p1 : group_class Js.t) -> p1##toFields) ;
  static_method "ofFields" (fun (xs : field_class Js.t Js.js_array Js.t) ->
      array_check_length xs 2 ;
      new%js group_constr
        (As_field.of_field_obj (array_get_exn xs 0))
        (As_field.of_field_obj (array_get_exn xs 1)) ) ;
  static_method "sizeInFields" (fun () : int -> 2) ;
  static_method "check" (fun (p : group_class Js.t) : unit ->
      Pickles.Step_main_inputs.Inner_curve.assert_on_curve
        Field.((p##.x##.value :> t), (p##.y##.value :> t)) ) ;
  method_ "toJSON" (fun (p : group_class Js.t) : < .. > Js.t ->
      object%js
        val x = (Obj.magic field_class)##toJSON p##.x

        val y = (Obj.magic field_class)##toJSON p##.y
      end ) ;
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
                (As_field.of_field_obj x) (As_field.of_field_obj y) ) ) )

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
           t2##.length )
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
          (As_field.of_field (Field.if_ b ~then_:x1##.value ~else_:x2##.value)) )

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
          < toFields : field_class Js.t Js.js_array Js.t Js.meth > Js.t as 'a )
        (t2 : 'a) : unit =
      f (to_field_elts_magic t1) (to_field_elts_magic t2)
    in
    let explicit
        (ctor :
          < toFields : 'a -> field_class Js.t Js.js_array Js.t Js.meth > Js.t )
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
                   (array_get_exn t2 i)##.value ) )
        |> As_bool.of_boolean )
    in
    let _implicit
        (t1 :
          < toFields : field_class Js.t Js.js_array Js.t Js.meth > Js.t as 'a )
        (t2 : 'a) : bool_class Js.t =
      f t1##toFields t2##toFields
    in
    let implicit t1 t2 = f (to_field_elts_magic t1) (to_field_elts_magic t2) in
    let explicit
        (ctor :
          < toFields : 'a -> field_class Js.t Js.js_array Js.t Js.meth > Js.t )
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
             if_magic b x1 x2 )
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
                  (Js.to_string (ks2##join (Js.string ", "))) )
               ks1 ks2 ;
             array_iter2 ks1 ks2 ~f:(fun k1 k2 ->
                 if not (js_equal k1 k2) then
                   raise_error "if: Arguments had mismatched types" ) ;
             let result = new%js ctor1 in
             array_iter ks1 ~f:(fun k ->
                 Js.Unsafe.set result k
                   (if_magic b (Js.Unsafe.get t1 k) (Js.Unsafe.get t2 k)) ) ;
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
                new%js field_constr (As_field.of_field (conv x)) ) ) )
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
      let () = (Js.Unsafe.coerce typ)##check a in
      ()
    else failwith "Circuit.witness: input does not have a `check` method" ;
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
    (main, Impl.Data_spec.[ typ_ c##.snarkyPublicTyp ])

  let generate_keypair (type w p) (c : (w, p) Circuit_main.t) :
      keypair_class Js.t =
    let main, spec = main_and_input c in
    let cs =
      Impl.constraint_system ~exposing:spec
        ~return_typ:Snark_params.Tick.Typ.unit (fun x -> main x)
    in
    let kp = Impl.Keypair.generate cs in
    new%js keypair_constr kp

  let prove (type w p) (c : (w, p) Circuit_main.t) (priv : w) (pub : p) kp :
      proof_class Js.t =
    let main, spec = main_and_input c in
    let pk = Keypair.pk kp in
    let p =
      Impl.generate_witness_conv ~return_typ:Snark_params.Tick.Typ.unit
        ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs } () ->
          Backend.Proof.create pk ~auxiliary:auxiliary_inputs
            ~primary:public_inputs )
        spec (main ~w:priv) pub
    in
    new%js proof_constr p

  let circuit = Js.Unsafe.eval_string {js|(function() { return this })|js}

  let () =
    circuit##.runAndCheck :=
      Js.wrap_callback (fun (f : unit -> 'a) ->
          Impl.run_and_check (fun () -> f) |> Or_error.ok_exn ) ;

    circuit##.asProver :=
      Js.wrap_callback (fun (f : (unit -> unit) Js.callback) : unit ->
          Impl.as_prover (fun () -> Js.Unsafe.fun_call f [||]) ) ;
    circuit##.witness := Js.wrap_callback witness ;
    circuit##.generateKeypair :=
      Js.wrap_meth_callback
        (fun (this : _ Circuit_main.t) : keypair_class Js.t ->
          generate_keypair this ) ;
    circuit##.prove :=
      Js.wrap_meth_callback
        (fun (this : _ Circuit_main.t) w p (kp : keypair_class Js.t) ->
          prove this w p kp##.value ) ;
    (circuit##.verify :=
       fun (pub : Js.Unsafe.any Js.js_array Js.t)
           (vk : verification_key_class Js.t) (pi : proof_class Js.t) :
           bool Js.t ->
         vk##verify pub pi ) ;
    circuit##.assertEqual := assert_equal ;
    circuit##.equal := equal ;
    circuit##.toFields := Js.wrap_callback to_field_elts_magic ;
    circuit##.inProver :=
      Js.wrap_callback (fun () : bool Js.t -> Js.bool (Impl.in_prover ())) ;
    circuit##.inCheckedComputation
    := Js.wrap_callback (fun () : bool Js.t ->
           Js.bool (Impl.in_checked_computation ()) ) ;
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
      new%js verification_key_constr (Keypair.vk this##.value) )

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
          (Js.to_string s |> Binable.of_string (module Backend.Proof)) ) ;
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
              raise_error "verify: Expected non-circuit values for input" ) ;
      Backend.Proof.verify pi##.value this##.value v |> Js.bool )

let () =
  let method_ name (f : proof_class Js.t -> _) = method_ proof_class name f in
  method_ "toString" (fun this : Js.js_string Js.t ->
      Binable.to_string (module Backend.Proof) this##.value |> Js.string ) ;
  proof_class##.ofString :=
    Js.wrap_callback (fun (s : Js.js_string Js.t) : proof_class Js.t ->
        new%js proof_constr
          (Js.to_string s |> Binable.of_string (module Backend.Proof)) ) ;
  method_ "verify"
    (fun
      (this : proof_class Js.t)
      (vk : verification_key_class Js.t)
      (pub : Js.Unsafe.any Js.js_array Js.t)
      :
      bool Js.t
    -> vk##verify pub this )

(* helpers for pickles_compile *)

type 'a public_input = 'a array

type public_input_js = field_class Js.t Js.js_array Js.t

type 'proof public_input_with_proof_js =
  < publicInput : public_input_js Js.prop ; proof : 'proof Js.prop > Js.t

module Public_input = struct
  type t = Field.t public_input

  let to_field_elements (t : t) : Field.t array = t

  let to_constant (t : t) = Array.map ~f:to_unchecked t

  let to_js (t : t) : public_input_js = Array.map ~f:to_js_field t |> Js.array

  let of_js (a : public_input_js) : t =
    Js.to_array a |> Array.map ~f:of_js_field

  let list_to_js (public_inputs : t list) =
    List.map ~f:to_js public_inputs |> Array.of_list |> Js.array

  module Constant = struct
    type t = Field.Constant.t public_input

    let to_field_elements (t : t) : Field.Constant.t array = t

    let to_js (t : t) : public_input_js =
      Array.map ~f:to_js_field_unchecked t |> Js.array

    let of_js (a : public_input_js) : t =
      Js.to_array a |> Array.map ~f:of_js_field_unchecked
  end
end

let public_input_typ (i : int) = Typ.array ~length:i Field.typ

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

type pickles_rule_js =
  < identifier : Js.js_string Js.t Js.prop
  ; main :
      (   public_input_js
       -> public_input_js Js.js_array Js.t
       -> bool_class Js.t Js.js_array Js.t )
      Js.prop
  ; proofsToVerify :
      < isSelf : bool Js.t Js.prop ; tag : Js.Unsafe.any Js.t Js.prop > Js.t
      Js.js_array
      Js.t
      Js.prop >
  Js.t

module Choices = struct
  open Pickles_types
  open Hlist

  module Prevs = struct
    type ('var, 'value, 'width, 'height) t =
      | Prevs :
          (   self:('var, 'value, 'width, 'height) Pickles.Tag.t
           -> ('prev_var, 'prev_values, 'widths, 'heights) H4.T(Pickles.Tag).t
          )
          -> ('var, 'value, 'width, 'height) t

    let of_rule (rule : pickles_rule_js) =
      let js_prevs = rule##.proofsToVerify in
      let rec get_tags (Prevs prevs) index =
        if index < 0 then Prevs prevs
        else
          let js_tag =
            Js.Optdef.get (Js.array_get js_prevs index) (fun () ->
                raise_errorf
                  "proofsToVerify array is sparse; the entry at index %i is \
                   missing"
                  index )
          in
          (* We introduce new opaque types to make sure that the type in the tag
             doesn't escape into the environment or have other ill effects.
          *)
          let module Types = struct
            type var

            type value

            type width

            type height
          end in
          let open Types in
          let to_tag ~self tag : (var, value, width, height) Pickles.Tag.t =
            (* The magic here isn't ideal, but it's safe enough if we immediately
               hide it behind [Types].
            *)
            if Js.to_bool tag##.isSelf then Obj.magic self
            else Obj.magic tag##.tag
          in
          let tag = to_tag js_tag in
          let prevs ~self : _ H4.T(Pickles.Tag).t = tag ~self :: prevs ~self in
          get_tags (Prevs prevs) (index - 1)
      in
      get_tags (Prevs (fun ~self:_ -> [])) (js_prevs##.length - 1)
  end

  module Inductive_rule = struct
    type ( 'var
         , 'value
         , 'width
         , 'height
         , 'arg_var
         , 'arg_value
         , 'ret_var
         , 'ret_value
         , 'auxiliary_var
         , 'auxiliary_value )
         t =
      | Rule :
          (   self:('var, 'value, 'width, 'height) Pickles.Tag.t
           -> ( 'prev_vars
              , 'prev_values
              , 'widths
              , 'heights
              , 'arg_var
              , 'arg_value
              , 'ret_var
              , 'ret_value
              , 'auxiliary_var
              , 'auxiliary_value )
              Pickles.Inductive_rule.t )
          -> ( 'var
             , 'value
             , 'width
             , 'height
             , 'arg_var
             , 'arg_value
             , 'ret_var
             , 'ret_value
             , 'auxiliary_var
             , 'auxiliary_value )
             t

    let rec should_verifys :
        type prev_vars prev_values widths heights.
           int
        -> (prev_vars, prev_values, widths, heights) H4.T(Pickles.Tag).t
        -> bool_class Js.t Js.js_array Js.t
        -> prev_vars H1.T(E01(Pickles.Inductive_rule.B)).t =
     fun index tags should_verifys_js ->
      match tags with
      | [] ->
          []
      | _ :: tags ->
          let js_bool =
            Js.Optdef.get (Js.array_get should_verifys_js index) (fun () ->
                raise_errorf
                  "Returned array is sparse; the entry at index %i is missing"
                  index )
          in
          let should_verifys =
            should_verifys (index + 1) tags should_verifys_js
          in
          js_bool##.value :: should_verifys

    let should_verifys tags should_verifys_js =
      should_verifys 0 tags should_verifys_js

    let rec vars_to_public_input :
        type prev_vars prev_values widths heights width height.
           public_input_size:int
        -> self:
             ( Public_input.t
             , Public_input.Constant.t
             , width
             , height )
             Pickles.Tag.t
        -> (prev_vars, prev_values, widths, heights) H4.T(Pickles.Tag).t
        -> prev_vars H1.T(Id).t
        -> Public_input.t list =
     fun ~public_input_size ~self tags inputs ->
      match (tags, inputs) with
      | [], [] ->
          []
      | tag :: tags, input :: inputs ->
          let (Typ typ) =
            match Type_equal.Id.same_witness tag.id self.id with
            | None ->
                Pickles.Types_map.public_input tag
            | Some T ->
                public_input_typ public_input_size
          in
          let input = fst (typ.var_to_fields input) in
          let inputs =
            vars_to_public_input ~public_input_size ~self tags inputs
          in
          input :: inputs

    type _ Snarky_backendless.Request.t +=
      | Get_public_input :
          int * (_, 'value, _, _) Pickles.Tag.t
          -> 'value Snarky_backendless.Request.t
      | Get_prev_proof : int -> _ Pickles.Proof.t Snarky_backendless.Request.t

    let create ~public_input_size (rule : pickles_rule_js) :
        ( _
        , _
        , _
        , _
        , Public_input.t
        , Public_input.Constant.t
        , unit
        , unit
        , unit
        , unit )
        t =
      let (Prevs prevs) = Prevs.of_rule rule in
      Rule
        (fun ~self ->
          let prevs = prevs ~self in
          { Pickles.Inductive_rule.identifier = Js.to_string rule##.identifier
          ; prevs
          ; main =
              (fun { public_input } ->
                dummy_constraints () ;
                (* TODO: Push this down into SnarkyJS so that it controls the
                   public inputs of prev proofs, and we can delete this
                   annoying logic.
                *)
                let previous_public_inputs =
                  let rec go :
                      type prev_vars prev_values widths heights.
                         int
                      -> ( prev_vars
                         , prev_values
                         , widths
                         , heights )
                         H4.T(Pickles.Tag).t
                      -> prev_vars H1.T(Id).t =
                   fun i tags ->
                    match tags with
                    | [] ->
                        []
                    | tag :: tags ->
                        let typ =
                          (fun (type a1 a2 a3 a4 b3 b4)
                               (tag : (a1, a2, a3, a4) Pickles.Tag.t)
                               (self :
                                 ( Field.t public_input
                                 , Impl.field public_input
                                 , b3
                                 , b4 )
                                 Pickles.Tag.t ) ->
                            match Type_equal.Id.same_witness tag.id self.id with
                            | None ->
                                Pickles.Types_map.public_input tag
                            | Some T ->
                                public_input_typ public_input_size )
                            tag self
                        in
                        let public_input =
                          Impl.exists typ ~request:(fun () ->
                              Get_public_input (i, tag) )
                        in
                        let public_inputs = go (i + 1) tags in
                        public_input :: public_inputs
                  in

                  go 0 prevs
                in
                let previous_proofs_should_verify =
                  rule##.main
                    (Public_input.to_js public_input)
                    (Public_input.list_to_js
                       (vars_to_public_input ~public_input_size ~self prevs
                          previous_public_inputs ) )
                  |> should_verifys prevs
                in
                let previous_proof_statements =
                  let rec go :
                      type prev_vars prev_values widths heights.
                         int
                      -> prev_vars H1.T(Id).t
                      -> prev_vars H1.T(E01(Pickles.Inductive_rule.B)).t
                      -> ( prev_vars
                         , prev_values
                         , widths
                         , heights )
                         H4.T(Pickles.Tag).t
                      -> ( prev_vars
                         , widths )
                         H2.T(Pickles.Inductive_rule.Previous_proof_statement).t
                      =
                   fun i public_inputs should_verifys tags ->
                    match (public_inputs, should_verifys, tags) with
                    | [], [], [] ->
                        []
                    | ( public_input :: public_inputs
                      , proof_must_verify :: should_verifys
                      , _tag :: tags ) ->
                        let proof =
                          Impl.exists (Impl.Typ.Internal.ref ())
                            ~request:(fun () -> Get_prev_proof i)
                        in
                        { public_input; proof; proof_must_verify }
                        :: go (i + 1) public_inputs should_verifys tags
                  in
                  go 0 previous_public_inputs previous_proofs_should_verify
                    prevs
                in
                { previous_proof_statements
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          } )
  end

  type ( 'var
       , 'value
       , 'width
       , 'height
       , 'arg_var
       , 'arg_value
       , 'ret_var
       , 'ret_value
       , 'auxiliary_var
       , 'auxiliary_value )
       t =
    | Choices :
        (   self:('var, 'value, 'width, 'height) Pickles.Tag.t
         -> ( 'prev_vars
            , 'prev_values
            , 'widths
            , 'heights
            , 'arg_var
            , 'arg_value
            , 'ret_var
            , 'ret_value
            , 'auxiliary_var
            , 'auxiliary_value )
            H4_6.T(Pickles.Inductive_rule).t )
        -> ( 'var
           , 'value
           , 'width
           , 'height
           , 'arg_var
           , 'arg_value
           , 'ret_var
           , 'ret_value
           , 'auxiliary_var
           , 'auxiliary_value )
           t

  let of_js ~public_input_size js_rules =
    let rec get_rules (Choices rules) index :
        ( _
        , _
        , _
        , _
        , Public_input.t
        , Public_input.Constant.t
        , unit
        , unit
        , unit
        , unit )
        t =
      if index < 0 then Choices rules
      else
        let js_rule =
          Js.Optdef.get (Js.array_get js_rules index) (fun () ->
              raise_errorf
                "Rules array is sparse; the entry at index %i is missing" index )
        in
        let (Rule rule) = Inductive_rule.create ~public_input_size js_rule in
        let rules ~self : _ H4_6.T(Pickles.Inductive_rule).t =
          rule ~self :: rules ~self
        in
        get_rules (Choices rules) (index - 1)
    in
    get_rules (Choices (fun ~self:_ -> [])) (js_rules##.length - 1)
end

let other_verification_key_constr :
    (Other_impl.Verification_key.t -> verification_key_class Js.t) Js.constr =
  Obj.magic verification_key_class

type proof = (Pickles_types.Nat.N0.n, Pickles_types.Nat.N0.n) Pickles.Proof.t

module Public_inputs_with_proofs =
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

let nat_add_modules_list : (module Pickles_types.Nat.Add.Intf) list =
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

let nat_add_module (i : int) : (module Pickles_types.Nat.Add.Intf) =
  List.nth_exn nat_add_modules_list i

let pickles_compile (choices : pickles_rule_js Js.js_array Js.t)
    (public_input_size : int) =
  let branches = choices##.length in
  let max_proofs =
    let choices = choices |> Js.to_array |> Array.to_list in
    List.map choices ~f:(fun c ->
        c##.proofsToVerify |> Js.to_array |> Array.length )
    |> List.max_elt ~compare |> Option.value ~default:0
  in
  let (module Branches) = nat_module branches in
  let (module Max_proofs_verified) = nat_add_module max_proofs in
  let (Choices choices) = Choices.of_js ~public_input_size choices in
  let tag, _cache, p, provers =
    Pickles.compile_promise ~choices
      (module Public_input)
      (module Public_input.Constant)
      ~public_input:(Input (public_input_typ public_input_size))
      ~auxiliary_typ:Typ.unit
      ~branches:(module Branches)
      ~max_proofs_verified:(module Max_proofs_verified)
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
    let prove (public_input_js : public_input_js)
        (prevs_js : Proof.t public_input_with_proof_js Js.js_array Js.t) =
      let to_prev (previous : Proof.t public_input_with_proof_js) =
        (Public_input.Constant.of_js previous##.publicInput, previous##.proof)
      in
      let prevs : (Field.Constant.t public_input * Proof.t) array =
        prevs_js |> Js.to_array |> Array.map ~f:to_prev
      in
      let public_input =
        Public_input.(public_input_js |> of_js |> to_constant)
      in
      let handler (Snarky_backendless.Request.With { request; respond }) =
        match request with
        | Choices.Inductive_rule.Get_public_input (i, prev_tag) -> (
            match Type_equal.Id.same_witness tag.id prev_tag.id with
            | Some T ->
                let public_input = fst (Array.get prevs i) in
                respond (Provide public_input)
            | None ->
                let (Typ typ) = Pickles.Types_map.public_input prev_tag in
                let public_input_fields = fst (Array.get prevs i) in
                let public_input =
                  typ.value_of_fields
                    (public_input_fields, typ.constraint_system_auxiliary ())
                in
                respond (Provide public_input) )
        | Choices.Inductive_rule.Get_prev_proof i ->
            respond (Provide (Obj.magic (snd (Array.get prevs i))))
        | _ ->
            respond Unhandled
      in
      prover ?handler:(Some handler) public_input
      |> Promise.map ~f:(fun ((), (), proof) -> proof)
      |> Promise_js_helpers.to_js
    in
    prove
  in
  let rec to_js_provers :
      type a b c.
         ( a
         , b
         , c
         , Public_input.Constant.t
         , (unit * unit * Proof.t) Promise.t )
         Pickles.Provers.t
      -> (   public_input_js
          -> Proof.t public_input_with_proof_js Js.js_array Js.t
          -> Proof.t Promise_js_helpers.js_promise )
         list = function
    | [] ->
        []
    | p :: ps ->
        to_js_prover p :: to_js_provers ps
  in
  let provers = provers |> to_js_provers |> Array.of_list |> Js.array in
  let verify (public_input_js : public_input_js) (proof : _ Pickles.Proof.t) =
    let public_input = Public_input.(public_input_js |> of_js |> to_constant) in
    Proof.verify_promise [ (public_input, proof) ]
    |> Promise.map ~f:Js.bool |> Promise_js_helpers.to_js
  in
  object%js
    val provers = Obj.magic provers

    val verify = Obj.magic verify

    val tag = Obj.magic tag

    val getVerificationKeyArtifact =
      fun () ->
        let vk = Pickles.Side_loaded.Verification_key.of_compiled tag in
        object%js
          val data =
            Pickles.Side_loaded.Verification_key.to_base58_check vk |> Js.string

          val hash =
            Mina_base.Zkapp_account.digest_vk vk
            |> Field.Constant.to_string |> Js.string
        end

    val getVerificationKey =
      fun () ->
        let key = Lazy.force Proof.verification_key in
        new%js other_verification_key_constr
          (Pickles.Verification_key.index key)
  end

module Proof0 = Pickles.Proof.Make (Pickles_types.Nat.N0) (Pickles_types.Nat.N0)
module Proof1 = Pickles.Proof.Make (Pickles_types.Nat.N1) (Pickles_types.Nat.N1)
module Proof2 = Pickles.Proof.Make (Pickles_types.Nat.N2) (Pickles_types.Nat.N2)

type some_proof = Proof0 of Proof0.t | Proof1 of Proof1.t | Proof2 of Proof2.t

let proof_to_base64 = function
  | Proof0 proof ->
      Proof0.to_base64 proof |> Js.string
  | Proof1 proof ->
      Proof1.to_base64 proof |> Js.string
  | Proof2 proof ->
      Proof2.to_base64 proof |> Js.string

let proof_of_base64 str i : some_proof =
  let str = Js.to_string str in
  match i with
  | 0 ->
      Proof0 (Proof0.of_base64 str |> Result.ok_or_failwith)
  | 1 ->
      Proof1 (Proof1.of_base64 str |> Result.ok_or_failwith)
  | 2 ->
      Proof2 (Proof2.of_base64 str |> Result.ok_or_failwith)
  | _ ->
      failwith "invalid proof index"

let verify (public_input : public_input_js) (proof : proof)
    (vk : Js.js_string Js.t) =
  let public_input = Public_input.Constant.of_js public_input in
  let typ = public_input_typ (Array.length public_input) in
  let proof = Pickles.Side_loaded.Proof.of_proof proof in
  let vk =
    Pickles.Side_loaded.Verification_key.of_base58_check_exn (Js.to_string vk)
  in
  Pickles.Side_loaded.verify_promise ~typ [ (vk, public_input, proof) ]
  |> Promise.map ~f:Js.bool |> Promise_js_helpers.to_js

let pickles =
  object%js
    val compile = pickles_compile

    val verify = verify

    val proofToBase64 = proof_to_base64

    val proofOfBase64 = proof_of_base64

    val proofToBase64Transaction =
      fun (proof : proof) ->
        proof |> Pickles.Side_loaded.Proof.of_proof
        |> Pickles.Side_loaded.Proof.to_base64 |> Js.string
  end

module Ledger = struct
  type js_uint32 = < value : field_class Js.t Js.readonly_prop > Js.t

  type js_uint64 = < value : field_class Js.t Js.readonly_prop > Js.t

  type private_key = < s : scalar_class Js.t Js.prop > Js.t

  type public_key = < g : group_class Js.t Js.prop > Js.t

  type zkapp_account =
    < appState : field_class Js.t Js.js_array Js.t Js.readonly_prop > Js.t

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

  let public_key (pk : public_key) : Signature_lib.Public_key.Compressed.t =
    { x = to_unchecked pk##.g##.x##.value
    ; is_odd = Bigint.(test_bit (of_field (to_unchecked pk##.g##.y##.value)) 0)
    }

  let private_key (key : private_key) : Signature_lib.Private_key.t =
    Js.Optdef.case
      key##.s##.constantValue
      (fun () -> failwith "invalid scalar")
      Fn.id

  let account_id pk =
    Mina_base.Account_id.create (public_key pk) Mina_base.Token_id.default

  let max_state_size =
    Pickles_types.Nat.to_int Mina_base.Zkapp_state.Max_state_size.n

  module Checked = struct
    let fields_to_hash
        (typ : ('var, 'value, Field.Constant.t, _) Impl.Internal_Basic.Typ.typ)
        (digest : 'var -> Field.t) (fields : field_class Js.t Js.js_array Js.t)
        =
      let fields = fields |> Js.to_array |> Array.map ~f:of_js_field in
      let (Typ typ) = typ in
      let variable =
        typ.var_of_fields (fields, typ.constraint_system_auxiliary ())
      in
      digest variable |> to_js_field
  end

  (* helper function to check whether the fields we produce from JS are correct *)
  let fields_of_json
      (typ : ('var, 'value, Field.Constant.t, 'tmp) Impl.Internal_Basic.Typ.typ)
      of_json (json : Js.js_string Js.t) : field_class Js.t Js.js_array Js.t =
    let json = json |> Js.to_string |> Yojson.Safe.from_string in
    let value = of_json json in
    let (Typ typ) = typ in
    let fields, _ = typ.value_to_fields value in
    Js.array
    @@ Array.map ~f:(fun x -> x |> Field.constant |> to_js_field) fields

  (* TODO: need to construct `aux` in JS, which has some extra data needed for `value_of_fields`  *)
  let fields_to_json
      (typ : ('var, 'value, Field.Constant.t, _) Impl.Internal_Basic.Typ.typ)
      to_json (fields : field_class Js.t Js.js_array Js.t) aux :
      Js.js_string Js.t =
    let fields =
      fields |> Js.to_array
      |> Array.map ~f:(fun x -> x |> of_js_field |> to_unchecked)
    in
    let (Typ typ) = typ in
    let value = typ.value_of_fields (fields, Obj.magic aux) in
    let json = to_json value in
    json |> Yojson.Safe.to_string |> Js.string

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
              ignore (xs##push (field x)) )
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

  module Party = Mina_base.Party
  module Parties = Mina_base.Parties

  let party_of_json =
    let deriver =
      Party.Graphql_repr.deriver @@ Fields_derivers_zkapps.Derivers.o ()
    in
    let party_of_json (party : Js.js_string Js.t) : Party.t =
      Fields_derivers_zkapps.of_json deriver
        (party |> Js.to_string |> Yojson.Safe.from_string)
      |> Party.of_graphql_repr
    in
    party_of_json

  (* TODO hash two parties together in the correct way *)

  let hash_party (p : Js.js_string Js.t) =
    Party.digest (p |> party_of_json) |> Field.constant |> to_js_field

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

  let zkapp_public_input (tx_json : Js.js_string Js.t) (party_index : int) =
    let tx =
      Parties.of_json @@ Yojson.Safe.from_string @@ Js.to_string tx_json
    in
    let party = List.nth_exn tx.other_parties party_index in
    Public_input.Constant.to_js
      [| (party.elt.party_digest :> Impl.field)
       ; (Parties.Digest.Forest.empty :> Impl.field)
      |]

  let sign_field_element (x : field_class Js.t) (key : private_key) =
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
           (transaction_commitment tx party_index) )
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
                else p )
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
               (key_to_string pk) )
      | Some pk_ ->
          if
            not
              (Signature_lib.Schnorr.Chunked.verify s
                 (Kimchi_pasta.Pasta.Pallas.of_affine pk_)
                 (Random_oracle_input.Chunked.field msg) )
          then
            failwith
              (sprintf "Check signature: Invalid signature on %s for key %s" who
                 (key_to_string pk) )
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
            () )

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

  let field_to_base58 (field : field_class Js.t) : Js.js_string Js.t =
    field |> of_js_field |> to_unchecked |> Mina_base.Account_id.Digest.of_field
    |> Mina_base.Account_id.Digest.to_string |> Js.string

  let field_of_base58 (field : Js.js_string Js.t) : field_class Js.t =
    to_js_field @@ Field.constant @@ Mina_base.Account_id.Digest.to_field_unsafe
    @@ Mina_base.Account_id.Digest.of_string @@ Js.to_string field

  let memo_to_base58 (memo : Js.js_string Js.t) : Js.js_string Js.t =
    Js.string @@ Mina_base.Signed_command_memo.to_base58_check
    @@ Mina_base.Signed_command_memo.create_from_string_exn @@ Js.to_string memo

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
        Js.t ) : ledger_class Js.t =
    let l = L.empty ~depth:20 () in
    array_iter genesis_accounts ~f:(fun a ->
        add_account_exn l a##.publicKey (Js.to_string a##.balance) ) ;
    new%js ledger_constr l

  let get_account l (pk : public_key) : account Js.optdef =
    let loc = L.location_of_account l##.value (account_id pk) in
    let account = Option.bind loc ~f:(L.get l##.value) in
    To_js.option To_js.account account

  let add_account l (pk : public_key) (balance : Js.js_string Js.t) =
    add_account_exn l##.value pk (Js.to_string balance)

  let dummy_state_view : Mina_base.Zkapp_precondition.Protocol_state.View.t =
    let epoch_data =
      { Mina_base.Zkapp_precondition.Protocol_state.Epoch_data.Poly.ledger =
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
    static_method "hashTransaction" hash_transaction ;
    static_method "hashTransactionChecked" hash_transaction_checked ;

    static_method "transactionCommitments" transaction_commitments ;
    static_method "zkappPublicInput" zkapp_public_input ;
    static_method "signFieldElement" sign_field_element ;
    static_method "signFeePayer" sign_fee_payer ;
    static_method "signOtherParty" sign_other_party ;

    static_method "publicKeyToString" public_key_to_string ;
    static_method "publicKeyOfString" public_key_of_string ;
    static_method "privateKeyToString" private_key_to_string ;
    static_method "privateKeyOfString" private_key_of_string ;
    static_method "fieldToBase58" field_to_base58 ;
    static_method "fieldOfBase58" field_of_base58 ;
    static_method "memoToBase58" memo_to_base58 ;

    static_method "hashPartyFromFields"
      (Checked.fields_to_hash
         (Mina_base.Party.Body.typ ())
         Mina_base.Party.Checked.digest ) ;

    (* TODO this is for debugging, maybe remove later *)
    let body_deriver =
      Mina_base.Party.Body.Graphql_repr.deriver @@ Fields_derivers_zkapps.o ()
    in
    let body_to_json value =
      value
      |> Party.Body.to_graphql_repr ~call_depth:0
      |> Fields_derivers_zkapps.to_json body_deriver
    in
    let body_of_json json =
      json
      |> Fields_derivers_zkapps.of_json body_deriver
      |> Party.Body.of_graphql_repr
    in
    static_method "fieldsToJson"
      (fields_to_json (Mina_base.Party.Body.typ ()) body_to_json) ;
    static_method "fieldsOfJson"
      (fields_of_json (Mina_base.Party.Body.typ ()) body_of_json) ;

    method_ "getAccount" get_account ;
    method_ "addAccount" add_account ;
    method_ "applyJsonTransaction" apply_json_transaction
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
