(** Algebraic test for the non-zkApp stake_change spec documented in
    [docs/unstaking-stake-change.md].

    Verifies that for every row of the spec's coverage table:

      expanded  =  reduced  =  per_row_formula

    as Fp-valued expressions over the Vesta scalar field — the same field
    in which the transaction SNARK is evaluated.

    Structure:
    - A [scenario] variant type encodes each coverage-table row as a
      constructor. Invalid Boolean combinations are unrepresentable.
    - [materialize] translates a scenario to [(bools, nums)] under the
      encoding constraints from the table (e.g. [body.amount = 0] for
      stake_delegations, [fee = 0] for Fee_transfer-one-single).
    - [per_row_formula] transcribes the collapsed expression from the
      table's last column.
    - For each scenario (all Boolean-parameterized constructor variants
      enumerated), draw [n_samples] random Fp numerics with a fixed seed
      and assert the three forms agree.

    No SNARK machinery; pure Fp arithmetic. *)

open Core_kernel
module F = Snark_params.Tick.Field

let n_samples = 100

(** The 9 discrete spec variables, as fed to [expanded] / [reduced]. *)
type bools =
  { is_user_command : bool
  ; is_payment : bool
  ; is_stake_delegation : bool
  ; user_command_fails : bool
  ; source_delegation_permitted : bool
  ; payment_permitted : bool
        (** [1] iff the body actually transferred funds — both source and
            receiver permissions allowed it. Implies [is_payment]. *)
  ; fp_staked : bool
  ; rcv_staked : bool
  ; set_to_unstaked : bool
  }

(** The 5 numeric spec variables. *)
type nums =
  { fp_bal : F.t
  ; rcv_bal : F.t
  ; fee : F.t
  ; body_amount : F.t
  ; receiver_increase : F.t
  }

let bit b = if b then F.one else F.zero

(** The write fires iff stake_delegation + didn't fail + permitted. *)
let writes_delegate_field (b : bools) =
  b.is_stake_delegation && (not b.user_command_fails)
  && b.source_delegation_permitted

let fp_staked' (b : bools) =
  if writes_delegate_field b then not b.set_to_unstaked else b.fp_staked

(** A payment body actually moves funds iff permissions allowed it AND none
    of the 8 strict failure modes fired. See doc's "Note on
    [payment_permitted]" for why both gates are required. *)
let payment_active (b : bools) = b.payment_permitted && not b.user_command_fails

let fp_bal_post (b : bools) (n : nums) =
  if b.is_user_command then
    let payment_amount = if payment_active b then n.body_amount else F.zero in
    F.(n.fp_bal - n.fee - payment_amount)
  else F.(n.fp_bal + n.fee)

let rcv_bal_delta (b : bools) (n : nums) =
  if b.is_user_command then if payment_active b then n.body_amount else F.zero
  else n.receiver_increase

let expanded (b : bools) (n : nums) =
  let fp_s = bit b.fp_staked in
  let fp_s' = bit (fp_staked' b) in
  let rcv_s = bit b.rcv_staked in
  F.(
    (fp_bal_post b n * fp_s') - (n.fp_bal * fp_s) + (rcv_bal_delta b n * rcv_s))

let reduced (b : bools) (n : nums) =
  let fp_s = bit b.fp_staked in
  let fp_s' = bit (fp_staked' b) in
  let rcv_s = bit b.rcv_staked in
  if b.is_user_command then
    let transition = F.(n.fp_bal * (fp_s' - fp_s)) in
    let fee_term = F.(negate (n.fee * fp_s')) in
    let body_term =
      if payment_active b then F.(n.body_amount * (rcv_s - fp_s)) else F.zero
    in
    F.(transition + fee_term + body_term)
  else F.((n.fee * fp_s) + (n.receiver_increase * rcv_s))

(** One constructor per row of the coverage table. Invalid Boolean
    combinations are unrepresentable. *)
type scenario =
  | Payment of { success : bool; fp_staked : bool; rcv_staked : bool }
  | Payment_not_permitted of { fp_staked : bool; rcv_staked : bool }
  | Delegation_SS of { rcv_staked : bool }
  | Delegation_SN of { rcv_staked : bool }
  | Delegation_NS of { rcv_staked : bool }
  | Delegation_NN of { rcv_staked : bool }
  | Delegation_failed of { fp_staked : bool; rcv_staked : bool }
  | Delegation_not_permitted of { fp_staked : bool; rcv_staked : bool }
  | Fee_transfer_one of { rcv_staked : bool }
  | Fee_transfer_two of { fp_staked : bool; rcv_staked : bool }
  | Coinbase_no_ft of { rcv_staked : bool }
  | Coinbase_with_ft of { fp_staked : bool; rcv_staked : bool }
[@@deriving sexp_of]

type concrete = { bools : bools; nums : nums }

(** Materialize a scenario as [(bools, nums)] under the encoding
    constraints from the coverage table. Raw random Fp values are passed
    in; per-scenario constraints override specific numeric fields. *)
let materialize (s : scenario) (raw : nums) : concrete =
  let signed_delegation_bools ~fp_staked ~rcv_staked ~set_to_unstaked ~permitted
      ~fails =
    { is_user_command = true
    ; is_payment = false
    ; is_stake_delegation = true
    ; user_command_fails = fails
    ; source_delegation_permitted = permitted
    ; payment_permitted = false
    ; fp_staked
    ; rcv_staked
    ; set_to_unstaked
    }
  in
  let internal_bools ~fp_staked ~rcv_staked =
    { is_user_command = false
    ; is_payment = false
    ; is_stake_delegation = false
    ; user_command_fails = false
    ; source_delegation_permitted = false
    ; payment_permitted = false
    ; fp_staked
    ; rcv_staked
    ; set_to_unstaked = false
    }
  in
  let delegation_nums () =
    { raw with body_amount = F.zero; receiver_increase = F.zero }
  in
  match s with
  | Payment { success; fp_staked; rcv_staked } ->
      (* [success = false] models the "8 strict failures" path
         (e.g., amount_insufficient_to_create), where permissions are fine
         but [user_command_fails = true] triggers the root rollback. *)
      { bools =
          { is_user_command = true
          ; is_payment = true
          ; is_stake_delegation = false
          ; user_command_fails = not success
          ; source_delegation_permitted = false
          ; payment_permitted = true
          ; fp_staked
          ; rcv_staked
          ; set_to_unstaked = false
          }
      ; nums = { raw with receiver_increase = raw.body_amount }
      }
  | Payment_not_permitted { fp_staked; rcv_staked } ->
      (* Permission-rejection path: source/receiver permissions reject, so
         [payment_permitted = false]. The unchecked status is
         Failed [Update_not_permitted_balance], but [user_command_fails]
         (the strict-failures predicate) is false. *)
      { bools =
          { is_user_command = true
          ; is_payment = true
          ; is_stake_delegation = false
          ; user_command_fails = false
          ; source_delegation_permitted = false
          ; payment_permitted = false
          ; fp_staked
          ; rcv_staked
          ; set_to_unstaked = false
          }
      ; nums = { raw with receiver_increase = raw.body_amount }
      }
  | Delegation_SS { rcv_staked } ->
      { bools =
          signed_delegation_bools ~fp_staked:true ~rcv_staked
            ~set_to_unstaked:false ~permitted:true ~fails:false
      ; nums = delegation_nums ()
      }
  | Delegation_SN { rcv_staked } ->
      { bools =
          signed_delegation_bools ~fp_staked:true ~rcv_staked
            ~set_to_unstaked:true ~permitted:true ~fails:false
      ; nums = delegation_nums ()
      }
  | Delegation_NS { rcv_staked } ->
      { bools =
          signed_delegation_bools ~fp_staked:false ~rcv_staked
            ~set_to_unstaked:false ~permitted:true ~fails:false
      ; nums = delegation_nums ()
      }
  | Delegation_NN { rcv_staked } ->
      { bools =
          signed_delegation_bools ~fp_staked:false ~rcv_staked
            ~set_to_unstaked:true ~permitted:true ~fails:false
      ; nums = delegation_nums ()
      }
  | Delegation_failed { fp_staked; rcv_staked } ->
      { bools =
          signed_delegation_bools ~fp_staked ~rcv_staked ~set_to_unstaked:false
            ~permitted:true ~fails:true
      ; nums = delegation_nums ()
      }
  | Delegation_not_permitted { fp_staked; rcv_staked } ->
      { bools =
          signed_delegation_bools ~fp_staked ~rcv_staked ~set_to_unstaked:false
            ~permitted:false ~fails:false
      ; nums = delegation_nums ()
      }
  | Fee_transfer_one { rcv_staked } ->
      (* fp_payer ≡ receiver, so fp_staked = rcv_staked.
         common.fee = 0, body.amount = receiver_increase = (actual fee). *)
      { bools = internal_bools ~fp_staked:rcv_staked ~rcv_staked
      ; nums = { raw with fee = F.zero; receiver_increase = raw.body_amount }
      }
  | Fee_transfer_two { fp_staked; rcv_staked } ->
      (* common.fee = fee₂, body.amount = receiver_increase = fee₁. *)
      { bools = internal_bools ~fp_staked ~rcv_staked
      ; nums = { raw with receiver_increase = raw.body_amount }
      }
  | Coinbase_no_ft { rcv_staked } ->
      (* fp_payer ≡ receiver, common.fee = 0, body.amount = receiver_increase = full. *)
      { bools = internal_bools ~fp_staked:rcv_staked ~rcv_staked
      ; nums = { raw with fee = F.zero; receiver_increase = raw.body_amount }
      }
  | Coinbase_with_ft { fp_staked; rcv_staked } ->
      (* common.fee = ft_fee, body.amount = full, receiver_increase = full - ft_fee. *)
      { bools = internal_bools ~fp_staked ~rcv_staked
      ; nums = { raw with receiver_increase = F.(raw.body_amount - raw.fee) }
      }

(** The per-row collapsed formula from the final column of the coverage
    table. *)
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
    | Fee_transfer_one { rcv_staked } | Coinbase_no_ft { rcv_staked } ->
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
    | Fee_transfer_one { rcv_staked }
    | Fee_transfer_two { rcv_staked; _ }
    | Coinbase_no_ft { rcv_staked }
    | Coinbase_with_ft { rcv_staked; _ } ->
        rcv_staked
  in
  let fp_staked = bit (scenario_fp_staked s) in
  let rcv_staked = bit (scenario_rcv_staked s) in
  match s with
  | Payment { success = true; _ } ->
      F.(negate (fee * fp_staked) + (body_amount * (rcv_staked - fp_staked)))
  | Payment { success = false; _ } | Payment_not_permitted _ ->
      F.(negate (fee * fp_staked))
  | Delegation_SS _ ->
      F.negate fee
  | Delegation_SN _ ->
      F.negate fp_bal
  | Delegation_NS _ ->
      F.(fp_bal - fee)
  | Delegation_NN _ ->
      F.zero
  | Delegation_failed _ | Delegation_not_permitted _ ->
      F.(negate (fee * fp_staked))
  | Fee_transfer_one _ ->
      F.(body_amount * rcv_staked)
  | Fee_transfer_two _ ->
      F.((fee * fp_staked) + (body_amount * rcv_staked))
  | Coinbase_no_ft _ ->
      F.(body_amount * rcv_staked)
  | Coinbase_with_ft _ ->
      F.((fee * fp_staked) + ((body_amount - fee) * rcv_staked))

(** Enumerate every constructor variant. *)
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
    ; each (fun rcv_staked -> [ Fee_transfer_one { rcv_staked } ])
    ; each (fun fp_staked ->
          each (fun rcv_staked ->
              [ Fee_transfer_two { fp_staked; rcv_staked } ] ) )
    ; each (fun rcv_staked -> [ Coinbase_no_ft { rcv_staked } ])
    ; each (fun fp_staked ->
          each (fun rcv_staked ->
              [ Coinbase_with_ft { fp_staked; rcv_staked } ] ) )
    ]

let nums_generator =
  Quickcheck.Generator.map
    (Quickcheck.Generator.tuple5 F.gen F.gen F.gen F.gen F.gen)
    ~f:(fun (fp_bal, rcv_bal, fee, body_amount, receiver_increase) ->
      { fp_bal; rcv_bal; fee; body_amount; receiver_increase } )

let test_all_forms_agree () =
  let random_state = Splittable_random.State.of_int 0xBADF00D in
  List.iter all_scenarios ~f:(fun s ->
      let label () = Sexp.to_string (sexp_of_scenario s) in
      for _ = 1 to n_samples do
        let raw =
          Quickcheck.Generator.generate nums_generator ~size:100
            ~random:random_state
        in
        let { bools; nums } = materialize s raw in
        let e = expanded bools nums in
        let r = reduced bools nums in
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
