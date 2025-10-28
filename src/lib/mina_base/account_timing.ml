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
  [@@deriving equal, hlist, fields, annot, sexp_of]

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
  , Global_slot_since_genesis.Stable.Latest.t
  , Global_slot_span.Stable.Latest.t
  , Balance.Stable.Latest.t
  , Amount.Stable.Latest.t )
  As_record.t
[@@deriving sexp_of]

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

(** A module defining the vesting parameter update procedure from the slot
    reduction MIP. See
    https://github.com/MinaProtocol/MIPs/blob/main/MIPS/mip-0006-slot-reduction-90s.md.
    To summarize, this vesting parameter update is intended to be applied as an
    edit to the ledgers during a hard fork that reduces the slot time by half.
    The update only applies to accounts that are actively vesting at the time of
    the hard fork; these are accounts that either have not reached their cliff
    time yet, or have reached their cliff time but still have a positive minimum
    balance. The update procedure does the best it can to adjust the account
    timing information so that actively vesting accounts will still unlock funds
    at the same system times as they would have had the hard fork not occurred.
    It will do this perfectly for any account with a "reasonable" vesting
    schedule, i.e., one that will finish before half the remaining life of the
    chain (at the time of the hard fork) has elapsed.

    An important note on the parameters: the slot at which the hard fork occurs
    is called [hardfork_slot] below. This slot is the global slot since genesis
    that is set in the genesis constants of the new (post hard fork) chain. It
    is not the global slot of the hard fork block, nor the [slot_tx_end], nor
    the [slot_chain_end]. The update procedure also assumes that the genesis
    timestamp of the new chain is set to be equal to the timestamp of the
    [hardfork_slot] {i relative to the old (pre hard fork) chain}. This
    simplifies the equations.
*)
module Slot_reduction_update = struct
  open Unsigned

  (** A form of [As_record.t] where all the fields are lifted to
      the same [UInt64.t] type, so the arithmetic in the vesting update
      equations becomes simpler. *)
  type t =
    ( unit
    , Unsigned_extended.UInt64.t
    , Unsigned_extended.UInt64.t
    , Unsigned_extended.UInt64.t
    , Unsigned_extended.UInt64.t )
    As_record.t
  [@@deriving equal, sexp_of]

  let clamp_uint64_to_uint32 x =
    UInt64.(
      if compare x (of_uint32 UInt32.max_int) <= 0 then to_uint32 x
      else UInt32.max_int)

  let of_record (t : as_record) : t =
    { is_timed = ()
    ; initial_minimum_balance = t.initial_minimum_balance |> Balance.to_uint64
    ; cliff_time =
        t.cliff_time |> Global_slot_since_genesis.to_uint32 |> UInt64.of_uint32
    ; cliff_amount = t.cliff_amount |> Amount.to_uint64
    ; vesting_period =
        t.vesting_period |> Global_slot_span.to_uint32 |> UInt64.of_uint32
    ; vesting_increment = t.vesting_increment |> Amount.to_uint64
    }

  (** Convert to a regular [as_record] by clamping all the values
      that might be out of range, as specified in the MIP *)
  let to_record (t : t) : as_record =
    { is_timed = true
    ; initial_minimum_balance = t.initial_minimum_balance |> Balance.of_uint64
    ; cliff_time =
        t.cliff_time |> clamp_uint64_to_uint32
        |> Global_slot_since_genesis.of_uint32
    ; cliff_amount = t.cliff_amount |> Amount.of_uint64
    ; vesting_period =
        t.vesting_period |> clamp_uint64_to_uint32 |> Global_slot_span.of_uint32
    ; vesting_increment = t.vesting_increment |> Amount.of_uint64
    }

  (** Calculate the total number of iterations needed for this account to vest
      completely, beyond the initial cliff unlock. This is [None] (undefined) if
      the vesting increment is zero and the cliff amount is smaller than the
      initial minimum balance. *)
  let vesting_iterations (t : t) : UInt64.t option =
    UInt64.(
      if compare t.initial_minimum_balance t.cliff_amount <= 0 then
        (* Account will complete vesting instantly at the cliff *)
        Some zero
      else if equal t.vesting_increment zero then
        (* Number of iterations is undefined - account is permanently stuck with
           a minimum balance *)
        None
      else
        let balance_to_unlock =
          Infix.(t.initial_minimum_balance - t.cliff_amount)
        in
        let full_increment_iterations =
          Infix.(balance_to_unlock / t.vesting_increment)
        in
        if equal Infix.(balance_to_unlock mod t.vesting_increment) zero then
          (* The account unlocks an equal amount of funds during each iteration *)
          Some full_increment_iterations
        else
          (* The account needs one more iteration to unlock the last little bit
             of funds. Note: if this happens, then full_increment_iterations
             will necessarily be well below UInt64.max_int, because division by
             t.vesting_increment will have decreased balance_to_unlock by a
             factor of at least two. *)
          Some Infix.(full_increment_iterations + one))

  (** True if an account has started vesting but the slot at which it completes
     vesting is still in the future *)
  let is_partially_vested ~global_slot (t : t) =
    let global_slot =
      global_slot |> Global_slot_since_genesis.to_uint32 |> UInt64.of_uint32
    in
    match vesting_iterations t with
    | None ->
        false
    | Some iterations ->
        UInt64.(
          compare global_slot t.cliff_time >= 0
          && compare iterations
               Infix.((global_slot - t.cliff_time) / t.vesting_period)
             > 0)

  (** True if an account has not started vesting *)
  let not_yet_vesting ~global_slot (t : t) =
    let global_slot =
      global_slot |> Global_slot_since_genesis.to_uint32 |> UInt64.of_uint32
    in
    UInt64.compare global_slot t.cliff_time < 0

  (** True if an account is actively vesting, as defined by the slot reduction
      MIP. Note that this is (almost) equivalent to the minimum balance of the
      account being positive at [global_slot].

      One subtlety: this is not equivalent to the statement "the account
      unlocked funds at [global_slot]". Once an account has a minimum balance of
      zero, it is no longer considered to be participating in the vesting
      system. In particular, at the [final_vesting_slot] of the timing the
      account will have unlocked funds, and yet it will not be actively vesting
      at that slot. (Unlocking funds happens between slots, so to speak).

      Second subtlety: this isn't exactly equivalent to the minimum balance of
      an account being positive. If an account has zero [vesting_increment] and
      didn't vest completely at [cliff_time], then it will be stuck with a
      permanent positive minimum balance. Such accounts are not actively
      vesting. See [vesting_iterations]. *)
  let is_actively_vesting ~global_slot (t : t) =
    not_yet_vesting ~global_slot t || is_partially_vested ~global_slot t

  (** Hardfork adjustment assuming that t is actively vesting *)
  let actively_vesting_hardfork_adjustment ~hardfork_slot (t : t) =
    let hardfork_slot =
      hardfork_slot |> Global_slot_since_genesis.to_uint32 |> UInt64.of_uint32
    in
    UInt64.(
      if compare hardfork_slot t.cliff_time < 0 then
        (* t has not started vesting *)
        { t with
          cliff_time =
            (* global_slot and cliff_time are in the uint32 range, so this will
               not wrap *)
            Infix.(hardfork_slot + ((t.cliff_time - hardfork_slot) * of_int 2))
        ; vesting_period =
            (* vesting period is in the uint32 range, so this will not wrap *)
            Infix.(of_int 2 * t.vesting_period)
        }
      else
        (* t is partially but not fully vested *)
        { t with
          initial_minimum_balance =
            (let balance_after_cliff =
               assert (compare t.initial_minimum_balance t.cliff_amount > 0) ;
               Infix.(t.initial_minimum_balance - t.cliff_amount)
             in
             let elapsed_vesting_periods =
               assert (compare t.vesting_period zero > 0) ;
               Infix.((hardfork_slot - t.cliff_time) / t.vesting_period)
             in
             let incremental_unlocked_balance =
               assert (
                 equal elapsed_vesting_periods zero
                 || compare t.vesting_increment
                      (div max_int elapsed_vesting_periods)
                    <= 0 ) ;
               Infix.(t.vesting_increment * elapsed_vesting_periods)
             in
             assert (
               compare balance_after_cliff incremental_unlocked_balance >= 0 ) ;
             Infix.(balance_after_cliff - incremental_unlocked_balance) )
        ; cliff_time =
            (* All the times and spans are in the uint32 range, so none of this
               will overflow *)
            Infix.(
              hardfork_slot
              + of_int 2
                * ( t.vesting_period
                  - ((hardfork_slot - t.cliff_time) mod t.vesting_period) ))
        ; cliff_amount = t.vesting_increment
        ; vesting_period =
            (* vesting_period is in the uint32 range, so this will not wrap *)
            Infix.(of_int 2 * t.vesting_period)
        })

  (** Apply the hardfork adjustment to the given timing, doing nothing if it is
      not actively vesting *)
  let hardfork_adjustment ~hardfork_slot (t : t) =
    if is_actively_vesting ~global_slot:hardfork_slot t then
      actively_vesting_hardfork_adjustment ~hardfork_slot t
    else t
end

(** Apply the slot reduction update to the [as_record] timing. This does nothing
    if the account is not actively vesting at [hardfork_slot]. See the
    [Slot_reduction_update] module documentation for general usage notes. *)
let slot_reduction_update ~hardfork_slot (t : as_record) =
  Slot_reduction_update.(
    t |> of_record |> hardfork_adjustment ~hardfork_slot |> to_record)
