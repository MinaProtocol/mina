open Core_kernel

module Kimchi_gate_type = struct
  (* Alias to allow deriving sexp *)
  type t = Kimchi_types.gate_type =
    | Zero
    | Generic
    | Poseidon
    | CompleteAdd
    | VarBaseMul
    | EndoMul
    | EndoMulScalar
    | Lookup
    | CairoClaim
    | CairoInstruction
    | CairoFlags
    | CairoTransition
    | RangeCheck0
    | RangeCheck1
    | ForeignFieldAdd
    | ForeignFieldMul
    | Xor16
    | Rot64
  [@@deriving sexp]
end

(** The PLONK constraints. *)
module Plonk_constraint = struct
  (** A PLONK constraint (or gate) can be [Basic], [Poseidon], [EC_add_complete], [EC_scale], [EC_endoscale], [EC_endoscalar], [RangeCheck0], [RangeCheck1], [Xor] *)
  module T = struct
    type ('v, 'f) t =
      | Basic of { l : 'f * 'v; r : 'f * 'v; o : 'f * 'v; m : 'f; c : 'f }
          (** the Poseidon state is an array of states (and states are arrays of size 3). *)
      | Poseidon of { state : 'v array array }
      | EC_add_complete of
          { p1 : 'v * 'v
          ; p2 : 'v * 'v
          ; p3 : 'v * 'v
          ; inf : 'v
          ; same_x : 'v
          ; slope : 'v
          ; inf_z : 'v
          ; x21_inv : 'v
          }
      | EC_scale of { state : 'v Scale_round.t array }
      | EC_endoscale of
          { state : 'v Endoscale_round.t array; xs : 'v; ys : 'v; n_acc : 'v }
      | EC_endoscalar of { state : 'v Endoscale_scalar_round.t array }
      | RangeCheck0 of
          { v0 : 'v (* Value to constrain to 88-bits *)
          ; v0p0 : 'v (* MSBs *)
          ; v0p1 : 'v (* vpX are 12-bit plookup chunks *)
          ; v0p2 : 'v
          ; v0p3 : 'v
          ; v0p4 : 'v
          ; v0p5 : 'v
          ; v0c0 : 'v (* vcX are 2-bit crumbs *)
          ; v0c1 : 'v
          ; v0c2 : 'v
          ; v0c3 : 'v
          ; v0c4 : 'v
          ; v0c5 : 'v
          ; v0c6 : 'v
          ; v0c7 : 'v (* LSBs *)
          ; (* Coefficients *)
            compact : 'f
                (* Limbs mode coefficient: 0 (standard 3-limb) or 1 (compact 2-limb) *)
          }
      | RangeCheck1 of
          { (* Current row *)
            v2 : 'v (* Value to constrain to 88-bits *)
          ; v12 : 'v (* Optional value used in compact 2-limb mode *)
          ; v2c0 : 'v (* MSBs, 2-bit crumb *)
          ; v2p0 : 'v (* vpX are 12-bit plookup chunks *)
          ; v2p1 : 'v
          ; v2p2 : 'v
          ; v2p3 : 'v
          ; v2c1 : 'v (* vcX are 2-bit crumbs *)
          ; v2c2 : 'v
          ; v2c3 : 'v
          ; v2c4 : 'v
          ; v2c5 : 'v
          ; v2c6 : 'v
          ; v2c7 : 'v
          ; v2c8 : 'v (* LSBs *)
          ; (* Next row *) v2c9 : 'v
          ; v2c10 : 'v
          ; v2c11 : 'v
          ; v0p0 : 'v
          ; v0p1 : 'v
          ; v1p0 : 'v
          ; v1p1 : 'v
          ; v2c12 : 'v
          ; v2c13 : 'v
          ; v2c14 : 'v
          ; v2c15 : 'v
          ; v2c16 : 'v
          ; v2c17 : 'v
          ; v2c18 : 'v
          ; v2c19 : 'v
          }
      | Xor of
          { in1 : 'v
          ; in2 : 'v
          ; out : 'v
          ; in1_0 : 'v
          ; in1_1 : 'v
          ; in1_2 : 'v
          ; in1_3 : 'v
          ; in2_0 : 'v
          ; in2_1 : 'v
          ; in2_2 : 'v
          ; in2_3 : 'v
          ; out_0 : 'v
          ; out_1 : 'v
          ; out_2 : 'v
          ; out_3 : 'v
          }
      | ForeignFieldAdd of
          { left_input_lo : 'v
          ; left_input_mi : 'v
          ; left_input_hi : 'v
          ; right_input_lo : 'v
          ; right_input_mi : 'v
          ; right_input_hi : 'v
          ; field_overflow : 'v
          ; carry : 'v
          }
      | ForeignFieldMul of
          { (* Current row *)
            left_input0 : 'v
          ; left_input1 : 'v
          ; left_input2 : 'v
          ; right_input0 : 'v
          ; right_input1 : 'v
          ; right_input2 : 'v
          ; carry1_lo : 'v
          ; carry1_hi : 'v
          ; carry0 : 'v
          ; quotient0 : 'v
          ; quotient1 : 'v
          ; quotient2 : 'v
          ; quotient_bound_carry : 'v
          ; product1_hi_1 : 'v
          ; (* Next row *) remainder0 : 'v
          ; remainder1 : 'v
          ; remainder2 : 'v
          ; quotient_bound01 : 'v
          ; quotient_bound2 : 'v
          ; product1_lo : 'v
          ; product1_hi_0 : 'v
          }
      | Rot64 of
          { (* Current row *)
            word : 'v
          ; rotated : 'v
          ; excess : 'v
          ; bound_limb0 : 'v
          ; bound_limb1 : 'v
          ; bound_limb2 : 'v
          ; bound_limb3 : 'v
          ; bound_crumb0 : 'v
          ; bound_crumb1 : 'v
          ; bound_crumb2 : 'v
          ; bound_crumb3 : 'v
          ; bound_crumb4 : 'v
          ; bound_crumb5 : 'v
          ; bound_crumb6 : 'v
          ; bound_crumb7 : 'v
          ; (* Next row *) shifted : 'v
          ; shifted_limb0 : 'v
          ; shifted_limb1 : 'v
          ; shifted_limb2 : 'v
          ; shifted_limb3 : 'v
          ; shifted_crumb0 : 'v
          ; shifted_crumb1 : 'v
          ; shifted_crumb2 : 'v
          ; shifted_crumb3 : 'v
          ; shifted_crumb4 : 'v
          ; shifted_crumb5 : 'v
          ; shifted_crumb6 : 'v
          ; shifted_crumb7 : 'v
          ; (* Coefficients *) two_to_rot : 'f (* Rotation scalar 2^rot *)
          }
      | Raw of
          { kind : Kimchi_gate_type.t; values : 'v array; coeffs : 'f array }
    [@@deriving sexp]

    (** map t *)
    let map (type a b f) (t : (a, f) t) ~(f : a -> b) =
      let fp (x, y) = (f x, f y) in
      match t with
      | Basic { l; r; o; m; c } ->
          let p (x, y) = (x, f y) in
          Basic { l = p l; r = p r; o = p o; m; c }
      | Poseidon { state } ->
          Poseidon { state = Array.map ~f:(fun x -> Array.map ~f x) state }
      | EC_add_complete { p1; p2; p3; inf; same_x; slope; inf_z; x21_inv } ->
          EC_add_complete
            { p1 = fp p1
            ; p2 = fp p2
            ; p3 = fp p3
            ; inf = f inf
            ; same_x = f same_x
            ; slope = f slope
            ; inf_z = f inf_z
            ; x21_inv = f x21_inv
            }
      | EC_scale { state } ->
          EC_scale
            { state = Array.map ~f:(fun x -> Scale_round.map ~f x) state }
      | EC_endoscale { state; xs; ys; n_acc } ->
          EC_endoscale
            { state = Array.map ~f:(fun x -> Endoscale_round.map ~f x) state
            ; xs = f xs
            ; ys = f ys
            ; n_acc = f n_acc
            }
      | EC_endoscalar { state } ->
          EC_endoscalar
            { state =
                Array.map ~f:(fun x -> Endoscale_scalar_round.map ~f x) state
            }
      | RangeCheck0
          { v0
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
          ; compact
          } ->
          RangeCheck0
            { v0 = f v0
            ; v0p0 = f v0p0
            ; v0p1 = f v0p1
            ; v0p2 = f v0p2
            ; v0p3 = f v0p3
            ; v0p4 = f v0p4
            ; v0p5 = f v0p5
            ; v0c0 = f v0c0
            ; v0c1 = f v0c1
            ; v0c2 = f v0c2
            ; v0c3 = f v0c3
            ; v0c4 = f v0c4
            ; v0c5 = f v0c5
            ; v0c6 = f v0c6
            ; v0c7 = f v0c7
            ; compact
            }
      | RangeCheck1
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
          } ->
          RangeCheck1
            { (* Current row *) v2 = f v2
            ; v12 = f v12
            ; v2c0 = f v2c0
            ; v2p0 = f v2p0
            ; v2p1 = f v2p1
            ; v2p2 = f v2p2
            ; v2p3 = f v2p3
            ; v2c1 = f v2c1
            ; v2c2 = f v2c2
            ; v2c3 = f v2c3
            ; v2c4 = f v2c4
            ; v2c5 = f v2c5
            ; v2c6 = f v2c6
            ; v2c7 = f v2c7
            ; v2c8 = f v2c8
            ; (* Next row *) v2c9 = f v2c9
            ; v2c10 = f v2c10
            ; v2c11 = f v2c11
            ; v0p0 = f v0p0
            ; v0p1 = f v0p1
            ; v1p0 = f v1p0
            ; v1p1 = f v1p1
            ; v2c12 = f v2c12
            ; v2c13 = f v2c13
            ; v2c14 = f v2c14
            ; v2c15 = f v2c15
            ; v2c16 = f v2c16
            ; v2c17 = f v2c17
            ; v2c18 = f v2c18
            ; v2c19 = f v2c19
            }
      | Xor
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
          } ->
          Xor
            { in1 = f in1
            ; in2 = f in2
            ; out = f out
            ; in1_0 = f in1_0
            ; in1_1 = f in1_1
            ; in1_2 = f in1_2
            ; in1_3 = f in1_3
            ; in2_0 = f in2_0
            ; in2_1 = f in2_1
            ; in2_2 = f in2_2
            ; in2_3 = f in2_3
            ; out_0 = f out_0
            ; out_1 = f out_1
            ; out_2 = f out_2
            ; out_3 = f out_3
            }
      | ForeignFieldAdd
          { left_input_lo
          ; left_input_mi
          ; left_input_hi
          ; right_input_lo
          ; right_input_mi
          ; right_input_hi
          ; field_overflow
          ; carry
          } ->
          ForeignFieldAdd
            { left_input_lo = f left_input_lo
            ; left_input_mi = f left_input_mi
            ; left_input_hi = f left_input_hi
            ; right_input_lo = f right_input_lo
            ; right_input_mi = f right_input_mi
            ; right_input_hi = f right_input_hi
            ; field_overflow = f field_overflow
            ; carry = f carry
            }
      | ForeignFieldMul
          { (* Current row *) left_input0
          ; left_input1
          ; left_input2
          ; right_input0
          ; right_input1
          ; right_input2
          ; carry1_lo
          ; carry1_hi
          ; carry0
          ; quotient0
          ; quotient1
          ; quotient2
          ; quotient_bound_carry
          ; product1_hi_1
          ; (* Next row *) remainder0
          ; remainder1
          ; remainder2
          ; quotient_bound01
          ; quotient_bound2
          ; product1_lo
          ; product1_hi_0
          } ->
          ForeignFieldMul
            { (* Current row *) left_input0 = f left_input0
            ; left_input1 = f left_input1
            ; left_input2 = f left_input2
            ; right_input0 = f right_input0
            ; right_input1 = f right_input1
            ; right_input2 = f right_input2
            ; carry1_lo = f carry1_lo
            ; carry1_hi = f carry1_hi
            ; carry0 = f carry0
            ; quotient0 = f quotient0
            ; quotient1 = f quotient1
            ; quotient2 = f quotient2
            ; quotient_bound_carry = f quotient_bound_carry
            ; product1_hi_1 = f product1_hi_1
            ; (* Next row *) remainder0 = f remainder0
            ; remainder1 = f remainder1
            ; remainder2 = f remainder2
            ; quotient_bound01 = f quotient_bound01
            ; quotient_bound2 = f quotient_bound2
            ; product1_lo = f product1_lo
            ; product1_hi_0 = f product1_hi_0
            }
      | Rot64
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
          ; bound_crumb7
          ; (* Next row *) shifted
          ; shifted_limb0
          ; shifted_limb1
          ; shifted_limb2
          ; shifted_limb3
          ; shifted_crumb0
          ; shifted_crumb1
          ; shifted_crumb2
          ; shifted_crumb3
          ; shifted_crumb4
          ; shifted_crumb5
          ; shifted_crumb6
          ; shifted_crumb7
          ; (* Coefficients *) two_to_rot
          } ->
          Rot64
            { (* Current row *) word = f word
            ; rotated = f rotated
            ; excess = f excess
            ; bound_limb0 = f bound_limb0
            ; bound_limb1 = f bound_limb1
            ; bound_limb2 = f bound_limb2
            ; bound_limb3 = f bound_limb3
            ; bound_crumb0 = f bound_crumb0
            ; bound_crumb1 = f bound_crumb1
            ; bound_crumb2 = f bound_crumb2
            ; bound_crumb3 = f bound_crumb3
            ; bound_crumb4 = f bound_crumb4
            ; bound_crumb5 = f bound_crumb5
            ; bound_crumb6 = f bound_crumb6
            ; bound_crumb7 = f bound_crumb7
            ; (* Next row *) shifted = f shifted
            ; shifted_limb0 = f shifted_limb0
            ; shifted_limb1 = f shifted_limb1
            ; shifted_limb2 = f shifted_limb2
            ; shifted_limb3 = f shifted_limb3
            ; shifted_crumb0 = f shifted_crumb0
            ; shifted_crumb1 = f shifted_crumb1
            ; shifted_crumb2 = f shifted_crumb2
            ; shifted_crumb3 = f shifted_crumb3
            ; shifted_crumb4 = f shifted_crumb4
            ; shifted_crumb5 = f shifted_crumb5
            ; shifted_crumb6 = f shifted_crumb6
            ; shifted_crumb7 = f shifted_crumb7
            ; (* Coefficients *) two_to_rot
            }
      | Raw { kind; values; coeffs } ->
          Raw { kind; values = Array.map ~f values; coeffs }

    (** [eval (module F) get_variable gate] checks that [gate]'s polynomial is
        satisfied by the assignments given by [get_variable].
        Warning: currently only implemented for the [Basic] gate.
    *)
    let eval (type v f)
        (module F : Snarky_backendless.Field_intf.S with type t = f)
        (eval_one : v -> f) (t : (v, f) t) =
      match t with
      (* cl * vl + cr * vr + co * vo + m * vl*vr + c = 0 *)
      | Basic { l = cl, vl; r = cr, vr; o = co, vo; m; c } ->
          let vl = eval_one vl in
          let vr = eval_one vr in
          let vo = eval_one vo in
          let open F in
          let res =
            List.reduce_exn ~f:add
              [ mul cl vl; mul cr vr; mul co vo; mul m (mul vl vr); c ]
          in
          if not (equal zero res) then (
            eprintf
              !"%{sexp:t} * %{sexp:t}\n\
                + %{sexp:t} * %{sexp:t}\n\
                + %{sexp:t} * %{sexp:t}\n\
                + %{sexp:t} * %{sexp:t}\n\
                + %{sexp:t}\n\
                = %{sexp:t}%!"
              cl vl cr vr co vo m (mul vl vr) c res ;
            false )
          else true
      | _ ->
          true
  end

  include T

  (* Adds our constraint enum to the list of constraints handled by Snarky. *)
  include Snarky_backendless.Constraint.Add_kind (T)
end

module Make (Field : sig
  type t [@@deriving sexp]

  val zero : t

  val one : t

  val equal : t -> t -> bool

  val mul : t -> t -> t

  val square : t -> t

  val add : t -> t -> t
end)
(Field_var : T) (State : sig
  type t

  val add_boolean_constraint : t -> Field_var.t -> unit

  val add_equal_constraint : t -> Field_var.t -> Field_var.t -> unit

  val add_square_constraint : t -> Field_var.t -> Field_var.t -> unit

  val add_r1cs_constraint :
    t -> Field_var.t -> Field_var.t -> Field_var.t -> unit

  val add_kimchi_constraint :
    t -> (Field_var.t, Field.t) Snarky_bindings.Constraints.kimchi -> unit
end) =
struct
  let add_kimchi_constraint state
      (constr : (Field_var.t, Field.t) Plonk_constraint.t) =
    let open Plonk_constraint in
    match constr with
    | Basic { l; r; o; m; c } ->
        let open Snarky_bindings.Constraints in
        let kimchi_input : (Field_var.t, Field.t) kimchi =
          Basic { l; r; o; m; c }
        in
        State.add_kimchi_constraint state kimchi_input
    | Poseidon { state = poseidon_state } ->
        let open Snarky_bindings.Constraints in
        let kimchi_input : (Field_var.t, Field.t) kimchi =
          Poseidon poseidon_state
        in
        State.add_kimchi_constraint state kimchi_input
    | EC_add_complete { p1; p2; p3; inf; same_x; slope; inf_z; x21_inv } ->
        let open Snarky_bindings.Constraints in
        let kimchi_input : (Field_var.t, Field.t) kimchi =
          EcAddComplete { p1; p2; p3; inf; same_x; slope; inf_z; x21_inv }
        in
        State.add_kimchi_constraint state kimchi_input
    | EC_scale { state = state2 } ->
        let open Snarky_bindings.Constraints in
        let state2 =
          Array.map
            ~f:(fun { accs; bits; ss; base; n_prev; n_next } ->
              Snarky_bindings.Constraints.Inputs.
                { accs; bits; ss; base; n_prev; n_next } )
            state2
        in
        let kimchi_input = EcScale state2 in
        State.add_kimchi_constraint state kimchi_input
    | EC_endoscale { state = state2; xs; ys; n_acc } ->
        let open Snarky_bindings.Constraints in
        let state2 =
          Array.map
            ~f:(fun { xt; yt; xp; yp; n_acc; xr; yr; s1; s3; b1; b2; b3; b4 } ->
              Snarky_bindings.Constraints.Inputs.
                { xt; yt; xp; yp; n_acc; xr; yr; s1; s3; b1; b2; b3; b4 } )
            state2
        in
        let kimchi_input = EcEndoscale { state = state2; xs; ys; n_acc } in
        State.add_kimchi_constraint state kimchi_input
    | EC_endoscalar { state = state2 } ->
        let open Snarky_bindings.Constraints in
        let state2 =
          Array.map
            ~f:(fun { n0; n8; a0; b0; a8; b8; x0; x1; x2; x3; x4; x5; x6; x7 } ->
              Snarky_bindings.Constraints.Inputs.
                { n0; n8; a0; b0; a8; b8; x0; x1; x2; x3; x4; x5; x6; x7 } )
            state2
        in
        let kimchi_input = EcEndoscalar state2 in
        State.add_kimchi_constraint state kimchi_input
    | RangeCheck0 _ ->
        failwith "finish implementing this"
    | RangeCheck1 _ ->
        failwith "finish implementing this"
    | Xor _ ->
        failwith "finish implementing this"
    | ForeignFieldAdd _ ->
        failwith "finish implementing this"
    | ForeignFieldMul _ ->
        failwith "finish implementing this"
    | Rot64 _ ->
        failwith "finish implementing this"
    | Raw _ ->
        failwith "finish implementing this"

  let add_constraint :
         ?label:string
      -> State.t
      -> (Field_var.t, Field.t) Snarky_backendless.Constraint.basic
      -> unit =
   fun ?label state constr ->
    match constr with
    | Snarky_backendless.Constraint.Square (v1, v2) ->
        State.add_square_constraint state v1 v2
    | Snarky_backendless.Constraint.R1CS (v1, v2, v3) ->
        State.add_r1cs_constraint state v1 v2 v3
    | Snarky_backendless.Constraint.Boolean v ->
        State.add_boolean_constraint state v
    | Snarky_backendless.Constraint.Equal (v1, v2) ->
        State.add_equal_constraint state v1 v2
    | Plonk_constraint.T kimchi_constraint ->
        add_kimchi_constraint state kimchi_constraint
    | _ ->
        failwith "unrecognized constraint"
end
