(** Algebraic test for the non-zkApp stake_change spec documented in
    [docs/unstaking-stake-change.md].

    Verifies, for every row of the spec's coverage table and for every
    permission-rejection variant, that three forms agree:

      expanded  =  reduced  =  per_row_formula

    as Fp-valued expressions over the Vesta scalar field.

    - [expanded] applies the definition directly, using the post-gate
      signed deltas as the actual balance changes:

        (fp_bal + Δfp_bal) · fp_staked'  −  fp_bal · fp_staked
          + Δrcv_bal · rcv_staked

    - [reduced] is the unified single-formula reduced form from the doc:

        fp_bal · (fp_staked' − fp_staked)
          + Δfp_bal · fp_staked'
          + Δrcv_bal · rcv_staked

    - [per_row_formula] is the per-row collapsed expression in the
      coverage table's last column.

    Permission failures appear here as scenarios where [Δfp_bal] or
    [Δrcv_bal] is forced to zero — exactly mirroring how the circuit's
    permission gates fold into the actual balance changes (so the
    reduced form needs no separate failure case). *)

open Core_kernel
module F = Snark_params.Tick.Field

let n_samples = 100

(** Boolean variables that affect [fp_staked'] (and so the
    delegate-transition term). Every other gate is folded into
    [Δfp_bal] / [Δrcv_bal]. *)
type bools =
  { is_stake_delegation : bool
  ; user_command_fails : bool
  ; source_delegation_permitted : bool
  ; fp_staked : bool
  ; rcv_staked : bool
  ; set_to_unstaked : bool
  }

(** Encoding-level numerics — the raw advice the unchecked / SNARK code
    sees per row. Δfp_bal and Δrcv_bal are derived from these by
    [materialize] under each scenario's gating constraints. *)
type nums = { fp_bal : F.t; fee : F.t; body_amount : F.t }

let bit b = if b then F.one else F.zero

(** The delegate write fires iff stake_delegation + didn't fail + permitted. *)
let writes_delegate_field (b : bools) =
  b.is_stake_delegation && (not b.user_command_fails)
  && b.source_delegation_permitted

let fp_staked' (b : bools) =
  if writes_delegate_field b then not b.set_to_unstaked else b.fp_staked

let expanded ~delta_fp ~delta_rcv (b : bools) (n : nums) =
  let fp_s = bit b.fp_staked in
  let fp_s' = bit (fp_staked' b) in
  let rcv_s = bit b.rcv_staked in
  F.(((n.fp_bal + delta_fp) * fp_s') - (n.fp_bal * fp_s) + (delta_rcv * rcv_s))

let reduced ~delta_fp ~delta_rcv (b : bools) (n : nums) =
  let fp_s = bit b.fp_staked in
  let fp_s' = bit (fp_staked' b) in
  let rcv_s = bit b.rcv_staked in
  F.((n.fp_bal * (fp_s' - fp_s)) + (delta_fp * fp_s') + (delta_rcv * rcv_s))

(** One constructor per coverage-table row. Permission-rejection variants
    are encoded by per-slot Boolean flags ([fp_rejected], [rcv_rejected])
    rather than by separate constructors. *)
type scenario =
  | Payment of { success : bool; fp_staked : bool; rcv_staked : bool }
      (** [success = true]: row 1. [success = false]: row 2 via the
          8-strict-failures path (rolled back by [user_command_fails]),
          which has the same formula as the permission-rejection
          variant. *)
  | Payment_not_permitted of { fp_staked : bool; rcv_staked : bool }
      (** Row 2 via the receiver permission-rejection path
          ([receive]/[access] rejects). [user_command_fails = false]
          here — the rejection rides on a different gate. *)
  | Delegation_SS of { rcv_staked : bool }
  | Delegation_SN of { rcv_staked : bool }
  | Delegation_NS of { rcv_staked : bool }
  | Delegation_NN of { rcv_staked : bool }
  | Delegation_failed of { fp_staked : bool; rcv_staked : bool }
  | Delegation_not_permitted of { fp_staked : bool; rcv_staked : bool }
  | Fee_transfer_one of { rcv_staked : bool; rcv_rejected : bool }
      (** Row 8. [rcv_rejected]: receive-permission rejection; credit
          burned, [Δrcv_bal = 0]. *)
  | Fee_transfer_two of
      { fp_staked : bool
      ; rcv_staked : bool
      ; fp_rejected : bool
      ; rcv_rejected : bool
      }  (** Row 9. The two rejection flags are independent. *)
  | Coinbase_no_ft of { rcv_staked : bool; rcv_rejected : bool }  (** Row 10. *)
  | Coinbase_with_ft of
      { fp_staked : bool
      ; rcv_staked : bool
      ; fp_rejected : bool
      ; rcv_rejected : bool
      }  (** Row 11. *)
[@@deriving sexp_of]

type concrete = { bools : bools; nums : nums; delta_fp : F.t; delta_rcv : F.t }

let internal_bools ~fp_staked ~rcv_staked =
  { is_stake_delegation = false
  ; user_command_fails = false
  ; source_delegation_permitted = false
  ; fp_staked
  ; rcv_staked
  ; set_to_unstaked = false
  }

let payment_bools ~fp_staked ~rcv_staked ~fails =
  { is_stake_delegation = false
  ; user_command_fails = fails
  ; source_delegation_permitted = false
  ; fp_staked
  ; rcv_staked
  ; set_to_unstaked = false
  }

let delegation_bools ~fp_staked ~rcv_staked ~set_to_unstaked ~permitted ~fails =
  { is_stake_delegation = true
  ; user_command_fails = fails
  ; source_delegation_permitted = permitted
  ; fp_staked
  ; rcv_staked
  ; set_to_unstaked
  }

let materialize (s : scenario) (raw : nums) : concrete =
  match s with
  | Payment { success; fp_staked; rcv_staked } ->
      let delta_fp =
        if success then F.(negate (raw.fee + raw.body_amount))
        else F.negate raw.fee
      in
      let delta_rcv = if success then raw.body_amount else F.zero in
      { bools = payment_bools ~fp_staked ~rcv_staked ~fails:(not success)
      ; nums = raw
      ; delta_fp
      ; delta_rcv
      }
  | Payment_not_permitted { fp_staked; rcv_staked } ->
      { bools = payment_bools ~fp_staked ~rcv_staked ~fails:false
      ; nums = raw
      ; delta_fp = F.negate raw.fee
      ; delta_rcv = F.zero
      }
  | Delegation_SS { rcv_staked } ->
      { bools =
          delegation_bools ~fp_staked:true ~rcv_staked ~set_to_unstaked:false
            ~permitted:true ~fails:false
      ; nums = { raw with body_amount = F.zero }
      ; delta_fp = F.negate raw.fee
      ; delta_rcv = F.zero
      }
  | Delegation_SN { rcv_staked } ->
      { bools =
          delegation_bools ~fp_staked:true ~rcv_staked ~set_to_unstaked:true
            ~permitted:true ~fails:false
      ; nums = { raw with body_amount = F.zero }
      ; delta_fp = F.negate raw.fee
      ; delta_rcv = F.zero
      }
  | Delegation_NS { rcv_staked } ->
      { bools =
          delegation_bools ~fp_staked:false ~rcv_staked ~set_to_unstaked:false
            ~permitted:true ~fails:false
      ; nums = { raw with body_amount = F.zero }
      ; delta_fp = F.negate raw.fee
      ; delta_rcv = F.zero
      }
  | Delegation_NN { rcv_staked } ->
      { bools =
          delegation_bools ~fp_staked:false ~rcv_staked ~set_to_unstaked:true
            ~permitted:true ~fails:false
      ; nums = { raw with body_amount = F.zero }
      ; delta_fp = F.negate raw.fee
      ; delta_rcv = F.zero
      }
  | Delegation_failed { fp_staked; rcv_staked } ->
      { bools =
          delegation_bools ~fp_staked ~rcv_staked ~set_to_unstaked:false
            ~permitted:true ~fails:true
      ; nums = { raw with body_amount = F.zero }
      ; delta_fp = F.negate raw.fee
      ; delta_rcv = F.zero
      }
  | Delegation_not_permitted { fp_staked; rcv_staked } ->
      { bools =
          delegation_bools ~fp_staked ~rcv_staked ~set_to_unstaked:false
            ~permitted:false ~fails:false
      ; nums = { raw with body_amount = F.zero }
      ; delta_fp = F.negate raw.fee
      ; delta_rcv = F.zero
      }
  | Fee_transfer_one { rcv_staked; rcv_rejected } ->
      (* fp ≡ rcv; encoding sets common.fee = 0, body.amount = actual fee. *)
      { bools = internal_bools ~fp_staked:rcv_staked ~rcv_staked
      ; nums = { raw with fee = F.zero }
      ; delta_fp = F.zero
      ; delta_rcv = (if rcv_rejected then F.zero else raw.body_amount)
      }
  | Fee_transfer_two { fp_staked; rcv_staked; fp_rejected; rcv_rejected } ->
      (* fee = fee₂ (fp slot's credit), body.amount = fee₁ (rcv credit). *)
      { bools = internal_bools ~fp_staked ~rcv_staked
      ; nums = raw
      ; delta_fp = (if fp_rejected then F.zero else raw.fee)
      ; delta_rcv = (if rcv_rejected then F.zero else raw.body_amount)
      }
  | Coinbase_no_ft { rcv_staked; rcv_rejected } ->
      (* fp ≡ rcv; common.fee = 0, body.amount = full coinbase. *)
      { bools = internal_bools ~fp_staked:rcv_staked ~rcv_staked
      ; nums = { raw with fee = F.zero }
      ; delta_fp = F.zero
      ; delta_rcv = (if rcv_rejected then F.zero else raw.body_amount)
      }
  | Coinbase_with_ft { fp_staked; rcv_staked; fp_rejected; rcv_rejected } ->
      (* fee = ft_fee, body.amount = full, receiver_increase = full − ft_fee. *)
      { bools = internal_bools ~fp_staked ~rcv_staked
      ; nums = raw
      ; delta_fp = (if fp_rejected then F.zero else raw.fee)
      ; delta_rcv =
          (if rcv_rejected then F.zero else F.(raw.body_amount - raw.fee))
      }

(** Per-row formula from the coverage table's last column, with rejection
    variants zeroing out the corresponding term. *)
let per_row_formula (s : scenario) ({ fp_bal; fee; body_amount; _ } : nums) :
    F.t =
  let scenario_fp_staked = function
    | Payment { fp_staked; _ } | Payment_not_permitted { fp_staked; _ } ->
        fp_staked
    | Delegation_SS _ | Delegation_SN _ ->
        true
    | Delegation_NS _ | Delegation_NN _ ->
        false
    | Delegation_failed { fp_staked; _ }
    | Delegation_not_permitted { fp_staked; _ } ->
        fp_staked
    | Fee_transfer_one { rcv_staked; _ } | Coinbase_no_ft { rcv_staked; _ } ->
        rcv_staked
    | Fee_transfer_two { fp_staked; _ } | Coinbase_with_ft { fp_staked; _ } ->
        fp_staked
  in
  let scenario_rcv_staked = function
    | Payment { rcv_staked; _ }
    | Payment_not_permitted { rcv_staked; _ }
    | Delegation_SS { rcv_staked }
    | Delegation_SN { rcv_staked }
    | Delegation_NS { rcv_staked }
    | Delegation_NN { rcv_staked }
    | Delegation_failed { rcv_staked; _ }
    | Delegation_not_permitted { rcv_staked; _ }
    | Fee_transfer_one { rcv_staked; _ }
    | Fee_transfer_two { rcv_staked; _ }
    | Coinbase_no_ft { rcv_staked; _ }
    | Coinbase_with_ft { rcv_staked; _ } ->
        rcv_staked
  in
  let fp_s = bit (scenario_fp_staked s) in
  let rcv_s = bit (scenario_rcv_staked s) in
  match s with
  | Payment { success = true; _ } ->
      F.(negate (fee * fp_s) + (body_amount * (rcv_s - fp_s)))
  | Payment { success = false; _ } | Payment_not_permitted _ ->
      F.(negate (fee * fp_s))
  | Delegation_SS _ ->
      F.negate fee
  | Delegation_SN _ ->
      F.negate fp_bal
  | Delegation_NS _ ->
      F.(fp_bal - fee)
  | Delegation_NN _ ->
      F.zero
  | Delegation_failed _ | Delegation_not_permitted _ ->
      F.(negate (fee * fp_s))
  | Fee_transfer_one { rcv_rejected; _ } ->
      if rcv_rejected then F.zero else F.(body_amount * rcv_s)
  | Fee_transfer_two { fp_rejected; rcv_rejected; _ } ->
      let fp_term = if fp_rejected then F.zero else F.(fee * fp_s) in
      let rcv_term = if rcv_rejected then F.zero else F.(body_amount * rcv_s) in
      F.(fp_term + rcv_term)
  | Coinbase_no_ft { rcv_rejected; _ } ->
      if rcv_rejected then F.zero else F.(body_amount * rcv_s)
  | Coinbase_with_ft { fp_rejected; rcv_rejected; _ } ->
      let fp_term = if fp_rejected then F.zero else F.(fee * fp_s) in
      let rcv_term =
        if rcv_rejected then F.zero else F.((body_amount - fee) * rcv_s)
      in
      F.(fp_term + rcv_term)

let all_scenarios : scenario list =
  let bs = [ false; true ] in
  let each f = List.concat_map bs ~f in
  List.concat
    [ each (fun success ->
          each (fun fp_staked ->
              each (fun rcv_staked ->
                  [ Payment { success; fp_staked; rcv_staked } ] ) ) )
    ; each (fun fp_staked ->
          each (fun rcv_staked ->
              [ Payment_not_permitted { fp_staked; rcv_staked } ] ) )
    ; each (fun rcv_staked -> [ Delegation_SS { rcv_staked } ])
    ; each (fun rcv_staked -> [ Delegation_SN { rcv_staked } ])
    ; each (fun rcv_staked -> [ Delegation_NS { rcv_staked } ])
    ; each (fun rcv_staked -> [ Delegation_NN { rcv_staked } ])
    ; each (fun fp_staked ->
          each (fun rcv_staked ->
              [ Delegation_failed { fp_staked; rcv_staked } ] ) )
    ; each (fun fp_staked ->
          each (fun rcv_staked ->
              [ Delegation_not_permitted { fp_staked; rcv_staked } ] ) )
    ; each (fun rcv_staked ->
          each (fun rcv_rejected ->
              [ Fee_transfer_one { rcv_staked; rcv_rejected } ] ) )
    ; each (fun fp_staked ->
          each (fun rcv_staked ->
              each (fun fp_rejected ->
                  each (fun rcv_rejected ->
                      [ Fee_transfer_two
                          { fp_staked; rcv_staked; fp_rejected; rcv_rejected }
                      ] ) ) ) )
    ; each (fun rcv_staked ->
          each (fun rcv_rejected ->
              [ Coinbase_no_ft { rcv_staked; rcv_rejected } ] ) )
    ; each (fun fp_staked ->
          each (fun rcv_staked ->
              each (fun fp_rejected ->
                  each (fun rcv_rejected ->
                      [ Coinbase_with_ft
                          { fp_staked; rcv_staked; fp_rejected; rcv_rejected }
                      ] ) ) ) )
    ]

let nums_generator =
  Quickcheck.Generator.map (Quickcheck.Generator.tuple3 F.gen F.gen F.gen)
    ~f:(fun (fp_bal, fee, body_amount) -> { fp_bal; fee; body_amount })

let test_all_forms_agree () =
  let random_state = Splittable_random.State.of_int 0xBADF00D in
  List.iter all_scenarios ~f:(fun s ->
      let label () = Sexp.to_string (sexp_of_scenario s) in
      for _ = 1 to n_samples do
        let raw =
          Quickcheck.Generator.generate nums_generator ~size:100
            ~random:random_state
        in
        let { bools; nums; delta_fp; delta_rcv } = materialize s raw in
        let e = expanded ~delta_fp ~delta_rcv bools nums in
        let r = reduced ~delta_fp ~delta_rcv bools nums in
        let p = per_row_formula s nums in
        if not (F.equal e r) then
          Alcotest.failf "expanded != reduced for %s" (label ()) ;
        if not (F.equal r p) then
          Alcotest.failf "reduced != per_row_formula for %s" (label ())
      done )

let () =
  Alcotest.run "stake_change algebra"
    [ ( "expanded eq reduced eq per_row_formula"
      , [ Alcotest.test_case "over Vesta Fp" `Quick test_all_forms_agree ] )
    ]
