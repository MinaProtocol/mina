open Core_kernel
open Currency
open Mina_base
module Impl = Pickles.Impls.Step
include Parties_logic.Local_state.Value

type display =
  ( string
  , string
  , string
  , string
  , bool
  , string
  , string )
  Parties_logic.Local_state.t
[@@deriving yojson]

let display
    ({ parties
     ; call_stack
     ; transaction_commitment
     ; full_transaction_commitment
     ; token_id
     ; excess
     ; ledger
     ; success
     ; failure_status
     } :
      t) : display =
  let f x =
    Visualization.display_prefix_of_string
      Zexe_backend.Pasta.(Bigint256.to_hex_string (Fp.to_bigint x))
  in
  { Parties_logic.Local_state.parties = f parties
  ; call_stack = f call_stack
  ; transaction_commitment = f transaction_commitment
  ; full_transaction_commitment = f full_transaction_commitment
  ; token_id = Token_id.to_string token_id
  ; excess = Amount.to_string excess
  ; ledger =
      Visualization.display_prefix_of_string
      @@ Frozen_ledger_hash.to_base58_check ledger
  ; success
  ; failure_status =
      Option.value_map failure_status ~default:"<no failure>"
        ~f:Transaction_status.Failure.to_string
  }

let dummy : t =
  { parties = Parties.Party_or_stack.With_hashes.empty
  ; call_stack = Parties.Party_or_stack.With_hashes.empty
  ; transaction_commitment = Parties.Transaction_commitment.empty
  ; full_transaction_commitment = Parties.Transaction_commitment.empty
  ; token_id = Token_id.default
  ; excess = Amount.zero
  ; ledger = Frozen_ledger_hash.empty_hash
  ; success = true
  ; failure_status = None
  }

let empty = dummy

let gen : t Quickcheck.Generator.t =
  let open Quickcheck.Generator.Let_syntax in
  let%map ledger = Frozen_ledger_hash.gen
  and excess = Amount.gen
  and transaction_commitment = Impl.Field.Constant.gen
  and parties = Impl.Field.Constant.gen
  and call_stack = Impl.Field.Constant.gen
  and token_id = Token_id.gen
  and success = Bool.quickcheck_generator
  and failure_status =
    let%bind failure = Transaction_status.Failure.gen in
    Quickcheck.Generator.of_list [ None; Some failure ]
  in
  { Parties_logic.Local_state.parties
  ; call_stack
  ; transaction_commitment
  ; full_transaction_commitment = transaction_commitment
  ; token_id
  ; ledger
  ; excess
  ; success
  ; failure_status
  }

let to_input
    ({ parties
     ; call_stack
     ; transaction_commitment
     ; full_transaction_commitment
     ; token_id
     ; excess
     ; ledger
     ; success
     ; failure_status = _
     } :
      t) =
  let open Random_oracle.Input in
  Array.reduce_exn ~f:append
    [| field parties
     ; field call_stack
     ; field transaction_commitment
     ; field full_transaction_commitment
     ; Token_id.to_input token_id
     ; Amount.to_input excess
     ; Ledger_hash.to_input ledger
     ; bitstring [ success ]
    |]

module Checked = struct
  open Impl
  include Parties_logic.Local_state.Checked

  let assert_equal (t1 : t) (t2 : t) =
    let ( ! ) f x y = Impl.run_checked (f x y) in
    let f eq f =
      Impl.with_label (Core_kernel.Field.name f) (fun () ->
          Core_kernel.Field.(eq (get f t1) (get f t2)))
    in
    Parties_logic.Local_state.Fields.iter ~parties:(f Field.Assert.equal)
      ~call_stack:(f Field.Assert.equal)
      ~transaction_commitment:(f Field.Assert.equal)
      ~full_transaction_commitment:(f Field.Assert.equal)
      ~token_id:(f !Token_id.Checked.Assert.equal)
      ~excess:(f !Currency.Amount.Checked.assert_equal)
      ~ledger:(f !Ledger_hash.assert_equal)
      ~success:(f Impl.Boolean.Assert.( = ))
      ~failure_status:(f (fun () () -> ()))

  let equal' (t1 : t) (t2 : t) =
    let ( ! ) f x y = Impl.run_checked (f x y) in
    let f eq acc f = Core_kernel.Field.(eq (get f t1) (get f t2)) :: acc in
    Parties_logic.Local_state.Fields.fold ~init:[] ~parties:(f Field.equal)
      ~call_stack:(f Field.equal) ~transaction_commitment:(f Field.equal)
      ~full_transaction_commitment:(f Field.equal)
      ~token_id:(f !Token_id.Checked.equal)
      ~excess:(f !Currency.Amount.Checked.equal)
      ~ledger:(f !Ledger_hash.equal_var) ~success:(f Impl.Boolean.equal)
      ~failure_status:(f (fun () () -> Impl.Boolean.true_))

  let to_input
      ({ parties
       ; call_stack
       ; transaction_commitment
       ; full_transaction_commitment
       ; token_id
       ; excess
       ; ledger
       ; success
       ; failure_status = _
       } :
        t) =
    (* failure_status is the unit value, no need to represent it *)
    let open Random_oracle.Input in
    Array.reduce_exn ~f:append
      [| field parties
       ; field call_stack
       ; field transaction_commitment
       ; field full_transaction_commitment
       ; run_checked (Token_id.Checked.to_input token_id)
       ; Amount.var_to_input excess
       ; Ledger_hash.var_to_input ledger
       ; bitstring [ success ]
      |]
end

(* there: map any failure status to the unit value in Checked
   back: map the unit value in Checked to None in the value world
   (an alternative would be to fail, since we intend never to do that,
   and it would make debugging difficult if we ever did that)
*)
let failure_status_typ : (unit, Transaction_status.Failure.t option) Impl.Typ.t
    =
  Impl.Typ.transport Impl.Typ.unit
    ~there:(fun _failure_status -> ())
    ~back:(fun () -> None)

let typ : (Checked.t, t) Impl.Typ.t =
  let open Parties_logic.Local_state in
  let open Impl in
  Typ.of_hlistable
    [ Field.typ
    ; Field.typ
    ; Field.typ
    ; Field.typ
    ; Token_id.typ
    ; Amount.typ
    ; Ledger_hash.typ
    ; Boolean.typ
    ; failure_status_typ
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist
