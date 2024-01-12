[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params
open Tick
open Currency
open Mina_numbers

(* A timed account is an account, which releases its balance to be spent
   gradually. The process of releasing frozen funds is defined as follows.
   Until the cliff_time global slot is reached, the initial_minimum_balance
   of mina is frozen and cannot be spent. At the cliff slot, cliff_amount
   is released and initial_minimum_balance is effectively lowered by that
   amount. Next, every vesting_period number of slots, vesting_increment
   is released, further decreasing the current minimum balance. At some
   point minimum balance drops to 0, and after that the account behaves
   like an untimed one. *)
module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('slot, 'slot_span, 'balance, 'amount) t =
        | Untimed
        | Timed of
            { initial_minimum_balance : 'balance
            ; cliff_time : 'slot
            ; cliff_amount : 'amount
            ; vesting_period : 'slot_span
            ; vesting_increment : 'amount
            }
      [@@deriving sexp, equal, hash, compare, yojson]
    end
  end]
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      ( Global_slot_since_genesis.Stable.V1.t
      , Global_slot_span.Stable.V1.t
      , Balance.Stable.V1.t
      , Amount.Stable.V1.t )
      Poly.Stable.V2.t
    [@@deriving sexp, equal, hash, compare, yojson]

    let to_latest = Fn.id
  end
end]

type ('slot, 'slot_span, 'balance, 'amount) tt =
      ('slot, 'slot_span, 'balance, 'amount) Poly.t =
  | Untimed
  | Timed of
      { initial_minimum_balance : 'balance
      ; cliff_time : 'slot
      ; cliff_amount : 'amount
      ; vesting_period : 'slot_span
      ; vesting_increment : 'amount
      }
[@@deriving sexp, equal, hash, compare, yojson]

module As_record = struct
  type ('bool, 'slot, 'slot_span, 'balance, 'amount) t =
    { is_timed : 'bool
    ; initial_minimum_balance : 'balance
    ; cliff_time : 'slot
    ; cliff_amount : 'amount
    ; vesting_period : 'slot_span
    ; vesting_increment : 'amount
    }
  [@@deriving equal, hlist, fields, annot]

  let deriver obj =
    let open Fields_derivers_zkapps.Derivers in
    let ( !. ) = ( !. ) ~t_fields_annots in
    Fields.make_creator obj ~is_timed:!.bool ~initial_minimum_balance:!.balance
      ~cliff_time:!.global_slot_since_genesis
      ~cliff_amount:!.amount ~vesting_period:!.global_slot_span
      ~vesting_increment:!.amount
    |> finish "AccountTiming" ~t_toplevel_annots
end

type as_record =
  ( bool
  , Global_slot_since_genesis.Stable.V1.t
  , Global_slot_span.Stable.V1.t
  , Balance.Stable.V1.t
  , Amount.Stable.V1.t )
  As_record.t

(* convert sum type to record format, useful for to_bits and typ *)
let to_record t =
  match t with
  | Untimed ->
      let slot_unused = Global_slot_since_genesis.zero in
      let slot_span_one = Global_slot_span.(succ zero) in
      let balance_unused = Balance.zero in
      let amount_unused = Amount.zero in
      { As_record.is_timed = false
      ; initial_minimum_balance = balance_unused
      ; cliff_time = slot_unused
      ; cliff_amount = amount_unused
      ; vesting_period = slot_span_one (* avoid division by zero *)
      ; vesting_increment = amount_unused
      }
  | Timed
      { initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      } ->
      { is_timed = true
      ; initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      }

let of_record
    { As_record.is_timed
    ; initial_minimum_balance
    ; cliff_time
    ; cliff_amount
    ; vesting_period
    ; vesting_increment
    } : t =
  if is_timed then
    Timed
      { initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      }
  else Untimed

let of_record (r : as_record) : t =
  if r.is_timed then
    Timed
      { initial_minimum_balance = r.initial_minimum_balance
      ; cliff_time = r.cliff_time
      ; cliff_amount = r.cliff_amount
      ; vesting_period = r.vesting_period
      ; vesting_increment = r.vesting_increment
      }
  else Untimed

let to_input t =
  let As_record.
        { is_timed
        ; initial_minimum_balance
        ; cliff_time
        ; cliff_amount
        ; vesting_period
        ; vesting_increment
        } =
    to_record t
  in
  let open Random_oracle_input.Chunked in
  Array.reduce_exn ~f:append
    [| packed ((if is_timed then Field.one else Field.zero), 1)
     ; Balance.to_input initial_minimum_balance
     ; Global_slot_since_genesis.to_input cliff_time
     ; Amount.to_input cliff_amount
     ; Global_slot_span.to_input vesting_period
     ; Amount.to_input vesting_increment
    |]

[%%ifdef consensus_mechanism]

type var =
  ( Boolean.var
  , Global_slot_since_genesis.Checked.var
  , Global_slot_span.Checked.var
  , Balance.var
  , Amount.var )
  As_record.t

let var_to_input
    As_record.
      { is_timed : Boolean.var
      ; initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      } =
  let open Random_oracle_input.Chunked in
  Array.reduce_exn ~f:append
    [| packed ((is_timed :> Field.Var.t), 1)
     ; Balance.var_to_input initial_minimum_balance
     ; Global_slot_since_genesis.Checked.to_input cliff_time
     ; Amount.var_to_input cliff_amount
     ; Global_slot_span.Checked.to_input vesting_period
     ; Amount.var_to_input vesting_increment
    |]

let var_of_t (t : t) : var =
  let { As_record.is_timed
      ; initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      } =
    to_record t
  in
  { is_timed = Boolean.var_of_value is_timed
  ; initial_minimum_balance = Balance.var_of_t initial_minimum_balance
  ; cliff_time = Global_slot_since_genesis.Checked.constant cliff_time
  ; cliff_amount = Amount.var_of_t cliff_amount
  ; vesting_period = Global_slot_span.Checked.constant vesting_period
  ; vesting_increment = Amount.var_of_t vesting_increment
  }

let untimed_var = var_of_t Untimed

let typ : (var, t) Typ.t =
  (* because we represent the types t (a sum type) and var (a record) differently,
      we can't use the trick, used elsewhere, of polymorphic to_hlist and of_hlist
      functions to handle both types
  *)
  let value_of_hlist :
         ( unit
         ,    Boolean.value
           -> Balance.t
           -> Global_slot_since_genesis.t
           -> Amount.t
           -> Global_slot_span.t
           -> Amount.t
           -> unit )
         H_list.t
      -> t =
    let open H_list in
    fun [ is_timed
        ; initial_minimum_balance
        ; cliff_time
        ; cliff_amount
        ; vesting_period
        ; vesting_increment
        ] ->
      if is_timed then
        Timed
          { initial_minimum_balance
          ; cliff_time
          ; cliff_amount
          ; vesting_period
          ; vesting_increment
          }
      else Untimed
  in
  let value_to_hlist (t : t) =
    let As_record.
          { is_timed
          ; initial_minimum_balance
          ; cliff_time
          ; cliff_amount
          ; vesting_period
          ; vesting_increment
          } =
      to_record t
    in
    H_list.
      [ is_timed
      ; initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      ]
  in
  let var_of_hlist = As_record.of_hlist in
  let var_to_hlist = As_record.to_hlist in
  Typ.of_hlistable
    [ Boolean.typ
    ; Balance.typ
    ; Global_slot_since_genesis.typ
    ; Amount.typ
    ; Global_slot_span.typ
    ; Amount.typ
    ]
    ~var_to_hlist ~var_of_hlist ~value_to_hlist ~value_of_hlist

(* we can't use the generic if_ with the above typ, because Global_slot_since_genesis.typ doesn't work correctly with it
    so we define a custom if_
*)
let if_ b ~(then_ : var) ~(else_ : var) =
  let%bind is_timed =
    Boolean.if_ b ~then_:then_.is_timed ~else_:else_.is_timed
  in
  let%bind initial_minimum_balance =
    Balance.Checked.if_ b ~then_:then_.initial_minimum_balance
      ~else_:else_.initial_minimum_balance
  in
  let%bind cliff_time =
    Global_slot_since_genesis.Checked.if_ b ~then_:then_.cliff_time
      ~else_:else_.cliff_time
  in
  let%bind cliff_amount =
    Amount.Checked.if_ b ~then_:then_.cliff_amount ~else_:else_.cliff_amount
  in
  let%bind vesting_period =
    Global_slot_span.Checked.if_ b ~then_:then_.vesting_period
      ~else_:else_.vesting_period
  in
  let%map vesting_increment =
    Amount.Checked.if_ b ~then_:then_.vesting_increment
      ~else_:else_.vesting_increment
  in
  { As_record.is_timed
  ; initial_minimum_balance
  ; cliff_time
  ; cliff_amount
  ; vesting_period
  ; vesting_increment
  }

let deriver obj =
  let open Fields_derivers_zkapps in
  iso_record ~to_record ~of_record As_record.deriver obj

[%%endif]
