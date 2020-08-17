[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
open Signature_lib
module Coda_numbers = Coda_numbers

[%%else]

open Signature_lib_nonconsensus
module Coda_numbers = Coda_numbers_nonconsensus.Coda_numbers
module Currency = Currency_nonconsensus.Currency
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module A = Account
open Coda_numbers
open Currency
open Snapp_basic
open Pickles_types
module Impl = Pickles.Impls.Step

module Closed_interval = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = {lower: 'a; upper: 'a}
      [@@deriving sexp, eq, compare, hash, yojson, hlist]
    end
  end]

  let to_input {lower; upper} ~f =
    Random_oracle_input.append (f lower) (f upper)

  let typ x =
    Typ.of_hlistable [x; x] ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

let assert_ b e = if b then Ok () else Or_error.error_string e

(* Proofs are produced against a predicate on the protocol state. For the
   transaction to go through, the predicate must be satisfied of the protocol
   state at the time of transaction application. *)
module Numeric = struct
  module Tc = struct
    type ('var, 'a) t =
      { zero: 'a
      ; max_value: 'a
      ; compare: 'a -> 'a -> int
      ; equal: 'a -> 'a -> bool
      ; typ: ('var, 'a) Typ.t
      ; to_input: 'a -> (F.t, bool) Random_oracle_input.t
      ; to_input_checked:
          'var -> (Field.Var.t, Boolean.var) Random_oracle_input.t }

    let length =
      Length.
        { zero
        ; max_value
        ; compare
        ; equal
        ; typ
        ; to_input
        ; to_input_checked= Fn.compose Impl.run_checked Checked.to_input }

    let amount =
      Currency.Amount.
        { zero
        ; max_value= max_int
        ; compare
        ; equal
        ; typ
        ; to_input
        ; to_input_checked= var_to_input }

    let balance =
      Currency.Balance.
        { zero
        ; max_value= max_int
        ; compare
        ; equal
        ; typ
        ; to_input
        ; to_input_checked= var_to_input }

    let nonce =
      Account_nonce.
        { zero
        ; max_value
        ; compare
        ; equal
        ; typ
        ; to_input
        ; to_input_checked= Fn.compose Impl.run_checked Checked.to_input }

    let global_slot =
      Global_slot.
        { zero
        ; max_value
        ; compare
        ; equal
        ; typ
        ; to_input
        ; to_input_checked= Fn.compose Impl.run_checked Checked.to_input }

    let token_id =
      Token_id.
        { zero= of_uint64 Unsigned.UInt64.zero
        ; max_value= of_uint64 Unsigned.UInt64.max_int
        ; equal
        ; compare
        ; typ
        ; to_input
        ; to_input_checked= Fn.compose Impl.run_checked Checked.to_input }

    let time =
      Block_time.
        { equal
        ; compare
        ; zero
        ; max_value
        ; typ= Unpacked.typ
        ; to_input= Fn.compose Random_oracle_input.bitstring Bits.to_bits
        ; to_input_checked=
            (fun x ->
              Random_oracle_input.bitstring
                (Unpacked.var_to_bits x :> Boolean.var list) ) }
  end

  open Tc

  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = 'a Closed_interval.Stable.V1.t Or_ignore.Stable.V1.t
      [@@deriving sexp, eq, yojson, hash, compare]
    end
  end]

  let to_input {zero; max_value; to_input; _} (t : 'a t) =
    Closed_interval.to_input ~f:to_input
      (match t with Check x -> x | Ignore -> {lower= zero; upper= max_value})

  module Checked = struct
    type 'a t = 'a Closed_interval.t Or_ignore.Checked.t
  end

  let typ {equal= eq; zero; max_value; typ; _} =
    Or_ignore.typ_implicit (Closed_interval.typ typ)
      ~equal:(Closed_interval.equal eq)
      ~ignore:{Closed_interval.lower= zero; upper= max_value}

  let check ~label {compare; _} (t : 'a t) (x : 'a) =
    match t with
    | Ignore ->
        Ok ()
    | Check {lower; upper} ->
        if compare lower x <= 0 && compare x upper <= 0 then Ok ()
        else Or_error.errorf "Bounds check failed: %s" label
end

module Eq_data = struct
  include Or_ignore

  module Tc = struct
    type ('var, 'a) t =
      { equal: 'a -> 'a -> bool
      ; default: 'a
      ; typ: ('var, 'a) Typ.t
      ; to_input: 'a -> (F.t, bool) Random_oracle_input.t
      ; to_input_checked:
          'var -> (Field.Var.t, Boolean.var) Random_oracle_input.t }

    let field =
      let open Random_oracle_input in
      Field.
        {typ; equal; default= zero; to_input= field; to_input_checked= field}

    let receipt_chain_hash =
      Receipt.Chain_hash.
        {field with to_input_checked= var_to_input; typ; equal}

    let ledger_hash =
      Ledger_hash.{field with to_input_checked= var_to_input; typ; equal}

    let frozen_ledger_hash =
      Frozen_ledger_hash.
        {field with to_input_checked= var_to_input; typ; equal}

    let state_hash =
      State_hash.{field with to_input_checked= var_to_input; typ; equal}

    let epoch_seed =
      Epoch_seed.{field with to_input_checked= var_to_input; typ; equal}

    let public_key () =
      Public_key.Compressed.
        { default= Lazy.force invalid_public_key
        ; to_input= Public_key.Compressed.to_input
        ; to_input_checked= Public_key.Compressed.Checked.to_input
        ; typ
        ; equal }
  end

  let to_input {Tc.default; to_input; _} (t : _ t) =
    to_input (match t with Ignore -> default | Check x -> x)

  let check ~label {Tc.equal; _} (t : 'a t) (x : 'a) =
    match t with
    | Ignore ->
        Ok ()
    | Check y ->
        if equal x y then Ok ()
        else Or_error.errorf "Equality check failed: %s" label

  let typ_implicit {Tc.equal; default= ignore; typ; _} =
    typ_implicit ~equal ~ignore typ

  let typ_explicit {Tc.default= ignore; typ; _} = typ_explicit ~ignore typ
end

module Hash = struct
  include Eq_data

  let typ = typ_implicit
end

module Leaf_typs = struct
  let public_key () =
    Public_key.Compressed.(
      Or_ignore.typ_implicit ~ignore:(Lazy.force invalid_public_key) ~equal typ)

  open Eq_data.Tc

  let field = Eq_data.typ_explicit field

  let receipt_chain_hash = Hash.typ receipt_chain_hash

  let ledger_hash = Hash.typ ledger_hash

  let frozen_ledger_hash = Hash.typ frozen_ledger_hash

  let state_hash = Hash.typ state_hash

  open Numeric.Tc

  let length = Numeric.typ length

  let time = Numeric.typ time

  let amount = Numeric.typ amount

  let balance = Numeric.typ balance

  let nonce = Numeric.typ nonce

  let global_slot = Numeric.typ global_slot

  let token_id = Numeric.typ token_id
end

module Account = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('balance, 'nonce, 'receipt_chain_hash, 'pk, 'field) t =
          { balance: 'balance
          ; nonce: 'nonce
          ; receipt_chain_hash: 'receipt_chain_hash
          ; public_key: 'pk
          ; delegate: 'pk
          ; state: 'field Snapp_state.Stable.V1.t }
        [@@deriving hlist, sexp, eq, yojson, hash, compare]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Balance.Stable.V1.t Numeric.Stable.V1.t
        , Account_nonce.Stable.V1.t Numeric.Stable.V1.t
        , Receipt.Chain_hash.Stable.V1.t Hash.Stable.V1.t
        , Public_key.Compressed.Stable.V1.t Eq_data.Stable.V1.t
        , F.Stable.V1.t Eq_data.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let accept : t =
    { balance= Ignore
    ; nonce= Ignore
    ; receipt_chain_hash= Ignore
    ; public_key= Ignore
    ; delegate= Ignore
    ; state=
        Vector.init Snapp_state.Max_state_size.n ~f:(fun _ -> Or_ignore.Ignore)
    }

  let to_input
      ({balance; nonce; receipt_chain_hash; public_key; delegate; state} : t) =
    let open Random_oracle_input in
    List.reduce_exn ~f:append
      [ Numeric.(to_input Tc.balance balance)
      ; Numeric.(to_input Tc.nonce nonce)
      ; Hash.(to_input Tc.receipt_chain_hash receipt_chain_hash)
      ; Eq_data.(to_input (Tc.public_key ()) public_key)
      ; Eq_data.(to_input (Tc.public_key ()) delegate)
      ; Vector.reduce_exn ~f:append
          (Vector.map state ~f:Eq_data.(to_input Tc.field)) ]

  let digest t =
    Random_oracle.(
      hash ~init:Hash_prefix.snapp_predicate_account (pack_input (to_input t)))

  module Checked = struct
    type t =
      ( Balance.var Numeric.Checked.t
      , Account_nonce.Checked.t Numeric.Checked.t
      , Receipt.Chain_hash.var Hash.Checked.t
      , Public_key.Compressed.var Eq_data.Checked.t
      , Field.Var.t Eq_data.Checked.t )
      Poly.Stable.Latest.t
  end

  let typ () : (Checked.t, Stable.Latest.t) Typ.t =
    let open Poly.Stable.Latest in
    let open Leaf_typs in
    Typ.of_hlistable
      [ balance
      ; nonce
      ; receipt_chain_hash
      ; public_key ()
      ; public_key ()
      ; Snapp_state.typ
          (Or_ignore.typ_implicit Field.typ ~equal:Field.equal
             ~ignore:Field.zero) ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let check
      ({balance; nonce; receipt_chain_hash; public_key; delegate; state} : t)
      (a : Account.t) =
    let open Or_error.Let_syntax in
    let%bind () =
      Numeric.(check ~label:"balance" Tc.balance balance a.balance)
    in
    let%bind () = Numeric.(check ~label:"nonce" Tc.nonce nonce a.nonce) in
    let%bind () =
      Eq_data.(
        check ~label:"receipt_chain_hash" Tc.receipt_chain_hash
          receipt_chain_hash a.receipt_chain_hash)
    in
    let%bind () =
      Eq_data.(check ~label:"delegate" (Tc.public_key ()) delegate a.delegate)
    in
    let%bind () =
      Eq_data.(
        check ~label:"public_key" (Tc.public_key ()) public_key a.public_key)
    in
    let%bind () =
      match a.snapp with
      | None ->
          return ()
      | Some snapp ->
          List.fold_result ~init:0
            Vector.(to_list (zip state snapp.app_state))
            ~f:(fun i (c, v) ->
              let%map () =
                Eq_data.(check Tc.field ~label:(sprintf "state[%d]" i) c v)
              in
              i + 1 )
          >>| ignore
    in
    return ()
end

module Protocol_state = struct
  (* On each numeric field, you may assert a range
      On each hash field, you may assert an equality
    *)

  module Epoch_data = struct
    module Poly = Epoch_data.Poly

    [%%versioned
    module Stable = struct
      module V1 = struct
        (* TODO: Not sure if this should be frozen ledger hash or not *)
        type t =
          ( ( Frozen_ledger_hash.Stable.V1.t Hash.Stable.V1.t
            , Currency.Amount.Stable.V1.t Numeric.Stable.V1.t )
            Epoch_ledger.Poly.Stable.V1.t
          , Epoch_seed.Stable.V1.t Hash.Stable.V1.t
          , State_hash.Stable.V1.t Hash.Stable.V1.t
          , State_hash.Stable.V1.t Hash.Stable.V1.t
          , Length.Stable.V1.t Numeric.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving sexp, eq, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    let to_input
        ({ ledger= {hash; total_currency}
         ; seed
         ; start_checkpoint
         ; lock_checkpoint
         ; epoch_length } :
          t) =
      let open Random_oracle.Input in
      List.reduce_exn ~f:append
        [ Hash.(to_input Tc.frozen_ledger_hash hash)
        ; Numeric.(to_input Tc.amount total_currency)
        ; Hash.(to_input Tc.epoch_seed seed)
        ; Hash.(to_input Tc.state_hash start_checkpoint)
        ; Hash.(to_input Tc.state_hash lock_checkpoint)
        ; Numeric.(to_input Tc.length epoch_length) ]

    module Checked = struct
      type t =
        ( ( Frozen_ledger_hash.var Hash.Checked.t
          , Currency.Amount.var Numeric.Checked.t )
          Epoch_ledger.Poly.t
        , Epoch_seed.var Hash.Checked.t
        , State_hash.var Hash.Checked.t
        , State_hash.var Hash.Checked.t
        , Length.Checked.t Numeric.Checked.t )
        Poly.t
    end
  end

  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ( 'staged_ledger_hash_ledger_hash
             , 'snarked_ledger_hash
             , 'token_id
             , 'time
             , 'length
             , 'vrf_output
             , 'global_slot
             , 'amount
             , 'epoch_data )
             t =
          { staged_ledger_hash_ledger_hash: 'staged_ledger_hash_ledger_hash
          ; snarked_ledger_hash: 'snarked_ledger_hash
          ; snarked_next_available_token: 'token_id
          ; timestamp: 'time
          ; blockchain_length: 'length
                (* TODO: This previously had epoch_count but I removed it as I believe it is redundant
   with curr_global_slot.

   epoch_count in [a, b]

   should be equivalent to

   curr_global_slot in [slots_per_epoch * a, slots_per_epoch * b]
*)
          ; min_window_density: 'length
          ; last_vrf_output: 'vrf_output
          ; total_currency: 'amount
          ; curr_global_slot: 'global_slot
          ; staking_epoch_data: 'epoch_data
          ; next_epoch_data: 'epoch_data }
        [@@deriving hlist, sexp, eq, yojson, hash, compare, fields]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Ledger_hash.Stable.V1.t Hash.Stable.V1.t
        , Frozen_ledger_hash.Stable.V1.t Hash.Stable.V1.t
        , Token_id.Stable.V1.t Numeric.Stable.V1.t
        , Block_time.Stable.V1.t Numeric.Stable.V1.t
        , Length.Stable.V1.t Numeric.Stable.V1.t
        , unit (* TODO *)
        , Global_slot.Stable.V1.t Numeric.Stable.V1.t
        , Currency.Amount.Stable.V1.t Numeric.Stable.V1.t
        , Epoch_data.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let to_input
      ({ staged_ledger_hash_ledger_hash
       ; snarked_ledger_hash
       ; snarked_next_available_token
       ; timestamp
       ; blockchain_length
       ; min_window_density
       ; last_vrf_output
       ; total_currency
       ; curr_global_slot
       ; staking_epoch_data
       ; next_epoch_data } :
        t) =
    let open Random_oracle.Input in
    let () = last_vrf_output in
    let length = Numeric.(to_input Tc.length) in
    List.reduce_exn ~f:append
      [ Hash.(to_input Tc.field staged_ledger_hash_ledger_hash)
      ; Hash.(to_input Tc.field snarked_ledger_hash)
      ; Numeric.(to_input Tc.token_id snarked_next_available_token)
      ; Numeric.(to_input Tc.time timestamp)
      ; length blockchain_length
      ; length min_window_density
      ; Numeric.(to_input Tc.amount total_currency)
      ; Numeric.(to_input Tc.global_slot curr_global_slot)
      ; Epoch_data.to_input staking_epoch_data
      ; Epoch_data.to_input next_epoch_data ]

  let digest t =
    Random_oracle.(
      hash ~init:Hash_prefix.snapp_predicate_protocol_state
        (pack_input (to_input t)))

  module Checked = struct
    type t =
      ( Ledger_hash.var Hash.Checked.t
      , Frozen_ledger_hash.var Hash.Checked.t
      , Token_id.var Numeric.Checked.t
      , Block_time.Unpacked.var Numeric.Checked.t
      , Length.Checked.t Numeric.Checked.t
      , unit (* TODO *)
      , Global_slot.Checked.t Numeric.Checked.t
      , Currency.Amount.var Numeric.Checked.t
      , Epoch_data.Checked.t )
      Poly.Stable.Latest.t
  end

  let typ : (Checked.t, Stable.Latest.t) Typ.t =
    let open Poly.Stable.Latest in
    let ledger_hash = Hash.(typ Tc.ledger_hash) in
    let frozen_ledger_hash = Hash.(typ Tc.frozen_ledger_hash) in
    let state_hash = Hash.(typ Tc.state_hash) in
    let epoch_seed = Hash.(typ Tc.epoch_seed) in
    let length = Numeric.(typ Tc.length) in
    let time = Numeric.(typ Tc.time) in
    let amount = Numeric.(typ Tc.amount) in
    let global_slot = Numeric.(typ Tc.global_slot) in
    let token_id = Numeric.(typ Tc.token_id) in
    let epoch_data =
      let epoch_ledger =
        let open Epoch_ledger.Poly in
        Typ.of_hlistable
          [frozen_ledger_hash; amount]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
          ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
      in
      let open Epoch_data.Poly in
      Typ.of_hlistable
        [epoch_ledger; epoch_seed; state_hash; state_hash; length]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
    in
    Typ.of_hlistable
      [ ledger_hash
      ; frozen_ledger_hash
      ; token_id
      ; time
      ; length
      ; length
      ; Typ.unit
      ; amount
      ; global_slot
      ; epoch_data
      ; epoch_data ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  module View = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Ledger_hash.Stable.V1.t
          , Frozen_ledger_hash.Stable.V1.t
          , Token_id.Stable.V1.t
          , Block_time.Stable.V1.t
          , Length.Stable.V1.t
          , unit (* TODO *)
          , Global_slot.Stable.V1.t
          , Currency.Amount.Stable.V1.t
          , ( ( Frozen_ledger_hash.Stable.V1.t
              , Currency.Amount.Stable.V1.t )
              Epoch_ledger.Poly.Stable.V1.t
            , Epoch_seed.Stable.V1.t
            , State_hash.Stable.V1.t
            , State_hash.Stable.V1.t
            , Length.Stable.V1.t )
            Epoch_data.Poly.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving sexp, eq, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]
  end

  let accept : t =
    let epoch_data : Epoch_data.t =
      { ledger= {hash= Ignore; total_currency= Ignore}
      ; seed= Ignore
      ; start_checkpoint= Ignore
      ; lock_checkpoint= Ignore
      ; epoch_length= Ignore }
    in
    { staged_ledger_hash_ledger_hash= Ignore
    ; snarked_ledger_hash= Ignore
    ; snarked_next_available_token= Ignore
    ; timestamp= Ignore
    ; blockchain_length= Ignore
    ; min_window_density= Ignore
    ; last_vrf_output= ()
    ; total_currency= Ignore
    ; curr_global_slot= Ignore
    ; staking_epoch_data= epoch_data
    ; next_epoch_data= epoch_data }

  let check
      (* Bind all the fields explicity so we make sure they are all used. *)
      ({ staged_ledger_hash_ledger_hash
       ; snarked_ledger_hash
       ; snarked_next_available_token
       ; timestamp
       ; blockchain_length
       ; min_window_density
       ; last_vrf_output
       ; total_currency
       ; curr_global_slot
       ; staking_epoch_data
       ; next_epoch_data } :
        t) (s : View.t) =
    let open Or_error.Let_syntax in
    let epoch_ledger ({hash; total_currency} : _ Epoch_ledger.Poly.t)
        (t : Epoch_ledger.Value.t) =
      let%bind () =
        Hash.(check ~label:"epoch_ledger_hash" Tc.frozen_ledger_hash)
          hash t.hash
      in
      let%map () =
        Numeric.(check ~label:"epoch_ledger_total_currency" Tc.amount)
          total_currency t.total_currency
      in
      ()
    in
    let epoch_data label
        ({ledger; seed; start_checkpoint; lock_checkpoint; epoch_length} :
          _ Epoch_data.Poly.t) (t : _ Epoch_data.Poly.t) =
      let l s = sprintf "%s_%s" label s in
      let%bind () = epoch_ledger ledger t.ledger in
      ignore seed ;
      let%bind () =
        Hash.(check ~label:(l "start_check_point") Tc.state_hash)
          start_checkpoint t.start_checkpoint
      in
      let%bind () =
        Hash.(check ~label:(l "lock_check_point") Tc.state_hash)
          lock_checkpoint t.lock_checkpoint
      in
      let%map () =
        Numeric.(check ~label:"epoch_length" Tc.length)
          epoch_length t.epoch_length
      in
      ()
    in
    let%bind () =
      Hash.(check ~label:"staged_ledger_hash_ledger_hash" Tc.ledger_hash)
        staged_ledger_hash_ledger_hash s.staged_ledger_hash_ledger_hash
    in
    let%bind () =
      Hash.(check ~label:"snarked_ledger_hash" Tc.ledger_hash)
        snarked_ledger_hash s.snarked_ledger_hash
    in
    let%bind () =
      Numeric.(check ~label:"snarked_next_available_token" Tc.token_id)
        snarked_next_available_token s.snarked_next_available_token
    in
    let%bind () =
      Numeric.(check ~label:"timestamp" Tc.time) timestamp s.timestamp
    in
    let%bind () =
      Numeric.(check ~label:"blockchain_length" Tc.length)
        blockchain_length s.blockchain_length
    in
    let%bind () =
      Numeric.(check ~label:"min_window_density" Tc.length)
        min_window_density s.min_window_density
    in
    ignore last_vrf_output ;
    (* TODO: Decide whether to expose this *)
    let%bind () =
      Numeric.(check ~label:"total_currency" Tc.amount)
        total_currency s.total_currency
    in
    let%bind () =
      Numeric.(check ~label:"curr_global_slot" Tc.global_slot)
        curr_global_slot s.curr_global_slot
    in
    let%bind () =
      epoch_data "staking_epoch_data" staking_epoch_data s.staking_epoch_data
    in
    let%map () =
      epoch_data "next_epoch_data" next_epoch_data s.next_epoch_data
    in
    ()
end

module Account_type = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = User | Snapp | None | Any
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let check (t : t) (a : A.t option) =
    match (a, t) with
    | _, Any ->
        Ok ()
    | None, None ->
        Ok ()
    | None, _ ->
        Or_error.error_string "expected account_type = None"
    | Some a, User ->
        assert_ (Option.is_none a.snapp) "expected account_type = User"
    | Some a, Snapp ->
        assert_ (Option.is_some a.snapp) "expected account_type = Snapp"
    | Some _, None ->
        Or_error.error_string "no second account allowed"

  let to_bits = function
    | User ->
        [true; false]
    | Snapp ->
        [false; true]
    | None ->
        [false; false]
    | Any ->
        [true; true]

  let of_bits = function
    | [user; snapp] -> (
      match (user, snapp) with
      | true, false ->
          User
      | false, true ->
          Snapp
      | false, false ->
          None
      | true, true ->
          Any )
    | _ ->
        assert false

  let to_input = Fn.compose Random_oracle_input.bitstring to_bits

  module Checked = struct
    type t = {user: Boolean.var; snapp: Boolean.var} [@@deriving hlist]

    let to_input {user; snapp} = Random_oracle_input.bitstring [user; snapp]
  end

  let typ =
    let open Checked in
    Typ.of_hlistable [Boolean.typ; Boolean.typ] ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist
      ~value_to_hlist:(function
        | User ->
            [true; false]
        | Snapp ->
            [false; true]
        | None ->
            [false; false]
        | Any ->
            [true; true] )
      ~value_of_hlist:(fun [user; snapp] ->
        match (user, snapp) with
        | true, false ->
            User
        | false, true ->
            Snapp
        | false, false ->
            None
        | true, true ->
            Any )
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('account, 'protocol_state, 'account_type, 'vk) t =
        { self_predicate: 'account
        ; other_predicate: 'account
        ; other_account_type: 'account_type
        ; other_account_vk: 'vk
        ; protocol_state_predicate: 'protocol_state }
      [@@deriving hlist, sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let typ spec =
    let open Stable.Latest in
    Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Account.Stable.V1.t
      , Protocol_state.Stable.V1.t
      , Account_type.Stable.V1.t
      , F.Stable.V1.t Hash.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving sexp, eq, yojson, hash, compare]

    let to_latest = Fn.id
  end
end]

module Digested = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( F.Stable.V1.t
        , F.Stable.V1.t
        , Account_type.Stable.V1.t
        , F.Stable.V1.t Hash.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let to_input
      ({ self_predicate
       ; other_predicate
       ; other_account_type
       ; other_account_vk
       ; protocol_state_predicate } :
        t) =
    let open Random_oracle.Input in
    List.reduce_exn ~f:append
      [ field self_predicate
      ; field other_predicate
      ; Hash.(to_input Tc.field) other_account_vk
      ; Account_type.to_input other_account_type
      ; field protocol_state_predicate ]

  module Checked = struct
    type t =
      ( Field.Var.t
      , Field.Var.t
      , Account_type.Checked.t
      , Field.Var.t Hash.Checked.t )
      Poly.Stable.Latest.t

    let to_input
        ({ self_predicate
         ; other_predicate
         ; other_account_type
         ; other_account_vk
         ; protocol_state_predicate } :
          t) =
      let open Random_oracle.Input in
      List.reduce_exn ~f:append
        [ field self_predicate
        ; field other_predicate
        ; Hash.Checked.to_input other_account_vk ~f:field
        ; Account_type.Checked.to_input other_account_type
        ; field protocol_state_predicate ]
  end
end

let digest
    ({ self_predicate
     ; other_predicate
     ; other_account_type
     ; other_account_vk
     ; protocol_state_predicate } :
      t) : Digested.t =
  { self_predicate= Account.digest self_predicate
  ; other_predicate= Account.digest other_predicate
  ; other_account_type
  ; other_account_vk
  ; protocol_state_predicate= Protocol_state.digest protocol_state_predicate }

let check
    ({ self_predicate
     ; other_predicate
     ; other_account_type
     ; other_account_vk
     ; protocol_state_predicate } :
      t) ~state_view ~self ~(other : _ option) =
  let open Or_error.Let_syntax in
  let%bind () = Protocol_state.check protocol_state_predicate state_view in
  let%bind () = Account.check self_predicate self in
  let%bind () = Account_type.check other_account_type other in
  let%bind () =
    match other with
    | None ->
        return ()
    | Some other -> (
        let%bind () = Account.check other_predicate other in
        match other.snapp with
        | None ->
            assert_
              (other_account_vk = Ignore)
              "other_account_vk must be ignore for user account"
        | Some snapp ->
            Hash.(check ~label:"other_account_vk" Tc.field)
              other_account_vk snapp.verification_key.hash )
  in
  return ()

let accept : t =
  { self_predicate= Account.accept
  ; other_predicate= Account.accept
  ; other_account_type= Any
  ; other_account_vk= Ignore
  ; protocol_state_predicate= Protocol_state.accept }

module Checked = struct
  type t =
    ( Account.Checked.t
    , Protocol_state.Checked.t
    , Account_type.Checked.t
    , Field.Var.t Or_ignore.Checked.t )
    Poly.Stable.Latest.t
end

let typ () : (Checked.t, Stable.Latest.t) Typ.t =
  Poly.typ
    [ Account.typ ()
    ; Account.typ ()
    ; Account_type.typ
    ; Hash.(typ Tc.field)
    ; Protocol_state.typ ]
