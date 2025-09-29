open Core_kernel
module Js = Js_of_ocaml.Js
module Backend = Kimchi_backend.Pasta.Vesta_based_plonk
module Impl = Pickles.Impls.Step
module Field = Impl.Field
module Boolean = Impl.Boolean
module As_prover = Impl.As_prover
module Typ = Impl.Typ
module Run_state = Snarky_backendless.Run_state

type field = Impl.field

(* light-weight wrapper around snarky-ml core *)

let empty_typ : (_, _, unit) Impl.Internal_Basic.Typ.typ' =
  { var_to_fields = (fun fields -> (fields, ()))
  ; var_of_fields = (fun (fields, _) -> fields)
  ; value_to_fields = (fun fields -> (fields, ()))
  ; value_of_fields = (fun (fields, _) -> fields)
  ; size_in_field_elements = 0
  ; constraint_system_auxiliary = (fun _ -> ())
  ; check = (fun _ -> Impl.Internal_Basic.Checked.return ())
  }

let typ (size_in_field_elements : int) : (Field.t array, field array) Typ.t =
  Typ { empty_typ with size_in_field_elements }

module Run = struct
  let exists (size_in_fields : int) (compute : unit -> Field.Constant.t array) =
    Impl.exists (typ size_in_fields) ~compute

  let exists_one (compute : unit -> Field.Constant.t) =
    Impl.exists Field.typ ~compute

  let in_prover () = Impl.in_prover ()

  let as_prover = Impl.as_prover

  let in_prover_block () = As_prover.in_prover_block () |> Js.bool

  let set_eval_constraints b = Snarky_backendless.Snark0.set_eval_constraints b

  let enter_constraint_system () =
    let builder =
      Impl.constraint_system_manual ~input_typ:Impl.Typ.unit
        ~return_typ:Impl.Typ.unit
    in
    builder.run_circuit (fun () () -> ()) ;
    builder.finish_computation

  let enter_generate_witness () =
    let builder =
      Impl.generate_witness_manual ~input_typ:Impl.Typ.unit
        ~return_typ:Impl.Typ.unit ()
    in
    builder.run_circuit (fun () () -> ()) ;
    let finish () = builder.finish_computation () |> fst in
    finish

  let enter_as_prover size = Impl.as_prover_manual size |> Staged.unstage

  module State = struct
    let alloc_var state = Backend.Run_state.alloc_var state ()

    let store_field_elt state x = Backend.Run_state.store_field_elt state x

    let as_prover state = Backend.Run_state.as_prover state

    let set_as_prover state b = Backend.Run_state.set_as_prover state b

    let has_witness state = Backend.Run_state.has_witness state

    let get_variable_value state i =
      Backend.Run_state.get_variable_value state i
  end
end

module Constraint_system = struct
  let rows cs = Backend.R1CS_constraint_system.get_rows_len cs

  let digest cs =
    Backend.R1CS_constraint_system.digest cs |> Md5.to_hex |> Js.string

  let to_json cs =
    Backend.R1CS_constraint_system.to_json cs |> Js.string |> Util.json_parse
end

module Field' = struct
  (** evaluates a CVar by unfolding the AST and reading Vars from a list of public input + aux values *)
  let read_var (x : Field.t) = As_prover.read_var x

  (** x === y without handling of constants *)
  let assert_equal x y = Impl.assert_ (Impl.Constraint.equal x y)

  (** x*y === z without handling of constants *)
  let assert_mul x y z = Impl.assert_ (Impl.Constraint.r1cs x y z)

  (** x*x === y without handling of constants *)
  let assert_square x y = Impl.assert_ (Impl.Constraint.square x y)

  (** x*x === x without handling of constants *)
  let assert_boolean x = Impl.assert_ (Impl.Constraint.boolean x)

  (** check x < y and x <= y.
        this is used in all comparisons, including with assert *)
  let compare (bit_length : int) x y =
    let ({ less; less_or_equal } : Field.comparison_result) =
      Field.compare ~bit_length x y
    in
    (less, less_or_equal)

  (** returns x truncated to the lowest [16 * length_div_16] bits
       => can be used to assert that x fits in [16 * length_div_16] bits.

       more efficient than [to_bits] because it uses the [EC_endoscalar] gate;
       does 16 bits per row (vs 1 bits per row that you can do with generic gates).
    *)
  let truncate_to_bits16 (length_div_16 : int) x =
    let _a, _b, x0 =
      Pickles.Scalar_challenge.to_field_checked' ~num_bits:(length_div_16 * 16)
        (module Impl)
        { inner = x }
    in
    x0
end

let add_gate (label : string) gate =
  Impl.with_label label (fun () -> Impl.assert_ gate)

module Gates = struct
  let zero in1 in2 out =
    add_gate "zero"
      (Raw { kind = Zero; values = [| in1; in2; out |]; coeffs = [||] })

  let generic sl l sr r so o sm sc =
    add_gate "generic"
      (Basic { l = (sl, l); r = (sr, r); o = (so, o); m = sm; c = sc })

  let poseidon state = add_gate "poseidon" (Poseidon { state })

  let ec_add p1 p2 p3 inf same_x slope inf_z x21_inv =
    add_gate "ec_add"
      (EC_add_complete { p1; p2; p3; inf; same_x; slope; inf_z; x21_inv }) ;
    (* TODO: do we need this? *)
    p3

  let ec_scale state = add_gate "ec_scale" (EC_scale { state })

  let ec_endoscale state xs ys n_acc =
    add_gate "ec_endoscale" (EC_endoscale { state; xs; ys; n_acc })

  let ec_endoscalar state = add_gate "ec_endoscalar" (EC_endoscalar { state })

  let lookup (w0, w1, w2, w3, w4, w5, w6) =
    add_gate "lookup" (Lookup { w0; w1; w2; w3; w4; w5; w6 })

  let range_check0 v0 (v0p0, v0p1, v0p2, v0p3, v0p4, v0p5)
      (v0c0, v0c1, v0c2, v0c3, v0c4, v0c5, v0c6, v0c7) compact =
    add_gate "range_check0"
      (RangeCheck0
         { (* Current row *) v0
         ; v0p0
         ; v0p1
         ; v0p2
         ; v0p3
         ; v0p4
         ; v0p5
         ; v0c0
         ; v0c1
         ; v0c2
         ; v0c3
         ; v0c4
         ; v0c5
         ; v0c6
         ; v0c7
         ; (* Coefficients *)
           compact
         } )

  let range_check1 v2 v12
      ( v2c0
      , v2p0
      , v2p1
      , v2p2
      , v2p3
      , v2c1
      , v2c2
      , v2c3
      , v2c4
      , v2c5
      , v2c6
      , v2c7
      , v2c8 )
      ( v2c9
      , v2c10
      , v2c11
      , v0p0
      , v0p1
      , v1p0
      , v1p1
      , v2c12
      , v2c13
      , v2c14
      , v2c15
      , v2c16
      , v2c17
      , v2c18
      , v2c19 ) =
    add_gate "range_check1"
      (RangeCheck1
         { (* Current row *) v2
         ; v12
         ; v2c0
         ; v2p0
         ; v2p1
         ; v2p2
         ; v2p3
         ; v2c1
         ; v2c2
         ; v2c3
         ; v2c4
         ; v2c5
         ; v2c6
         ; v2c7
         ; v2c8
         ; (* Next row *) v2c9
         ; v2c10
         ; v2c11
         ; v0p0
         ; v0p1
         ; v1p0
         ; v1p1
         ; v2c12
         ; v2c13
         ; v2c14
         ; v2c15
         ; v2c16
         ; v2c17
         ; v2c18
         ; v2c19
         } )

  let xor in1 in2 out in1_0 in1_1 in1_2 in1_3 in2_0 in2_1 in2_2 in2_3 out_0
      out_1 out_2 out_3 =
    add_gate "xor"
      (Xor
         { in1
         ; in2
         ; out
         ; in1_0
         ; in1_1
         ; in1_2
         ; in1_3
         ; in2_0
         ; in2_1
         ; in2_2
         ; in2_3
         ; out_0
         ; out_1
         ; out_2
         ; out_3
         } )

  let foreign_field_add (left_input_lo, left_input_mi, left_input_hi)
      (right_input_lo, right_input_mi, right_input_hi) field_overflow carry
      (foreign_field_modulus0, foreign_field_modulus1, foreign_field_modulus2)
      sign =
    add_gate "foreign_field_add"
      (ForeignFieldAdd
         { left_input_lo
         ; left_input_mi
         ; left_input_hi
         ; right_input_lo
         ; right_input_mi
         ; right_input_hi
         ; field_overflow
         ; carry
         ; foreign_field_modulus0
         ; foreign_field_modulus1
         ; foreign_field_modulus2
         ; sign
         } )

  let foreign_field_mul (left_input0, left_input1, left_input2)
      (right_input0, right_input1, right_input2) (remainder01, remainder2)
      (quotient0, quotient1, quotient2) quotient_hi_bound
      (product1_lo, product1_hi_0, product1_hi_1) carry0
      ( carry1_0
      , carry1_12
      , carry1_24
      , carry1_36
      , carry1_48
      , carry1_60
      , carry1_72 ) (carry1_84, carry1_86, carry1_88, carry1_90)
      foreign_field_modulus2
      ( neg_foreign_field_modulus0
      , neg_foreign_field_modulus1
      , neg_foreign_field_modulus2 ) =
    add_gate "foreign_field_mul"
      (ForeignFieldMul
         { left_input0
         ; left_input1
         ; left_input2
         ; right_input0
         ; right_input1
         ; right_input2
         ; remainder01
         ; remainder2
         ; quotient0
         ; quotient1
         ; quotient2
         ; quotient_hi_bound
         ; product1_lo
         ; product1_hi_0
         ; product1_hi_1
         ; carry0
         ; carry1_0
         ; carry1_12
         ; carry1_24
         ; carry1_36
         ; carry1_48
         ; carry1_60
         ; carry1_72
         ; carry1_84
         ; carry1_86
         ; carry1_88
         ; carry1_90
         ; foreign_field_modulus2
         ; neg_foreign_field_modulus0
         ; neg_foreign_field_modulus1
         ; neg_foreign_field_modulus2
         } )

  let rotate word rotated excess
      (bound_limb0, bound_limb1, bound_limb2, bound_limb3)
      ( bound_crumb0
      , bound_crumb1
      , bound_crumb2
      , bound_crumb3
      , bound_crumb4
      , bound_crumb5
      , bound_crumb6
      , bound_crumb7 ) two_to_rot =
    add_gate "rot64"
      (Rot64
         { (* Current row *) word
         ; rotated
         ; excess
         ; bound_limb0
         ; bound_limb1
         ; bound_limb2
         ; bound_limb3
         ; bound_crumb0
         ; bound_crumb1
         ; bound_crumb2
         ; bound_crumb3
         ; bound_crumb4
         ; bound_crumb5
         ; bound_crumb6
         ; bound_crumb7 (* Coefficients *)
         ; two_to_rot (* Rotation scalar 2^rot *)
         } )

  let add_fixed_lookup_table id data =
    add_gate "add_fixed_lookup_table" (AddFixedLookupTable { id; data })

  let add_runtime_table_config id first_column =
    add_gate "add_runtime_table_config" (AddRuntimeTableCfg { id; first_column })

  let raw kind values coeffs = add_gate "raw" (Raw { kind; values; coeffs })
end

module Group = struct
  let scale_fast_unpack (base : Field.t * Field.t)
      (scalar : Field.t Pickles_types.Shifted_value.Type1.t) num_bits :
      (Field.t * Field.t) * Boolean.var array =
    Pickles.Step_main_inputs.Ops.scale_fast_unpack base scalar ~num_bits
end

module Circuit = struct
  module Main = struct
    let of_js (main : Field.t array -> unit) =
      let main' public_input () = main public_input in
      main'
  end

  let compile main public_input_size lazy_mode =
    let input_typ = typ public_input_size in
    let return_typ = Impl.Typ.unit in
    let cs = Impl.constraint_system ~input_typ ~return_typ (Main.of_js main) in
    Impl.Keypair.generate ~lazy_mode ~prev_challenges:0 cs

  let prove main public_input_size public_input keypair =
    let pk = Impl.Keypair.pk keypair in
    let input_typ = typ public_input_size in
    let return_typ = Impl.Typ.unit in
    Impl.generate_witness_conv ~input_typ ~return_typ
      ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs } () ->
        Backend.Proof.create pk ~auxiliary:auxiliary_inputs
          ~primary:public_inputs )
      (Main.of_js main) public_input

  let verify public_input proof vk =
    let public_input_vec = Backend.Field.Vector.create () in
    Array.iter public_input ~f:(fun x ->
        Backend.Field.Vector.emplace_back public_input_vec x ) ;
    Backend.Proof.verify proof vk public_input_vec |> Js.bool

  module Keypair = struct
    let get_vk t = Impl.Keypair.vk t

    external prover_to_json :
      Kimchi_bindings.Protocol.Index.Fp.t -> Js.js_string Js.t
      = "prover_to_json"

    let get_cs_json t =
      (Impl.Keypair.pk t).index |> prover_to_json |> Util.json_parse
  end
end

module Poseidon = struct
  let update (state : Field.t Random_oracle.State.t) (input : Field.t array) :
      Field.t Random_oracle.State.t =
    Random_oracle.Checked.update ~state input

  let hash_to_group (xs : Field.t array) =
    let input = Random_oracle.Checked.hash xs in
    Snark_params.Group_map.Checked.to_group input

  (* sponge *)

  let to_unchecked (x : Field.t) =
    match x with Constant y -> y | y -> As_prover.read_var y

  module Poseidon_sponge_checked =
    Sponge.Make_sponge (Pickles.Step_main_inputs.Sponge.Permutation)
  module Poseidon_sponge =
    Sponge.Make_sponge (Sponge.Poseidon (Pickles.Tick_field_sponge.Inputs))

  let sponge_params = Kimchi_pasta_basic.poseidon_params_fp

  let sponge_params_checked = Sponge.Params.map sponge_params ~f:Field.constant

  type sponge =
    | Checked of Poseidon_sponge_checked.t
    | Unchecked of Poseidon_sponge.t

  (* returns a "sponge" that stays opaque to JS *)
  let sponge_create (is_checked : bool Js.t) : sponge =
    if Js.to_bool is_checked then
      Checked (Poseidon_sponge_checked.create ?init:None sponge_params_checked)
    else Unchecked (Poseidon_sponge.create ?init:None sponge_params)

  let sponge_absorb (sponge : sponge) (field : Field.t) : unit =
    match sponge with
    | Checked s ->
        Poseidon_sponge_checked.absorb s field
    | Unchecked s ->
        Poseidon_sponge.absorb s @@ to_unchecked field

  let sponge_squeeze (sponge : sponge) : Field.t =
    match sponge with
    | Checked s ->
        Poseidon_sponge_checked.squeeze s
    | Unchecked s ->
        Poseidon_sponge.squeeze s |> Impl.Field.constant
end

let snarky =
  object%js
    val run =
      let open Run in
      object%js
        method exists = exists

        method existsOne = exists_one

        val inProver = in_prover

        method asProver = as_prover

        val inProverBlock = in_prover_block

        val setEvalConstraints = set_eval_constraints

        val enterConstraintSystem = enter_constraint_system

        val enterGenerateWitness = enter_generate_witness

        val enterAsProver = enter_as_prover

        val state =
          object%js
            val allocVar = State.alloc_var

            val storeFieldElt = State.store_field_elt

            val asProver = State.as_prover

            val setAsProver = State.set_as_prover

            val hasWitness = State.has_witness

            val getVariableValue = State.get_variable_value
          end
      end

    val constraintSystem =
      object%js
        method rows = Constraint_system.rows

        method digest = Constraint_system.digest

        method toJson = Constraint_system.to_json
      end

    val field =
      let open Field' in
      object%js
        method readVar = read_var

        method assertEqual = assert_equal

        method assertMul = assert_mul

        method assertSquare = assert_square

        method assertBoolean = assert_boolean

        method compare = compare

        method truncateToBits16 = truncate_to_bits16
      end

    val gates =
      object%js
        method zero = Gates.zero

        method generic = Gates.generic

        method poseidon = Gates.poseidon

        method ecAdd = Gates.ec_add

        method ecScale = Gates.ec_scale

        method ecEndoscale = Gates.ec_endoscale

        method ecEndoscalar = Gates.ec_endoscalar

        method lookup = Gates.lookup

        method rangeCheck0 = Gates.range_check0

        method rangeCheck1 = Gates.range_check1

        method xor = Gates.xor

        method foreignFieldAdd = Gates.foreign_field_add

        method foreignFieldMul = Gates.foreign_field_mul

        method rotate = Gates.rotate

        method addFixedLookupTable = Gates.add_fixed_lookup_table

        method addRuntimeTableConfig = Gates.add_runtime_table_config

        method raw = Gates.raw
      end

    val group =
      object%js
        val scaleFastUnpack = Group.scale_fast_unpack
      end

    val circuit =
      object%js
        method compile = Circuit.compile

        method prove = Circuit.prove

        method verify = Circuit.verify

        val keypair =
          object%js
            method getVerificationKey = Circuit.Keypair.get_vk

            method getConstraintSystemJSON = Circuit.Keypair.get_cs_json
          end
      end

    val poseidon =
      object%js
        method update = Poseidon.update

        method hashToGroup = Poseidon.hash_to_group

        val sponge =
          object%js
            method create = Poseidon.sponge_create

            method absorb = Poseidon.sponge_absorb

            method squeeze = Poseidon.sponge_squeeze
          end
      end
  end
