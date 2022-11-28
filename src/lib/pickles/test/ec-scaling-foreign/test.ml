open Core_kernel
open Pickles.Impls.Step

module type S = sig
  type foreign

  val foreign_typ : (foreign, unit) Typ.t

  val zero : foreign

  val assert_equal : foreign -> foreign -> unit

  val range_check : foreign -> unit

  val add_chain : range_check:(foreign -> unit) -> foreign -> foreign -> foreign

  val sub_chain : range_check:(foreign -> unit) -> foreign -> foreign -> foreign

  val mul_chain : range_check:(foreign -> unit) -> foreign -> foreign -> foreign

  val add : range_check:(foreign -> unit) -> foreign -> foreign -> foreign

  val mul : range_check:(foreign -> unit) -> foreign -> foreign -> foreign
end

module Make (Foreign_implementation : S) = struct
  include Foreign_implementation

  (*
     x = s^2 - A_x - B_x
     y = s * (B_x - x) - B_y

     s = (A_y - B_y) / (A_x - B_x)
  *)
  let ec_add (a_x, a_y) (b_x, b_y) =
    let actual_range_check = range_check in
    let range_checks = ref [] in
    let range_check x = range_checks := x :: !range_checks in
    (* diff_x = a_x - b_x *)
    let diff_x = sub_chain ~range_check a_x b_x in
    let s = exists foreign_typ ~compute:(fun () -> ()) in
    (* diff_y = diff_x * s *)
    let diff_y = mul_chain ~range_check diff_x s in
    (* diff_y = a_y - b_y *)
    let a_y' = add_chain ~range_check diff_y b_y in
    assert_equal a_y a_y' ;
    (* s_squared = s * s *)
    let s_squared = mul_chain ~range_check s s in
    (* s_squared_sub_a_x = s * s - a_x *)
    let s_squared_sub_a_x = sub_chain ~range_check s_squared a_x in
    (* x = s * s - a_x - b_x *)
    let x = sub_chain ~range_check s_squared_sub_a_x b_x in
    (* x_change = b_x - x *)
    let neg_x_change = sub_chain ~range_check x b_x in
    (* y_change = (b_x - x) * s *)
    let neg_y_change = mul_chain ~range_check neg_x_change s in
    let y = exists foreign_typ ~compute:(fun () -> ()) in
    (* y = (b_x - x) * s - b_y *)
    let neg_b_y = add_chain ~range_check neg_y_change y in
    let zero' = add_chain ~range_check neg_b_y b_y in
    assert_equal zero zero' ;
    (* Run the deferred range checks *)
    List.iter ~f:actual_range_check !range_checks ;
    (x, y)

  (*
     x = s^2 - 2 A_x
     y = - A_y + s (A_x - x)

     s = (3 A_x^2 + a) / (2 A_y)
  *)
  let ec_double a (a_x, a_y) =
    let actual_range_check = range_check in
    let range_checks = ref [] in
    let range_check x = range_checks := x :: !range_checks in
    (* a_x_squared = a_x * a_x *)
    let a_x_squared = mul_chain ~range_check a_x a_x in
    (* two_a_x_squared = 2 * a_x * a_x *)
    let two_a_x_squared = add_chain ~range_check a_x_squared a_x_squared in
    (* three_a_x_squared = 3 * a_x * a_x *)
    let three_a_x_squared =
      add_chain ~range_check two_a_x_squared a_x_squared
    in
    (* s_numerator = 3 * a_x * a_x + a *)
    let s_numerator = add ~range_check three_a_x_squared a in
    let s_denominator = add_chain ~range_check a_y a_y in
    let s = exists foreign_typ ~compute:(fun () -> ()) in
    let s_numerator' = mul ~range_check s_denominator s in
    assert_equal s_numerator s_numerator' ;
    let s_squared = mul_chain ~range_check s s in
    let s_squared_sub_a_x = sub_chain ~range_check s_squared a_x in
    let x = sub_chain ~range_check s_squared_sub_a_x a_x in
    let x_sub_a_x = sub_chain ~range_check x a_x in
    let s_mul_a_sub_a_x = mul_chain ~range_check x_sub_a_x s in
    let neg_y = add_chain ~range_check s_mul_a_sub_a_x a_y in
    let y = exists foreign_typ ~compute:(fun () -> ()) in
    let zero' = add_chain ~range_check neg_y y in
    assert_equal zero zero' ;
    (* Run the deferred range checks *)
    List.iter ~f:actual_range_check !range_checks ;
    (x, y)

  let pt_typ = Typ.tuple2 foreign_typ foreign_typ

  let circuit a pt scalar_bits =
    let res, _is_zero, _pt =
      Array.fold
        ~init:((zero, zero), Boolean.true_, pt)
        scalar_bits
        ~f:(fun (acc, is_zero, pt) bit ->
          let still_zero = Boolean.(is_zero &&& not bit) in
          let acc_base = if_ is_zero ~typ:pt_typ ~then_:pt ~else_:acc in
          let acc_res = ec_add pt acc_base in
          let acc =
            if_ bit ~typ:pt_typ
              ~then_:(if_ is_zero ~typ:pt_typ ~then_:pt ~else_:acc_res)
              ~else_:acc
          in
          (* NB: We do an unnecessary final double. Optimise before using anywhere. *)
          let double_pt = ec_double a pt in
          (acc, still_zero, double_pt) )
    in
    ignore (res : foreign * foreign)
end

module Foreign_base = struct
  type foreign = Field.t * Field.t * Field.t

  let zero = (Field.zero, Field.zero, Field.zero)

  let foreign_typ =
    Typ.tuple3 Field.typ Field.typ Field.typ
    |> Typ.transport
         ~there:(fun _ ->
           (Field.Constant.zero, Field.Constant.zero, Field.Constant.zero) )
         ~back:(fun _ -> ())

  let assert_equal (x, y, z) (a, b, c) =
    Field.Assert.equal x a ; Field.Assert.equal y b ; Field.Assert.equal z c

  let add_zero_constraint vars =
    assert_
      { annotation = Some __LOC__
      ; basic =
          Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
            (Zero { vars })
      }

  let range_check (x, y, z) =
    (* Requires 4 constraints; inject zeros accordingly. *)
    add_zero_constraint [| x |] ;
    add_zero_constraint [| y |] ;
    add_zero_constraint [| z |] ;
    add_zero_constraint [||]

  (* Assume that we never need to range_check here, because of the range checks
     elsewhere.
  *)
  let add_chain ~range_check:_ (a, b, c) (d, e, f) =
    let res = exists foreign_typ ~compute:(fun () -> ()) in
    add_zero_constraint [| a; b; c; d; e; f |] ;
    res

  let add ~range_check x y =
    let ((a, b, c) as res) = add_chain ~range_check x y in
    add_zero_constraint [| a; b; c |] ;
    res

  let sub_chain ~range_check x y =
    (* We're not really adding valid constraints, so just call add_chain. *)
    add_chain ~range_check x y
end

module Foreign_using_chinese_remainder_theorem = struct
  include Foreign_base

  let mul_chain ~range_check (a, b, c) (d, e, f) =
    let ((q0, q1, q2) as q_upper_bound) =
      exists foreign_typ ~compute:(fun () -> ())
    in
    let ((r0, r1, r2) as r) = exists foreign_typ ~compute:(fun () -> ()) in
    let auxiliaries = exists foreign_typ ~compute:(fun () -> ()) in
    add_zero_constraint [| a; b; c; d; e; f |] ;
    add_zero_constraint [| q0; q1; q2; r0; r1; r2 |] ;
    range_check q_upper_bound ;
    range_check r ;
    range_check auxiliaries ;
    (* Pretend the second r is actually 2^(3*88). *)
    let r_upper_bound = add ~range_check r r in
    range_check r_upper_bound ; r

  let mul ~range_check x y =
    (* No chaining, just pass it on through. *)
    mul_chain ~range_check x y
end

module Foreign_using_naive = struct
  include Foreign_base

  let mul_chain ~range_check (a, b, c) (d, e, f) =
    let ((q0, q1, q2) as q) = exists foreign_typ ~compute:(fun () -> ()) in
    let r = exists foreign_typ ~compute:(fun () -> ()) in
    let ((a0, a1, a2) as auxiliaries) =
      exists foreign_typ ~compute:(fun () -> ())
    in
    add_zero_constraint [| a; b; c; d; e; f |] ;
    add_zero_constraint [| a0; a1; a2; q0; q1; q2 |] ;
    range_check auxiliaries ;
    range_check q ;
    range_check r ;
    r

  let mul ~range_check x y =
    let ((r0, r1, r2) as r) = mul_chain ~range_check x y in
    add_zero_constraint [| r0; r1; r2 |] ;
    r
end

let%test_module "number of constraints" =
  ( module struct
    let count_constraints circuit =
      constraint_count
        ~weight:(function
          | { basic =
                Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                  (Zero _)
            ; _
            } ->
              1
          | _ ->
              0 )
        circuit

    module Make_test (Foreign : S) = struct
      include Make (Foreign)

      let unit_circuit () =
        let a = exists foreign_typ ~compute:(fun () -> ()) in
        let pt =
          exists (Typ.tuple2 foreign_typ foreign_typ) ~compute:(fun () ->
              ((), ()) )
        in
        let scalar_bits =
          (* We create a 258-bit scalar (as booleans) to pretend that we're
             working over secp256k1.
          *)
          exists (Typ.array ~length:258 Boolean.typ) ~compute:(fun () ->
              Array.init 258 ~f:(fun i -> i < 257) )
        in
        circuit a pt scalar_bits
    end

    let%test_unit "crt matches" =
      let module Test = Make_test (Foreign_using_chinese_remainder_theorem) in
      let num_constraints = count_constraints Test.unit_circuit in
      [%test_eq: int] num_constraints 40506 ;
      [%test_eq: int] num_constraints 0x9E3A

    let%test_unit "naive matches" =
      let module Test = Make_test (Foreign_using_naive) in
      let num_constraints = count_constraints Test.unit_circuit in
      [%test_eq: int] num_constraints 29928 ;
      [%test_eq: int] num_constraints 0x74E8
  end )

let%test_module "pickles" =
  ( module struct
    (* Currently, a circuit must have at least 1 of every type of constraint. *)
    let dummy_constraints () =
      let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
      let g =
        exists (Typ.tuple2 Field.typ Field.typ) ~compute:(fun _ ->
            Pickles.Backend.Tick.Inner_curve.(to_affine_exn one) )
      in
      ignore
        ( Pickles.Scalar_challenge.to_field_checked'
            (module Impl)
            ~num_bits:16
            (Kimchi_backend_common.Scalar_challenge.create x)
          : Field.t * Field.t * Field.t ) ;
      ignore
        ( Pickles.Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
          : Pickles.Step_main_inputs.Inner_curve.t ) ;
      ignore
        ( Pickles.Step_verifier.Scalar_challenge.endo g ~num_bits:4
            (Kimchi_backend_common.Scalar_challenge.create x)
          : Field.t * Field.t )

    module Make_test (Foreign : S) = struct
      include Make (Foreign)

      let compile () =
        Pickles.compile ()
          ~public_input:
            (Input
               (Typ.tuple3 foreign_typ
                  (Typ.tuple2 foreign_typ foreign_typ)
                  (Typ.array ~length:258 Boolean.typ) ) )
          ~auxiliary_typ:Typ.unit
          ~branches:(module Pickles_types.Nat.N1)
          ~max_proofs_verified:(module Pickles_types.Nat.N0)
          ~name:"blockchain-snark"
          ~constraint_constants:
            (* Dummy values *)
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
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; prevs = []
              ; uses_lookup = false
              ; main =
                  (fun { public_input = a, pt, scalar } ->
                    dummy_constraints () ;
                    circuit a pt scalar ;
                    { previous_proof_statements = []
                    ; public_output = ()
                    ; auxiliary_output = ()
                    } )
              }
            ] )
    end

    let () = Pickles.Backend.Tick.Keypair.set_urs_info []

    let () = Pickles.Backend.Tock.Keypair.set_urs_info []

    let%test_unit "crt compiles" =
      let module Test = Make_test (Foreign_using_chinese_remainder_theorem) in
      let (_ : _) = Test.compile () in
      ()

    let%test_unit "naive compiles" =
      let module Test = Make_test (Foreign_using_naive) in
      let (_ : _) = Test.compile () in
      ()
  end )
