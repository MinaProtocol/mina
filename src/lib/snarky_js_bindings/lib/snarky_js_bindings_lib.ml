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

let log_and_raise_error_with_message ~exn ~msg =
  match Js.Optdef.to_option msg with
  | None ->
      raise_error (Core_kernel.Exn.to_string exn)
  | Some msg ->
      let stack = Printexc.get_backtrace () in
      let msg =
        Printf.sprintf "%s\n%s%s" (Js.to_string msg)
          (Core_kernel.Exn.to_string exn)
          stack
      in
      raise_error msg

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

let arg_optdef_arg_method (type a b) class_ (name : string)
    (f : _ Js.t -> b -> a Js.Optdef.t -> _) =
  let prototype = Js.Unsafe.get class_ (Js.string "prototype") in
  let meth =
    let wrapper =
      Js.Unsafe.eval_string
        {js|
        (function(f) {
          return function(argVal, xOptdef) {
            return f(this, argVal, xOptdef);
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

let bool_to_unchecked (x : Boolean.var) =
  (x :> Field.t) |> to_unchecked |> Field.Constant.(equal one)

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
     arg_optdef_arg_method field_class name
       (fun this (y : As_field.t) (msg : Js.js_string Js.t Js.Optdef.t) : unit
       ->
         try f ~bit_length this##.value (As_field.value y)
         with exn -> log_and_raise_error_with_message ~exn ~msg )
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

  arg_optdef_arg_method field_class "assertEquals"
    (fun this (y : As_field.t) (msg : Js.js_string Js.t Js.Optdef.t) : unit ->
      try Field.Assert.equal this##.value (As_field.value y)
      with exn -> log_and_raise_error_with_message ~exn ~msg ) ;
  optdef_arg_method field_class "assertBoolean"
    (fun this (msg : Js.js_string Js.t Js.Optdef.t) : unit ->
      try Impl.assert_ (Constraint.boolean this##.value)
      with exn -> log_and_raise_error_with_message ~exn ~msg ) ;
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
  field_class##.fromFields :=
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
  field_class##.fromBits :=
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
  arg_optdef_arg_method bool_class "assertEquals"
    (fun this (y : As_bool.t) (msg : Js.js_string Js.t Js.Optdef.t) : unit ->
      try Boolean.Assert.( = ) this##.value (As_bool.value y)
      with exn -> log_and_raise_error_with_message ~exn ~msg ) ;
  optdef_arg_method bool_class "assertTrue"
    (fun this (msg : Js.js_string Js.t Js.Optdef.t) : unit ->
      try Boolean.Assert.is_true this##.value
      with exn -> log_and_raise_error_with_message ~exn ~msg ) ;
  optdef_arg_method bool_class "assertFalse"
    (fun this (msg : Js.js_string Js.t Js.Optdef.t) : unit ->
      try Boolean.Assert.( = ) this##.value Boolean.false_
      with exn -> log_and_raise_error_with_message ~exn ~msg ) ;
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
  static_method "fromFields"
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
  static_method "fromFields"
    (fun (xs : field_class Js.t Js.js_array Js.t) : scalar_class Js.t ->
      new%js scalar_constr
        (Array.map (Js.to_array xs) ~f:(fun x ->
             Boolean.Unsafe.of_cvar x##.value ) ) ) ;
  static_method "random" (fun () : scalar_class Js.t ->
      let x = Other_backend.Field.random () in
      new%js scalar_constr_const (bits x) x ) ;
  static_method "fromBits"
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
  arg_optdef_arg_method group_class "assertEquals"
    (fun
      (p1 : group_class Js.t)
      (p2 : As_group.t)
      (msg : Js.js_string Js.t Js.Optdef.t)
      :
      unit
    ->
      let x1, y1 = As_group.value (As_group.of_group_obj p1) in
      let x2, y2 = As_group.value p2 in
      try Field.Assert.equal x1 x2
      with exn -> (
        ignore (log_and_raise_error_with_message ~exn ~msg) ;
        try Field.Assert.equal y1 y2
        with exn -> log_and_raise_error_with_message ~exn ~msg ) ) ;

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
  static_method "fromFields" (fun (xs : field_class Js.t Js.js_array Js.t) ->
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

    method fromFields : field_class Js.t Js.js_array Js.t -> 'a Js.meth

    method sizeInFields : int Js.meth
  end

class type ['a] as_field_elements_minimal =
  object
    method toFields : 'a -> field_class Js.t Js.js_array Js.t Js.meth

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
    (* this could be removed eventually since it's easily implemented using `update` *)
    method hash (xs : field_class Js.t Js.js_array Js.t)
        (is_checked : bool Js.t) : field_class Js.t =
      let input = Array.map (Js.to_array xs) ~f:of_js_field in
      let digest =
        if Js.to_bool is_checked then Random_oracle.Checked.hash input
        else
          Random_oracle.hash (Array.map ~f:to_unchecked input) |> Field.constant
      in
      to_js_field digest

    method update (state : field_class Js.t Js.js_array Js.t)
        (xs : field_class Js.t Js.js_array Js.t) (is_checked : bool Js.t)
        : field_class Js.t Js.js_array Js.t =
      let state : Field.t Random_oracle.State.t =
        Array.map (Js.to_array state) ~f:of_js_field |> Obj.magic
      in
      let input = Array.map (Js.to_array xs) ~f:of_js_field in
      let new_state : field_class Js.t array =
        ( if Js.to_bool is_checked then Random_oracle.Checked.update ~state input
        else
          Random_oracle.update
            ~state:(Random_oracle.State.map ~f:to_unchecked state)
            (Array.map ~f:to_unchecked input)
          |> Random_oracle.State.map ~f:Field.constant )
        |> Random_oracle.State.map ~f:to_js_field
        |> Obj.magic
      in
      new_state |> Js.array

    (* returns a "sponge" that stays opaque to JS *)
    method spongeCreate (is_checked : bool Js.t) =
      if Js.to_bool is_checked then
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

    val prefixes =
      let open Hash_prefixes in
      object%js
        val event = Js.string (zkapp_event :> string)

        val events = Js.string (zkapp_events :> string)

        val sequenceEvents = Js.string (zkapp_sequence_events :> string)

        val body = Js.string (zkapp_body :> string)

        val accountUpdateCons = Js.string (account_update_cons :> string)

        val accountUpdateNode = Js.string (account_update_node :> string)
      end
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
           has "toFields" && has "fromFields"
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
        ctor##fromFields arr

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
           let has s = Js.Optdef.test (Js.Unsafe.get ctor (Js.string s)) in
           has "toFields" && has "fromFields"
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
             (* we use Object.create to avoid calling the constructor with the wrong number of arguments *)
             let result =
               Js.Unsafe.global ##. Object##create
                 (Js.Unsafe.coerce ctor1)##.prototype
             in
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
      typ##fromFields
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

  let typ_minimal (type a) (typ : a as_field_elements_minimal Js.t) =
    Typ.array ~length:typ##sizeInFields Field.typ

  let witness_minimal (type a) (typ : a as_field_elements_minimal Js.t)
      (f : (unit -> field_class Js.t Js.js_array Js.t) Js.callback) =
    Impl.exists (typ_minimal typ) ~compute:(fun () ->
        Js.Unsafe.fun_call f [||]
        |> Js.to_array
        |> Array.map ~f:of_js_field_unchecked )
    |> Array.map ~f:to_js_field |> Js.array

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
    (main, typ_ c##.snarkyPublicTyp)

  let generate_keypair (type w p) (c : (w, p) Circuit_main.t) :
      keypair_class Js.t =
    let main, input_typ = main_and_input c in
    let cs =
      Impl.constraint_system ~input_typ ~return_typ:Snark_params.Tick.Typ.unit
        (fun x -> main x)
    in
    let kp = Impl.Keypair.generate ~prev_challenges:0 cs in
    new%js keypair_constr kp

  let constraint_system (main : unit -> unit) =
    let cs =
      Impl.constraint_system ~input_typ:Impl.Typ.unit
        ~return_typ:Snark_params.Tick.Typ.unit (fun () -> main)
    in
    let rows = List.length cs.rows_rev in
    let digest =
      Backend.R1CS_constraint_system.digest cs |> Md5.to_hex |> Js.string
    in
    (* TODO: to_json doesn't return anything; call into kimchi instead *)
    let json =
      Js.Unsafe.(
        fun_call
          global ##. JSON##.parse
          [| inject
               ( Backend.R1CS_constraint_system.to_json cs
               |> Yojson.Safe.to_string |> Js.string )
          |])
    in
    object%js
      val rows = rows

      val digest = digest

      val json = json
    end

  let prove (type w p) (c : (w, p) Circuit_main.t) (priv : w) (pub : p) kp :
      proof_class Js.t =
    let main, input_typ = main_and_input c in
    let pk = Keypair.pk kp in
    let p =
      Impl.generate_witness_conv ~return_typ:Snark_params.Tick.Typ.unit
        ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs } () ->
          Backend.Proof.create pk ~auxiliary:auxiliary_inputs
            ~primary:public_inputs )
        ~input_typ (main ~w:priv) pub
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
    Js.Unsafe.set circuit (Js.string "_constraintSystem") constraint_system ;
    Js.Unsafe.set circuit (Js.string "_witness")
      (Js.wrap_callback witness_minimal) ;
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
          ; uses_lookup = false
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

let name = "smart-contract"

let constraint_constants =
  (* TODO these are dummy values *)
  { Snark_keys_header.Constraint_constants.sub_windows_per_window = 0
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

let pickles_digest (choices : pickles_rule_js Js.js_array Js.t)
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
  try
    let _ =
      Pickles.compile_promise () ~choices ~return_early_digest_exception:true
        ~public_input:(Input (public_input_typ public_input_size))
        ~auxiliary_typ:Typ.unit
        ~branches:(module Branches)
        ~max_proofs_verified:(module Pickles_types.Nat.N0)
        ~name ~constraint_constants
    in
    failwith "Unexpected: The exception will always fire"
  with Pickles.Return_digest md5 -> Md5.to_hex md5 |> Js.string

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
    Pickles.compile_promise () ~choices
      ~public_input:(Input (public_input_typ public_input_size))
      ~auxiliary_typ:Typ.unit
      ~branches:(module Branches)
      ~max_proofs_verified:(module Max_proofs_verified)
      ~name ~constraint_constants
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
            Pickles.Side_loaded.Verification_key.to_base64 vk |> Js.string

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
    match Pickles.Side_loaded.Verification_key.of_base64 (Js.to_string vk) with
    | Ok vk_ ->
        vk_
    | Error err ->
        failwithf "Could not decode base64 verification key: %s"
          (Error.to_string_hum err) ()
  in
  Pickles.Side_loaded.verify_promise ~typ [ (vk, public_input, proof) ]
  |> Promise.map ~f:Js.bool |> Promise_js_helpers.to_js

let dummy_base64_proof () =
  let n2 = Pickles_types.Nat.N2.n in
  let proof = Pickles.Proof.dummy n2 n2 n2 ~domain_log2:15 in
  Proof2.to_base64 proof |> Js.string

let pickles =
  object%js
    val compile = pickles_compile

    val circuitDigest = pickles_digest

    val verify = verify

    val dummyBase64Proof = dummy_base64_proof

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

  type public_key =
    < x : field_class Js.t Js.readonly_prop
    ; isOdd : bool_class Js.t Js.readonly_prop >
    Js.t

  type zkapp_account =
    < appState : field_class Js.t Js.js_array Js.t Js.readonly_prop
    ; verificationKey :
        < hash : Js.js_string Js.t Js.readonly_prop
        ; data : Js.js_string Js.t Js.readonly_prop >
        Js.t
        Js.optdef
        Js.readonly_prop
    ; zkappVersion : int Js.readonly_prop
    ; sequenceState : field_class Js.t Js.js_array Js.t Js.readonly_prop
    ; lastSequenceSlot : int Js.readonly_prop
    ; provedState : bool_class Js.t Js.readonly_prop >
    Js.t

  type permissions =
    < editState : Js.js_string Js.t Js.readonly_prop
    ; send : Js.js_string Js.t Js.readonly_prop
    ; receive : Js.js_string Js.t Js.readonly_prop
    ; setDelegate : Js.js_string Js.t Js.readonly_prop
    ; setPermissions : Js.js_string Js.t Js.readonly_prop
    ; setVerificationKey : Js.js_string Js.t Js.readonly_prop
    ; setZkappUri : Js.js_string Js.t Js.readonly_prop
    ; editSequenceState : Js.js_string Js.t Js.readonly_prop
    ; setTokenSymbol : Js.js_string Js.t Js.readonly_prop
    ; incrementNonce : Js.js_string Js.t Js.readonly_prop
    ; setVotingFor : Js.js_string Js.t Js.readonly_prop >
    Js.t

  type account =
    (* TODO: timing *)
    < publicKey : public_key Js.readonly_prop
    ; tokenId : field_class Js.t Js.readonly_prop
    ; tokenSymbol : Js.js_string Js.t Js.readonly_prop
    ; balance : js_uint64 Js.readonly_prop
    ; nonce : js_uint32 Js.readonly_prop
    ; receiptChainHash : field_class Js.t Js.readonly_prop
    ; delegate : public_key Js.optdef Js.readonly_prop
    ; votingFor : field_class Js.t Js.readonly_prop
    ; zkapp : zkapp_account Js.optdef Js.readonly_prop
    ; permissions : permissions Js.readonly_prop >
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

  let public_key_checked (pk : public_key) :
      Signature_lib.Public_key.Compressed.var =
    { x = pk##.x##.value; is_odd = pk##.isOdd##.value }

  let public_key (pk : public_key) : Signature_lib.Public_key.Compressed.t =
    { x = to_unchecked pk##.x##.value
    ; is_odd = bool_to_unchecked pk##.isOdd##.value
    }

  let private_key (key : private_key) : Signature_lib.Private_key.t =
    Js.Optdef.case
      key##.s##.constantValue
      (fun () -> failwith "invalid scalar")
      Fn.id

  let token_id_checked (token : field_class Js.t) =
    token |> of_js_field |> Mina_base.Token_id.Checked.of_field

  let token_id (token : field_class Js.t) : Mina_base.Token_id.t =
    token |> of_js_field_unchecked |> Mina_base.Token_id.of_field

  let default_token_id_js =
    Mina_base.Token_id.default |> Mina_base.Token_id.to_field_unsafe
    |> Field.constant |> to_js_field

  let account_id_checked pk token =
    Mina_base.Account_id.Checked.create (public_key_checked pk)
      (token_id_checked token)

  let account_id pk token =
    Mina_base.Account_id.create (public_key pk) (token_id token)

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

    let public_key (pk : Signature_lib.Public_key.Compressed.t) : public_key =
      object%js
        val x = to_js_field_unchecked pk.x

        val isOdd =
          new%js bool_constr
            (As_bool.of_boolean @@ Boolean.var_of_value pk.is_odd)
      end

    let token_id (token_id : Mina_base.Token_id.t) =
      token_id |> Mina_base.Token_id.to_field_unsafe |> field

    let private_key (sk : Signature_lib.Private_key.t) = to_js_scalar sk

    let signature (sg : Signature_lib.Schnorr.Chunked.Signature.t) =
      let r, s = sg in
      object%js
        val r = to_js_field_unchecked r

        val s = to_js_scalar s
      end

    let option (transform : 'a -> 'b) (x : 'a option) =
      Js.Optdef.option (Option.map x ~f:transform)

    let app_state s =
      let xs = new%js Js.array_empty in
      Pickles_types.Vector.iter s ~f:(fun x -> ignore (xs##push (field x))) ;
      xs

    let verification_key (vk : Mina_base__Verification_key_wire.Stable.V1.t) =
      object%js
        val data =
          Js.string (Pickles.Side_loaded.Verification_key.to_base64 vk.data)

        val hash = vk.hash |> Field.Constant.to_string |> Js.string
      end

    let zkapp_account (a : Mina_base.Zkapp_account.t) : zkapp_account =
      object%js
        val appState = app_state a.app_state

        val verificationKey = option verification_key a.verification_key

        val zkappVersion = Mina_numbers.Zkapp_version.to_int a.zkapp_version

        val sequenceState = app_state a.sequence_state

        val lastSequenceSlot =
          Mina_numbers.Global_slot.to_int a.last_sequence_slot

        val provedState =
          new%js bool_constr (As_bool.of_js_bool @@ Js.bool a.proved_state)
      end

    let permissions (p : Mina_base.Permissions.t) : permissions =
      object%js
        val editState =
          Js.string (Mina_base.Permissions.Auth_required.to_string p.edit_state)

        val send =
          Js.string (Mina_base.Permissions.Auth_required.to_string p.send)

        val receive =
          Js.string (Mina_base.Permissions.Auth_required.to_string p.receive)

        val setDelegate =
          Js.string
            (Mina_base.Permissions.Auth_required.to_string p.set_delegate)

        val setPermissions =
          Js.string
            (Mina_base.Permissions.Auth_required.to_string p.set_permissions)

        val setVerificationKey =
          Js.string
            (Mina_base.Permissions.Auth_required.to_string
               p.set_verification_key )

        val setZkappUri =
          Js.string
            (Mina_base.Permissions.Auth_required.to_string p.set_zkapp_uri)

        val editSequenceState =
          Js.string
            (Mina_base.Permissions.Auth_required.to_string p.edit_sequence_state)

        val setTokenSymbol =
          Js.string
            (Mina_base.Permissions.Auth_required.to_string p.set_token_symbol)

        val incrementNonce =
          Js.string
            (Mina_base.Permissions.Auth_required.to_string p.increment_nonce)

        val setVotingFor =
          Js.string
            (Mina_base.Permissions.Auth_required.to_string p.set_voting_for)
      end

    let account (a : Mina_base.Account.t) : account =
      object%js
        val publicKey = public_key a.public_key

        val tokenId = token_id a.token_id

        val tokenSymbol = Js.string a.token_symbol

        val balance = uint64 (Currency.Balance.to_uint64 a.balance)

        val nonce = uint32 (Mina_numbers.Account_nonce.to_uint32 a.nonce)

        val receiptChainHash = field (a.receipt_chain_hash :> Impl.field)

        val delegate = option public_key a.delegate

        val votingFor = field (a.voting_for :> Impl.field)

        val zkapp = option zkapp_account a.zkapp

        val permissions = permissions a.permissions
      end
  end

  module Account_update = Mina_base.Account_update
  module Zkapp_command = Mina_base.Zkapp_command

  let account_update_of_json =
    let deriver =
      Account_update.Graphql_repr.deriver
      @@ Fields_derivers_zkapps.Derivers.o ()
    in
    let account_update_of_json (account_update : Js.js_string Js.t) :
        Account_update.t =
      Fields_derivers_zkapps.of_json deriver
        (account_update |> Js.to_string |> Yojson.Safe.from_string)
      |> Account_update.of_graphql_repr
    in
    account_update_of_json

  (* TODO hash two zkapp_command together in the correct way *)

  let hash_account_update (p : Js.js_string Js.t) =
    Account_update.digest (p |> account_update_of_json)
    |> Field.constant |> to_js_field

  let forest_digest_of_field : Field.Constant.t -> Zkapp_command.Digest.Forest.t
      =
    Obj.magic

  let forest_digest_of_field_checked :
      Field.t -> Zkapp_command.Digest.Forest.Checked.t =
    Obj.magic

  let hash_transaction account_updates_hash =
    let account_updates_hash =
      account_updates_hash |> of_js_field |> to_unchecked
      |> forest_digest_of_field
    in
    Zkapp_command.Transaction_commitment.create ~account_updates_hash
    |> Field.constant |> to_js_field

  let hash_transaction_checked account_updates_hash =
    let account_updates_hash =
      account_updates_hash |> of_js_field |> forest_digest_of_field_checked
    in
    Zkapp_command.Transaction_commitment.Checked.create ~account_updates_hash
    |> to_js_field

  type account_update_index = Fee_payer | Other_account_update of int

  let transaction_commitment
      ({ fee_payer; account_updates; memo } as tx : Zkapp_command.t)
      (account_update_index : account_update_index) =
    let commitment = Zkapp_command.commitment tx in
    let full_commitment =
      Zkapp_command.Transaction_commitment.create_complete commitment
        ~memo_hash:(Mina_base.Signed_command_memo.hash memo)
        ~fee_payer_hash:
          (Zkapp_command.Digest.Account_update.create
             (Account_update.of_fee_payer fee_payer) )
    in
    let use_full_commitment =
      match account_update_index with
      | Fee_payer ->
          true
      | Other_account_update i ->
          (List.nth_exn
             (Zkapp_command.Call_forest.to_account_updates account_updates)
             i )
            .body
            .use_full_commitment
    in
    if use_full_commitment then full_commitment else commitment

  let transaction_commitments (tx_json : Js.js_string Js.t) =
    let tx =
      Zkapp_command.of_json @@ Yojson.Safe.from_string @@ Js.to_string tx_json
    in
    let commitment = Zkapp_command.commitment tx in
    let full_commitment =
      Zkapp_command.Transaction_commitment.create_complete commitment
        ~memo_hash:(Mina_base.Signed_command_memo.hash tx.memo)
        ~fee_payer_hash:
          (Zkapp_command.Digest.Account_update.create
             (Account_update.of_fee_payer tx.fee_payer) )
    in
    object%js
      val commitment = to_js_field_unchecked commitment

      val fullCommitment = to_js_field_unchecked full_commitment
    end

  let zkapp_public_input (tx_json : Js.js_string Js.t)
      (account_update_index : int) =
    let tx =
      Zkapp_command.of_json @@ Yojson.Safe.from_string @@ Js.to_string tx_json
    in
    let account_update = List.nth_exn tx.account_updates account_update_index in
    object%js
      val accountUpdate =
        to_js_field_unchecked
          (account_update.elt.account_update_digest :> Impl.field)

      val calls =
        to_js_field_unchecked
          (Zkapp_command.Call_forest.hash account_update.elt.calls :> Impl.field)
    end

  let sign_field_element (x : field_class Js.t) (key : private_key) =
    Signature_lib.Schnorr.Chunked.sign (private_key key)
      (Random_oracle.Input.Chunked.field (x |> of_js_field |> to_unchecked))
    |> Mina_base.Signature.to_base58_check |> Js.string

  let dummy_signature () =
    Mina_base.Signature.(dummy |> to_base58_check) |> Js.string

  let sign_account_update (tx_json : Js.js_string Js.t) (key : private_key)
      (account_update_index : account_update_index) =
    let tx =
      Zkapp_command.of_json @@ Yojson.Safe.from_string @@ Js.to_string tx_json
    in
    let signature =
      Signature_lib.Schnorr.Chunked.sign (private_key key)
        (Random_oracle.Input.Chunked.field
           (transaction_commitment tx account_update_index) )
    in
    ( match account_update_index with
    | Fee_payer ->
        { tx with fee_payer = { tx.fee_payer with authorization = signature } }
    | Other_account_update i ->
        { tx with
          account_updates =
            Zkapp_command.Call_forest.mapi tx.account_updates
              ~f:(fun i' (p : Account_update.t) ->
                if i' = i then { p with authorization = Signature signature }
                else p )
        } )
    |> Zkapp_command.to_json |> Yojson.Safe.to_string |> Js.string

  let sign_fee_payer tx_json key = sign_account_update tx_json key Fee_payer

  let sign_other_account_update tx_json key i =
    sign_account_update tx_json key (Other_account_update i)

  let check_account_update_signatures zkapp_command =
    let ({ fee_payer; account_updates; memo } : Zkapp_command.t) =
      zkapp_command
    in
    let tx_commitment = Zkapp_command.commitment zkapp_command in
    let full_tx_commitment =
      Zkapp_command.Transaction_commitment.create_complete tx_commitment
        ~memo_hash:(Mina_base.Signed_command_memo.hash memo)
        ~fee_payer_hash:
          (Zkapp_command.Digest.Account_update.create
             (Account_update.of_fee_payer fee_payer) )
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
    List.iteri (Zkapp_command.Call_forest.to_account_updates account_updates)
      ~f:(fun i p ->
        let commitment =
          if p.body.use_full_commitment then full_tx_commitment
          else tx_commitment
        in
        match p.authorization with
        | Signature s ->
            check_signature
              (sprintf "account_update %d" i)
              s p.body.public_key commitment
        | Proof _ | None_given ->
            () )

  let public_key_to_string (pk : public_key) : Js.js_string Js.t =
    pk |> public_key |> Signature_lib.Public_key.Compressed.to_base58_check
    |> Js.string

  let public_key_of_string (pk_base58 : Js.js_string Js.t) : public_key =
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

  (* low-level building blocks for encoding *)
  let binary_string_to_base58_check bin_string (version_byte : int) :
      Js.js_string Js.t =
    let module T = struct
      let version_byte = Char.of_int_exn version_byte

      let description = "any"
    end in
    let module B58 = Base58_check.Make (T) in
    bin_string |> B58.encode |> Js.string

  let binary_string_of_base58_check (base58 : Js.js_string Js.t)
      (version_byte : int) =
    let module T = struct
      let version_byte = Char.of_int_exn version_byte

      let description = "any"
    end in
    let module B58 = Base58_check.Make (T) in
    base58 |> Js.to_string |> B58.decode_exn

  let add_account_exn (l : L.t) pk (balance : string) =
    let account_id = account_id pk default_token_id_js in
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

  let get_account l (pk : public_key) (token : field_class Js.t) :
      account Js.optdef =
    let loc = L.location_of_account l##.value (account_id pk token) in
    let account = Option.bind loc ~f:(L.get l##.value) in
    To_js.option To_js.account account

  let add_account l (pk : public_key) (balance : Js.js_string Js.t) =
    add_account_exn l##.value pk (Js.to_string balance)

  let protocol_state_of_json =
    let deriver =
      Mina_base.Zkapp_precondition.Protocol_state.View.deriver
      @@ Fields_derivers_zkapps.o ()
    in
    let of_json = Fields_derivers_zkapps.of_json deriver in
    fun (json : Js.js_string Js.t) :
        Mina_base.Zkapp_precondition.Protocol_state.View.t ->
      json |> Js.to_string |> Yojson.Safe.from_string |> of_json

  let apply_zkapp_command_transaction l (txn : Zkapp_command.t)
      (account_creation_fee : string)
      (network_state : Mina_base.Zkapp_precondition.Protocol_state.View.t) =
    check_account_update_signatures txn ;
    let ledger = l##.value in
    let application_result =
      T.apply_zkapp_command_unchecked ~state_view:network_state
        ~constraint_constants:
          { Genesis_constants.Constraint_constants.compiled with
            account_creation_fee = Currency.Fee.of_string account_creation_fee
          }
        ledger txn
    in
    let applied, _ =
      match application_result with
      | Ok res ->
          res
      | Error err ->
          raise_error (Error.to_string_hum err)
    in
    let T.Transaction_applied.Zkapp_command_applied.{ accounts; command; _ } =
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
      (account_creation_fee : Js.js_string Js.t)
      (network_json : Js.js_string Js.t) =
    let txn =
      Zkapp_command.of_json @@ Yojson.Safe.from_string @@ Js.to_string tx_json
    in
    let network_state = protocol_state_of_json network_json in
    apply_zkapp_command_transaction l txn
      (Js.to_string account_creation_fee)
      network_state

  let check_account_update_signature (account_update_json : Js.js_string Js.t)
      (x : field_class Js.t) =
    let account_update = account_update_of_json account_update_json in
    let check_signature s pk msg =
      match Signature_lib.Public_key.decompress pk with
      | None ->
          false
      | Some pk_ ->
          Signature_lib.Schnorr.Chunked.verify s
            (Kimchi_pasta.Pasta.Pallas.of_affine pk_)
            (Random_oracle_input.Chunked.field msg)
    in

    let isValid =
      match account_update.authorization with
      | Signature s ->
          check_signature s account_update.body.public_key
            (x |> of_js_field |> to_unchecked)
      | Proof _ | None_given ->
          false
    in
    Js.bool isValid

  let create_token_account pk token =
    account_id pk token |> Mina_base.Account_id.public_key
    |> Signature_lib.Public_key.Compressed.to_string |> Js.string

  let custom_token_id_checked pk token =
    Mina_base.Account_id.Checked.derive_token_id
      ~owner:(account_id_checked pk token)
    |> Mina_base.Account_id.Digest.Checked.to_field_unsafe |> to_js_field

  let custom_token_id_unchecked pk token =
    Mina_base.Account_id.derive_token_id ~owner:(account_id pk token)
    |> Mina_base.Token_id.to_field_unsafe |> to_js_field_unchecked

  type random_oracle_input_js =
    < fields : field_class Js.t Js.js_array Js.t Js.readonly_prop
    ; packed :
        < field : field_class Js.t Js.readonly_prop
        ; size : int Js.readonly_prop >
        Js.t
        Js.js_array
        Js.t
        Js.readonly_prop >
    Js.t

  let random_oracle_input_to_js
      (input : Impl.field Random_oracle_input.Chunked.t) :
      random_oracle_input_js =
    let fields =
      input.field_elements |> Array.map ~f:to_js_field_unchecked |> Js.array
    in
    let packed =
      input.packeds
      |> Array.map ~f:(fun (field, size) ->
             object%js
               val field = to_js_field_unchecked field

               val size = size
             end )
      |> Js.array
    in
    object%js
      val fields = fields

      val packed = packed
    end

  let pack_input (input : random_oracle_input_js) :
      field_class Js.t Js.js_array Js.t =
    let field_elements =
      input##.fields |> Js.to_array |> Array.map ~f:of_js_field_unchecked
    in
    let packeds =
      input##.packed |> Js.to_array
      |> Array.map ~f:(fun packed ->
             let field = packed##.field |> of_js_field_unchecked in
             let size = packed##.size in
             (field, size) )
    in
    let input : Impl.field Random_oracle_input.Chunked.t =
      { field_elements; packeds }
    in
    Random_oracle.pack_input input
    |> Array.map ~f:to_js_field_unchecked
    |> Js.array

  let () =
    let static name thing = Js.Unsafe.set ledger_class (Js.string name) thing in
    let static_method name f =
      Js.Unsafe.set ledger_class (Js.string name) (Js.wrap_callback f)
    in
    let method_ name (f : ledger_class Js.t -> _) =
      method_ ledger_class name f
    in
    static_method "customTokenId" custom_token_id_unchecked ;
    static_method "customTokenIdChecked" custom_token_id_checked ;
    static_method "createTokenAccount" create_token_account ;
    static_method "create" create ;

    static_method "transactionCommitments" transaction_commitments ;
    static_method "zkappPublicInput" zkapp_public_input ;
    static_method "signFieldElement" sign_field_element ;
    static_method "dummySignature" dummy_signature ;
    static_method "signFeePayer" sign_fee_payer ;
    static_method "signOtherAccountUpdate" sign_other_account_update ;

    static_method "publicKeyToString" public_key_to_string ;
    static_method "publicKeyOfString" public_key_of_string ;
    static_method "privateKeyToString" private_key_to_string ;
    static_method "privateKeyOfString" private_key_of_string ;

    (* these are implemented in JS, but kept here for consistency tests *)
    static_method "fieldToBase58" field_to_base58 ;
    static_method "fieldOfBase58" field_of_base58 ;

    static_method "memoToBase58" memo_to_base58 ;

    static_method "checkAccountUpdateSignature" check_account_update_signature ;

    let version_bytes =
      let open Base58_check.Version_bytes in
      object%js
        val tokenIdKey = Char.to_int token_id_key

        val receiptChainHash = Char.to_int receipt_chain_hash

        val ledgerHash = Char.to_int ledger_hash

        val epochSeed = Char.to_int epoch_seed

        val stateHash = Char.to_int state_hash
      end
    in
    static "encoding"
      (object%js
         val toBase58 = binary_string_to_base58_check

         val ofBase58 = binary_string_of_base58_check

         val versionBytes = version_bytes
      end ) ;

    static_method "hashAccountUpdateFromJson" hash_account_update ;
    static_method "hashAccountUpdateFromFields"
      (Checked.fields_to_hash
         (Mina_base.Account_update.Body.typ ())
         Mina_base.Account_update.Checked.digest ) ;

    (* TODO this is for debugging, maybe remove later *)
    let body_deriver =
      Mina_base.Account_update.Body.Graphql_repr.deriver
      @@ Fields_derivers_zkapps.o ()
    in
    let body_to_json value =
      value
      |> Account_update.Body.to_graphql_repr ~call_depth:0
      |> Fields_derivers_zkapps.to_json body_deriver
    in
    let body_of_json json =
      json
      |> Fields_derivers_zkapps.of_json body_deriver
      |> Account_update.Body.of_graphql_repr
    in
    static_method "fieldsToJson"
      (fields_to_json (Mina_base.Account_update.Body.typ ()) body_to_json) ;
    static_method "fieldsOfJson"
      (fields_of_json (Mina_base.Account_update.Body.typ ()) body_of_json) ;

    (* hash inputs for various account_update subtypes *)
    (* TODO: this is for testing against JS impl, remove eventually *)
    let timing_input (json : Js.js_string Js.t) : random_oracle_input_js =
      let deriver = Account_update.Update.Timing_info.deriver in
      let json = json |> Js.to_string |> Yojson.Safe.from_string in
      let value = Fields_derivers_zkapps.(of_json (deriver @@ o ()) json) in
      let input = Account_update.Update.Timing_info.to_input value in
      random_oracle_input_to_js input
    in
    let permissions_input (json : Js.js_string Js.t) : random_oracle_input_js =
      let deriver = Mina_base.Permissions.deriver in
      let json = json |> Js.to_string |> Yojson.Safe.from_string in
      let value = Fields_derivers_zkapps.(of_json (deriver @@ o ()) json) in
      let input = Mina_base.Permissions.to_input value in
      random_oracle_input_to_js input
    in
    let update_input (json : Js.js_string Js.t) : random_oracle_input_js =
      let deriver = Account_update.Update.deriver in
      let json = json |> Js.to_string |> Yojson.Safe.from_string in
      let value = Fields_derivers_zkapps.(of_json (deriver @@ o ()) json) in
      let input = Account_update.Update.to_input value in
      random_oracle_input_to_js input
    in
    let account_precondition_input (json : Js.js_string Js.t) :
        random_oracle_input_js =
      let deriver = Mina_base.Zkapp_precondition.Account.deriver in
      let json = json |> Js.to_string |> Yojson.Safe.from_string in
      let value = Fields_derivers_zkapps.(of_json (deriver @@ o ()) json) in
      let input = Mina_base.Zkapp_precondition.Account.to_input value in
      random_oracle_input_to_js input
    in
    let network_precondition_input (json : Js.js_string Js.t) :
        random_oracle_input_js =
      let deriver = Mina_base.Zkapp_precondition.Protocol_state.deriver in
      let json = json |> Js.to_string |> Yojson.Safe.from_string in
      let value = Fields_derivers_zkapps.(of_json (deriver @@ o ()) json) in
      let input = Mina_base.Zkapp_precondition.Protocol_state.to_input value in
      random_oracle_input_to_js input
    in
    let body_input (json : Js.js_string Js.t) : random_oracle_input_js =
      let json = json |> Js.to_string |> Yojson.Safe.from_string in
      let value = body_of_json json in
      let input = Account_update.Body.to_input value in
      random_oracle_input_to_js input
    in

    static "hashInputFromJson"
      (object%js
         val packInput = pack_input

         val timing = timing_input

         val permissions = permissions_input

         val accountPrecondition = account_precondition_input

         val networkPrecondition = network_precondition_input

         val update = update_input

         val body = body_input
      end ) ;

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
