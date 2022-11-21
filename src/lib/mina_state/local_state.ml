open Core_kernel
open Currency
open Mina_base
module Impl = Pickles.Impls.Step

include Mina_transaction_logic.Zkapp_command_logic.Local_state.Value

type display =
  ( string
  , string
  , string
  , string
  , string
  , bool
  , string
  , int
  , string )
  Mina_transaction_logic.Zkapp_command_logic.Local_state.t
[@@deriving yojson]

let display
    ({ stack_frame
     ; call_stack
     ; transaction_commitment
     ; full_transaction_commitment
     ; token_id
     ; excess
     ; supply_increase
     ; ledger
     ; success
     ; account_update_index
     ; failure_status_tbl
     } :
      t ) : display =
  let open Kimchi_backend.Pasta.Basic in
  let f x =
    Visualization.display_prefix_of_string
      (Bigint256.to_hex_string (Fp.to_bigint x))
  in
  let signed_amount_to_string (amt : Currency.Amount.Signed.t) =
    let prefix = match amt.sgn with Sgn.Pos -> "" | Sgn.Neg -> "-" in
    prefix ^ Amount.to_string amt.magnitude
  in
  { Mina_transaction_logic.Zkapp_command_logic.Local_state.stack_frame =
      f (stack_frame :> Fp.t)
  ; call_stack = f (call_stack :> Fp.t)
  ; transaction_commitment = f transaction_commitment
  ; full_transaction_commitment = f full_transaction_commitment
  ; token_id = Token_id.to_string token_id
  ; excess = signed_amount_to_string excess
  ; supply_increase = signed_amount_to_string supply_increase
  ; ledger =
      Visualization.display_prefix_of_string
      @@ Frozen_ledger_hash.to_base58_check ledger
  ; success
  ; account_update_index = Mina_numbers.Index.to_int account_update_index
  ; failure_status_tbl =
      Transaction_status.Failure.Collection.to_display failure_status_tbl
      |> Transaction_status.Failure.Collection.Display.to_yojson
      |> Yojson.Safe.to_string
  }

let dummy : unit -> t =
  Memo.unit (fun () : t ->
      { stack_frame = Stack_frame.Digest.create Stack_frame.empty
      ; call_stack = Call_stack_digest.empty
      ; transaction_commitment = Zkapp_command.Transaction_commitment.empty
      ; full_transaction_commitment = Zkapp_command.Transaction_commitment.empty
      ; token_id = Token_id.default
      ; excess = Amount.(Signed.of_unsigned zero)
      ; supply_increase = Amount.(Signed.of_unsigned zero)
      ; ledger = Frozen_ledger_hash.empty_hash
      ; success = true
      ; account_update_index = Mina_numbers.Index.zero
      ; failure_status_tbl = []
      } )

let empty = dummy

let gen : t Quickcheck.Generator.t =
  let open Quickcheck.Generator.Let_syntax in
  let%map ledger = Frozen_ledger_hash.gen
  and excess = Amount.Signed.gen
  and supply_increase = Amount.Signed.gen
  and transaction_commitment = Impl.Field.Constant.gen
  and stack_frame = Stack_frame.Digest.gen
  and call_stack = Call_stack_digest.gen
  and token_id = Token_id.gen
  and success = Bool.quickcheck_generator
  and account_update_index =
    Mina_numbers.Index.gen
    (*
  and failure_status =
    let%bind failure = Transaction_status.Failure.gen in
    Quickcheck.Generator.of_list [ None; Some failure ]
  *)
  in
  { Mina_transaction_logic.Zkapp_command_logic.Local_state.stack_frame
  ; call_stack
  ; transaction_commitment
  ; full_transaction_commitment = transaction_commitment
  ; token_id
  ; ledger
  ; excess
  ; supply_increase
  ; success
  ; account_update_index
  ; failure_status_tbl = []
  }

let to_input
    ({ stack_frame
     ; call_stack
     ; transaction_commitment
     ; full_transaction_commitment
     ; token_id
     ; excess
     ; supply_increase
     ; ledger
     ; success
     ; account_update_index
     ; failure_status_tbl = _
     } :
      t ) =
  let open Random_oracle.Input.Chunked in
  let open Pickles.Impls.Step in
  Array.reduce_exn ~f:append
    [| field (stack_frame :> Field.Constant.t)
     ; field (call_stack :> Field.Constant.t)
     ; field transaction_commitment
     ; field full_transaction_commitment
     ; Token_id.to_input token_id
     ; Amount.Signed.to_input excess
     ; Amount.Signed.to_input supply_increase
     ; Ledger_hash.to_input ledger
     ; Mina_numbers.Index.to_input account_update_index
     ; packed (Mina_base.Util.field_of_bool success, 1)
    |]

module Checked = struct
  open Impl

  include Mina_transaction_logic.Zkapp_command_logic.Local_state.Checked

  let assert_equal (t1 : t) (t2 : t) =
    let ( ! ) f x y = Impl.run_checked (f x y) in
    let f eq f =
      Impl.with_label (Core_kernel.Field.name f) (fun () ->
          Core_kernel.Field.(eq (get f t1) (get f t2)) )
    in
    Mina_transaction_logic.Zkapp_command_logic.Local_state.Fields.iter
      ~stack_frame:(f Stack_frame.Digest.Checked.Assert.equal)
      ~call_stack:(f Call_stack_digest.Checked.Assert.equal)
      ~transaction_commitment:(f Field.Assert.equal)
      ~full_transaction_commitment:(f Field.Assert.equal)
      ~token_id:(f Token_id.Checked.Assert.equal)
      ~excess:(f !Currency.Amount.Signed.Checked.assert_equal)
      ~supply_increase:(f !Currency.Amount.Signed.Checked.assert_equal)
      ~ledger:(f !Ledger_hash.assert_equal)
      ~success:(f Impl.Boolean.Assert.( = ))
      ~account_update_index:(f !Mina_numbers.Index.Checked.Assert.equal)
      ~failure_status_tbl:(f (fun () () -> ()))

  let equal' (t1 : t) (t2 : t) =
    let ( ! ) f x y = Impl.run_checked (f x y) in
    let f eq acc f = Core_kernel.Field.(eq (get f t1) (get f t2)) :: acc in
    Mina_transaction_logic.Zkapp_command_logic.Local_state.Fields.fold ~init:[]
      ~stack_frame:(f Stack_frame.Digest.Checked.equal)
      ~call_stack:(f Call_stack_digest.Checked.equal)
      ~transaction_commitment:(f Field.equal)
      ~full_transaction_commitment:(f Field.equal)
      ~token_id:(f Token_id.Checked.equal)
      ~excess:(f !Currency.Amount.Signed.Checked.equal)
      ~supply_increase:(f !Currency.Amount.Signed.Checked.equal)
      ~ledger:(f !Ledger_hash.equal_var) ~success:(f Impl.Boolean.equal)
      ~account_update_index:(f !Mina_numbers.Index.Checked.equal)
      ~failure_status_tbl:(f (fun () () -> Impl.Boolean.true_))

  let to_input
      ({ stack_frame
       ; call_stack
       ; transaction_commitment
       ; full_transaction_commitment
       ; token_id
       ; excess
       ; supply_increase
       ; ledger
       ; success
       ; account_update_index
       ; failure_status_tbl = _
       } :
        t ) =
    (* failure_status is the unit value, no need to represent it *)
    let open Random_oracle.Input.Chunked in
    let open Snark_params.Tick.Field.Var in
    Array.reduce_exn ~f:append
      [| field (stack_frame :> t)
       ; field (call_stack :> t)
       ; field transaction_commitment
       ; field full_transaction_commitment
       ; Token_id.Checked.to_input token_id
       ; run_checked (Amount.Signed.Checked.to_input excess)
       ; run_checked (Amount.Signed.Checked.to_input supply_increase)
       ; Ledger_hash.var_to_input ledger
       ; Mina_numbers.Index.Checked.to_input account_update_index
       ; packed ((success :> t), 1)
      |]
end

(* there: map any failure status to the unit value in Checked
   back: map the unit value in Checked to None in the value world
   (an alternative would be to fail, since we intend never to do that,
   and it would make debugging difficult if we ever did that)
*)
let failure_status_tbl_typ :
    (unit, Transaction_status.Failure.Collection.t) Impl.Typ.t =
  Impl.Typ.transport Impl.Typ.unit
    ~there:(fun _failure_status_tbl -> ())
    ~back:(fun () -> [])

let typ : (Checked.t, t) Impl.Typ.t =
  let open Mina_transaction_logic.Zkapp_command_logic.Local_state in
  let open Impl in
  Typ.of_hlistable
    [ Stack_frame.Digest.typ
    ; Call_stack_digest.typ
    ; Field.typ
    ; Field.typ
    ; Token_id.typ
    ; Amount.Signed.typ
    ; Amount.Signed.typ
    ; Ledger_hash.typ
    ; Boolean.typ
    ; Mina_numbers.Index.typ
    ; failure_status_tbl_typ
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist
