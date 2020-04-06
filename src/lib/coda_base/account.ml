(* account.ml *)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params
open Tick
open Snark_bits

[%%else]

open Snark_params_nonconsensus
open Snark_bits_nonconsensus
module Currency = Currency_nonconsensus.Currency
module Coda_numbers = Coda_numbers_nonconsensus.Coda_numbers
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

open Currency
open Coda_numbers
open Fold_lib
open Import

module Index = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = int [@@deriving to_yojson, sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving to_yojson, sexp]

  let to_int = Int.to_int

  let gen = Int.gen_incl 0 ((1 lsl ledger_depth) - 1)

  module Table = Int.Table

  module Vector = struct
    include Int

    let length = ledger_depth

    let empty = zero

    let get t i = (t lsr i) land 1 = 1

    let set v i b = if b then v lor (one lsl i) else v land lnot (one lsl i)
  end

  include (
    Bits.Vector.Make (Vector) : Bits_intf.Convertible_bits with type t := t)

  let fold_bits = fold

  let fold t = Fold.group3 ~default:false (fold_bits t)

  [%%ifdef
  consensus_mechanism]

  include Bits.Snarkable.Small_bit_vector (Tick) (Vector)

  [%%endif]
end

module Nonce = Account_nonce

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('pk, 'amount, 'nonce, 'receipt_chain_hash, 'state_hash, 'timing) t =
        { public_key: 'pk
        ; balance: 'amount
        ; nonce: 'nonce
        ; receipt_chain_hash: 'receipt_chain_hash
        ; delegate: 'pk
        ; voting_for: 'state_hash
        ; timing: 'timing }
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type ('pk, 'amount, 'nonce, 'receipt_chain_hash, 'state_hash, 'timing) t =
        ( 'pk
        , 'amount
        , 'nonce
        , 'receipt_chain_hash
        , 'state_hash
        , 'timing )
        Stable.Latest.t =
    { public_key: 'pk
    ; balance: 'amount
    ; nonce: 'nonce
    ; receipt_chain_hash: 'receipt_chain_hash
    ; delegate: 'pk
    ; voting_for: 'state_hash
    ; timing: 'timing }
  [@@deriving sexp, eq, compare, hash, yojson, fields]
end

module Key = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Public_key.Compressed.Stable.V1.t
      [@@deriving sexp, eq, hash, compare, yojson]

      let to_latest = Fn.id
    end
  end]
end

type key = Key.Stable.Latest.t [@@deriving sexp, eq, hash, compare, yojson]

module Timing = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('slot, 'balance, 'amount) t =
          | Untimed
          | Timed of
              { initial_minimum_balance: 'balance
              ; cliff_time: 'slot
              ; vesting_period: 'slot
              ; vesting_increment: 'amount }
        [@@deriving sexp, eq, hash, compare, yojson]
      end
    end]

    type ('slot, 'balance, 'amount) t =
          ('slot, 'balance, 'amount) Stable.Latest.t =
      | Untimed
      | Timed of
          { initial_minimum_balance: 'balance
          ; cliff_time: 'slot
          ; vesting_period: 'slot
          ; vesting_increment: 'amount }
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Global_slot.Stable.V1.t
        , Balance.Stable.V1.t
        , Amount.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, eq, hash, compare, yojson]

      let to_latest = Fn.id
    end
  end]

  type ('slot, 'balance, 'amount) tt = ('slot, 'balance, 'amount) Poly.t =
    | Untimed
    | Timed of
        { initial_minimum_balance: 'balance
        ; cliff_time: 'slot
        ; vesting_period: 'slot
        ; vesting_increment: 'amount }
  [@@deriving sexp, eq, hash, compare, yojson]

  type t = (Global_slot.t, Balance.t, Amount.t) tt
  [@@deriving sexp, eq, hash, compare, yojson]

  module As_record = struct
    type ('bool, 'slot, 'balance, 'amount) t =
      { is_timed: 'bool
      ; initial_minimum_balance: 'balance
      ; cliff_time: 'slot
      ; vesting_period: 'slot
      ; vesting_increment: 'amount }
  end

  (* convert sum type to record format, useful for to_bits and typ *)
  let to_record t =
    match t with
    | Untimed ->
        let slot_unused = Global_slot.zero in
        let slot_one = Global_slot.(succ zero) in
        let balance_unused = Balance.zero in
        let amount_unused = Amount.zero in
        As_record.
          { is_timed= false
          ; initial_minimum_balance= balance_unused
          ; cliff_time= slot_unused
          ; vesting_period= slot_one (* avoid division by zero *)
          ; vesting_increment= amount_unused }
    | Timed
        {initial_minimum_balance; cliff_time; vesting_period; vesting_increment}
      ->
        As_record.
          { is_timed= true
          ; initial_minimum_balance
          ; cliff_time
          ; vesting_period
          ; vesting_increment }

  let to_bits t =
    let As_record.
          { is_timed
          ; initial_minimum_balance
          ; cliff_time
          ; vesting_period
          ; vesting_increment } =
      to_record t
    in
    is_timed
    :: ( Balance.to_bits initial_minimum_balance
       @ Global_slot.to_bits cliff_time
       @ Global_slot.to_bits vesting_period
       @ Amount.to_bits vesting_increment )

  [%%ifdef
  consensus_mechanism]

  type var =
    (Boolean.var, Global_slot.Checked.var, Balance.var, Amount.var) As_record.t

  let var_to_bits
      As_record.
        { is_timed
        ; initial_minimum_balance
        ; cliff_time
        ; vesting_period
        ; vesting_increment } =
    let open Bitstring_lib.Bitstring.Lsb_first in
    let initial_minimum_balance =
      to_list @@ Balance.var_to_bits initial_minimum_balance
    in
    let cliff_time = to_list @@ Global_slot.var_to_bits cliff_time in
    let vesting_period = to_list @@ Global_slot.var_to_bits vesting_period in
    let vesting_increment = to_list @@ Amount.var_to_bits vesting_increment in
    of_list
      ( is_timed
      :: ( initial_minimum_balance @ cliff_time @ vesting_period
         @ vesting_increment ) )

  let var_of_t (t : t) : var =
    let As_record.
          { is_timed
          ; initial_minimum_balance
          ; cliff_time
          ; vesting_period
          ; vesting_increment } =
      to_record t
    in
    As_record.
      { is_timed= Boolean.var_of_value is_timed
      ; initial_minimum_balance= Balance.var_of_t initial_minimum_balance
      ; cliff_time= Global_slot.Checked.constant cliff_time
      ; vesting_period= Global_slot.Checked.constant vesting_period
      ; vesting_increment= Amount.var_of_t vesting_increment }

  let untimed_var = var_of_t Untimed

  let typ : (var, t) Typ.t =
    let spec =
      let open Data_spec in
      [Boolean.typ; Balance.typ; Global_slot.typ; Global_slot.typ; Amount.typ]
    in
    (* because we represent the types t (a sum type) and var (a record) differently,
       we can't use the trick, used elsewhere, of polymorphic to_hlist and of_hlist
       functions to handle both types
    *)
    let value_of_hlist :
           ( unit
           ,    Boolean.value
             -> Balance.t
             -> Global_slot.t
             -> Global_slot.t
             -> Amount.t
             -> unit )
           H_list.t
        -> t =
      let open H_list in
      fun [ is_timed
          ; initial_minimum_balance
          ; cliff_time
          ; vesting_period
          ; vesting_increment ] ->
        if is_timed then
          Timed
            { initial_minimum_balance
            ; cliff_time
            ; vesting_period
            ; vesting_increment }
        else Untimed
    in
    let value_to_hlist (t : t) =
      let As_record.
            { is_timed
            ; initial_minimum_balance
            ; cliff_time
            ; vesting_period
            ; vesting_increment } =
        to_record t
      in
      H_list.
        [ is_timed
        ; initial_minimum_balance
        ; cliff_time
        ; vesting_period
        ; vesting_increment ]
    in
    let var_of_hlist :
           ( unit
           ,    Boolean.var
             -> Balance.var
             -> Global_slot.Checked.var
             -> Global_slot.Checked.var
             -> Amount.var
             -> unit )
           H_list.t
        -> var =
      let open H_list in
      fun [ is_timed
          ; initial_minimum_balance
          ; cliff_time
          ; vesting_period
          ; vesting_increment ] ->
        ( { is_timed
          ; initial_minimum_balance
          ; cliff_time
          ; vesting_period
          ; vesting_increment }
          : var )
    in
    let var_to_hlist
        As_record.
          { is_timed
          ; initial_minimum_balance
          ; cliff_time
          ; vesting_period
          ; vesting_increment } =
      H_list.
        [ is_timed
        ; initial_minimum_balance
        ; cliff_time
        ; vesting_period
        ; vesting_increment ]
    in
    Typ.of_hlistable spec ~var_to_hlist ~var_of_hlist ~value_to_hlist
      ~value_of_hlist

  (* we can't use the generic if_ with the above typ, because Global_slot.typ doesn't work correctly with it
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
      Global_slot.Checked.if_ b ~then_:then_.cliff_time ~else_:else_.cliff_time
    in
    let%bind vesting_period =
      Global_slot.Checked.if_ b ~then_:then_.vesting_period
        ~else_:else_.vesting_period
    in
    let%map vesting_increment =
      Amount.Checked.if_ b ~then_:then_.vesting_increment
        ~else_:else_.vesting_increment
    in
    As_record.
      { is_timed
      ; initial_minimum_balance
      ; cliff_time
      ; vesting_period
      ; vesting_increment }

  [%%endif]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Balance.Stable.V1.t
      , Nonce.Stable.V1.t
      , Receipt.Chain_hash.Stable.V1.t
      , State_hash.Stable.V1.t
      , Timing.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving sexp, eq, hash, compare, yojson]

    let to_latest = Fn.id

    let public_key (t : t) : key = t.public_key
  end
end]

type t = Stable.Latest.t [@@deriving sexp, eq, hash, compare, yojson]

[%%define_locally
Stable.Latest.(public_key)]

type value =
  ( Public_key.Compressed.t
  , Balance.t
  , Nonce.t
  , Receipt.Chain_hash.t
  , State_hash.t
  , Timing.t )
  Poly.t
[@@deriving sexp]

let key_gen = Public_key.Compressed.gen

let initialize public_key : t =
  { public_key
  ; balance= Balance.zero
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; delegate= public_key
  ; voting_for= State_hash.dummy
  ; timing= Timing.Untimed }

let to_input (t : t) =
  let open Random_oracle.Input in
  let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
  let bits conv = f (Fn.compose bitstring conv) in
  Poly.Fields.fold ~init:[]
    ~public_key:(f Public_key.Compressed.to_input)
    ~balance:(bits Balance.to_bits) ~nonce:(bits Nonce.Bits.to_bits)
    ~receipt_chain_hash:(f Receipt.Chain_hash.to_input)
    ~delegate:(f Public_key.Compressed.to_input)
    ~voting_for:(f State_hash.to_input) ~timing:(bits Timing.to_bits)
  |> List.reduce_exn ~f:append

let crypto_hash_prefix = Hash_prefix.account

let crypto_hash t =
  Random_oracle.hash ~init:crypto_hash_prefix
    (Random_oracle.pack_input (to_input t))

[%%ifdef
consensus_mechanism]

type var =
  ( Public_key.Compressed.var
  , Balance.var
  , Nonce.Checked.t
  , Receipt.Chain_hash.var
  , State_hash.var
  , Timing.var )
  Poly.t

let typ : (var, value) Typ.t =
  let spec =
    let open Data_spec in
    [ Public_key.Compressed.typ
    ; Balance.typ
    ; Nonce.typ
    ; Receipt.Chain_hash.typ
    ; Public_key.Compressed.typ
    ; State_hash.typ
    ; Timing.typ ]
  in
  let of_hlist
        : 'a 'b 'c 'd 'e 'f.    ( unit
                                ,    'a (* public key *)
                                  -> 'b
                                  -> 'c
                                  -> 'd
                                  -> 'a (* public key again *)
                                  -> 'e
                                  -> 'f
                                  -> unit )
                                H_list.t -> ('a, 'b, 'c, 'd, 'e, 'f) Poly.t =
    let open H_list in
    fun [ public_key
        ; balance
        ; nonce
        ; receipt_chain_hash
        ; delegate
        ; voting_for
        ; timing ] ->
      { public_key
      ; balance
      ; nonce
      ; receipt_chain_hash
      ; delegate
      ; voting_for
      ; timing }
  in
  let to_hlist
      Poly.
        { public_key
        ; balance
        ; nonce
        ; receipt_chain_hash
        ; delegate
        ; voting_for
        ; timing } =
    H_list.
      [ public_key
      ; balance
      ; nonce
      ; receipt_chain_hash
      ; delegate
      ; voting_for
      ; timing ]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_of_t
    ({ public_key
     ; balance
     ; nonce
     ; receipt_chain_hash
     ; delegate
     ; voting_for
     ; timing } :
      value) =
  { Poly.public_key= Public_key.Compressed.var_of_t public_key
  ; balance= Balance.var_of_t balance
  ; nonce= Nonce.Checked.constant nonce
  ; receipt_chain_hash= Receipt.Chain_hash.var_of_t receipt_chain_hash
  ; delegate= Public_key.Compressed.var_of_t delegate
  ; voting_for= State_hash.var_of_t voting_for
  ; timing= Timing.var_of_t timing }

module Checked = struct
  let to_input (t : var) =
    let ( ! ) f x = Run.run_checked (f x) in
    let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
    let open Random_oracle.Input in
    let bits conv =
      f (fun x ->
          bitstring (Bitstring_lib.Bitstring.Lsb_first.to_list (conv x)) )
    in
    List.reduce_exn ~f:append
      (Poly.Fields.fold ~init:[]
         ~public_key:(f Public_key.Compressed.Checked.to_input)
         ~balance:(bits Balance.var_to_bits)
         ~nonce:(bits !Nonce.Checked.to_bits)
         ~receipt_chain_hash:(f Receipt.Chain_hash.var_to_input)
         ~delegate:(f Public_key.Compressed.Checked.to_input)
         ~voting_for:(f State_hash.var_to_input)
         ~timing:(bits Timing.var_to_bits))

  let digest t =
    make_checked (fun () ->
        Random_oracle.Checked.(
          hash ~init:crypto_hash_prefix (pack_input (to_input t))) )

  let to_input t = make_checked (fun () -> to_input t)
end

[%%endif]

let empty =
  { Poly.public_key= Public_key.Compressed.empty
  ; balance= Balance.zero
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; delegate= Public_key.Compressed.empty
  ; voting_for= State_hash.dummy
  ; timing= Timing.Untimed }

let digest = crypto_hash

let create public_key balance =
  { Poly.public_key
  ; balance
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; delegate= public_key
  ; voting_for= State_hash.dummy
  ; timing= Timing.Untimed }

let create_timed public_key balance ~initial_minimum_balance ~cliff_time
    ~vesting_period ~vesting_increment =
  if Balance.(initial_minimum_balance > balance) then
    Or_error.errorf
      !"create_timed: initial minimum balance %{sexp: Balance.t} greater than \
        balance %{sexp: Balance.t}"
      initial_minimum_balance balance
  else if Global_slot.(equal vesting_period zero) then
    Or_error.errorf "create_timed: vesting period must be greater than zero"
  else
    Or_error.return
      { Poly.public_key
      ; balance
      ; nonce= Nonce.zero
      ; receipt_chain_hash= Receipt.Chain_hash.empty
      ; delegate= public_key
      ; voting_for= State_hash.dummy
      ; timing=
          Timing.Timed
            { initial_minimum_balance
            ; cliff_time
            ; vesting_period
            ; vesting_increment } }

(* no vesting after cliff time + 1 slot *)
let create_time_locked public_key balance ~initial_minimum_balance ~cliff_time
    =
  create_timed public_key balance ~initial_minimum_balance ~cliff_time
    ~vesting_period:Global_slot.(succ zero)
    ~vesting_increment:initial_minimum_balance

let gen =
  let open Quickcheck.Let_syntax in
  let%bind public_key = Public_key.Compressed.gen in
  let%map balance = Currency.Balance.gen in
  create public_key balance

let gen_timed =
  let open Quickcheck.Let_syntax in
  let%bind public_key = Public_key.Compressed.gen in
  let%bind balance = Currency.Balance.gen in
  (* initial min balance <= balance *)
  let%bind min_diff_int = Int.gen_incl 0 (Balance.to_int balance) in
  let min_diff = Amount.of_int min_diff_int in
  let initial_minimum_balance =
    Option.value_exn Balance.(balance - min_diff)
  in
  let%bind cliff_time = Global_slot.gen in
  (* vesting period must be at least one to avoid division by zero *)
  let%bind vesting_period =
    Int.gen_incl 1 100 >>= Fn.compose return Global_slot.of_int
  in
  let%map vesting_increment = Amount.gen in
  create_timed public_key balance ~initial_minimum_balance ~cliff_time
    ~vesting_period ~vesting_increment
