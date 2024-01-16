(* account.ml *)

[%%import "/src/config.mlh"]

open Core_kernel
open Mina_base_util
open Snark_params
open Tick
open Currency
open Mina_numbers
open Fold_lib
open Mina_base_import

module Index = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving to_yojson, sexp, hash, compare]
      end

      include T

      let to_latest = Fn.id

      include Hashable.Make_binable (T)
    end
  end]

  include Hashable.Make_binable (Stable.Latest)

  let to_int = Int.to_int

  let gen ~ledger_depth = Int.gen_incl 0 ((1 lsl ledger_depth) - 1)

  module Vector = struct
    include Int

    let empty = zero

    let get t i = (t lsr i) land 1 = 1

    let set v i b = if b then v lor (one lsl i) else v land lnot (one lsl i)
  end

  let to_bits ~ledger_depth t = List.init ledger_depth ~f:(Vector.get t)

  let of_bits = List.foldi ~init:Vector.empty ~f:(fun i t b -> Vector.set t i b)

  let to_input ~ledger_depth x =
    List.map (to_bits ~ledger_depth x) ~f:(fun b -> (field_of_bool b, 1))
    |> List.to_array |> Random_oracle.Input.Chunked.packeds

  let fold_bits ~ledger_depth t =
    { Fold.fold =
        (fun ~init ~f ->
          let rec go acc i =
            if i = ledger_depth then acc else go (f acc (Vector.get t i)) (i + 1)
          in
          go init 0 )
    }

  let fold ~ledger_depth t =
    Fold.group3 ~default:false (fold_bits ~ledger_depth t)

  [%%ifdef consensus_mechanism]

  module Unpacked = struct
    type var = Tick.Boolean.var list

    type value = Vector.t

    let to_input x =
      List.map x ~f:(fun (b : Boolean.var) -> ((b :> Field.Var.t), 1))
      |> List.to_array |> Random_oracle.Input.Chunked.packeds

    let typ ~ledger_depth : (var, value) Tick.Typ.t =
      Typ.transport
        (Typ.list ~length:ledger_depth Boolean.typ)
        ~there:(to_bits ~ledger_depth) ~back:of_bits
  end

  [%%endif]
end

module Nonce = Account_nonce

module Token_symbol = struct
  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = string [@@deriving sexp, equal, compare, hash, yojson]

        let to_latest = Fn.id

        let max_length = 6

        let check (x : t) = assert (String.length x <= max_length)

        let t_of_sexp sexp =
          let res = t_of_sexp sexp in
          check res ; res

        let of_yojson json =
          let res = of_yojson json in
          Result.bind res ~f:(fun res ->
              Result.try_with (fun () -> check res)
              |> Result.map ~f:(Fn.const res)
              |> Result.map_error
                   ~f:(Fn.const "Token_symbol.of_yojson: symbol is too long") )
      end

      include T

      include
        Binable.Of_binable_without_uuid
          (Core_kernel.String.Stable.V1)
          (struct
            type t = string

            let to_binable = Fn.id

            let of_binable x = check x ; x
          end)
    end
  end]

  [%%define_locally
  Stable.Latest.
    (sexp_of_t, t_of_sexp, equal, to_yojson, of_yojson, max_length, check)]

  let default = ""

  (* 48 = max_length * 8 *)
  module Num_bits = Pickles_types.Nat.N48

  let num_bits = Pickles_types.Nat.to_int Num_bits.n

  let to_bits (x : t) =
    Pickles_types.Vector.init Num_bits.n ~f:(fun i ->
        let byte_index = i / 8 in
        if byte_index < String.length x then
          let c = x.[byte_index] |> Char.to_int in
          c land (1 lsl (i mod 8)) <> 0
        else false )

  let of_bits x : t =
    let c, j, chars =
      Pickles_types.Vector.fold x ~init:(0, 0, []) ~f:(fun (c, j, chars) x ->
          let c = c lor ((if x then 1 else 0) lsl j) in
          if j = 7 then (0, 0, Char.of_int_exn c :: chars) else (c, j + 1, chars) )
    in
    assert (c = 0) ;
    assert (j = 0) ;
    let chars = List.drop_while ~f:(fun c -> Char.to_int c = 0) chars in
    String.of_char_list (List.rev chars)

  let to_field (x : t) : Field.t =
    Field.project (Pickles_types.Vector.to_list (to_bits x))

  let to_input (x : t) =
    Random_oracle_input.Chunked.packed (to_field x, num_bits)

  [%%ifdef consensus_mechanism]

  type var = Field.Var.t

  let range_check (t : var) =
    let%bind actual =
      make_checked (fun () ->
          let _, _, actual_packed =
            Pickles.Scalar_challenge.to_field_checked' ~num_bits m
              (Kimchi_backend_common.Scalar_challenge.create t)
          in
          actual_packed )
    in
    Field.Checked.Assert.equal t actual

  let var_of_value x =
    Pickles_types.Vector.map ~f:Boolean.var_of_value (to_bits x)

  let of_field (x : Field.t) : t =
    of_bits
      (Pickles_types.Vector.of_list_and_length_exn
         (List.take (Field.unpack x) num_bits)
         Num_bits.n )

  let typ : (var, t) Typ.t =
    let (Typ typ) = Field.typ in
    Typ.transport
      (Typ { typ with check = range_check })
      ~there:to_field ~back:of_field

  let var_to_input (x : var) = Random_oracle_input.Chunked.packed (x, num_bits)

  let if_ = Tick.Run.Field.if_

  [%%endif]
end

(* the `token_symbol` describes a token id owned by the account id
   from this account, not the token id used by this account
*)
module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ( 'pk
           , 'id
           , 'token_symbol
           , 'amount
           , 'nonce
           , 'receipt_chain_hash
           , 'delegate
           , 'state_hash
           , 'timing
           , 'permissions
           , 'zkapp_opt )
           t =
        { public_key : 'pk
        ; token_id : 'id
        ; token_symbol : 'token_symbol
        ; balance : 'amount
        ; nonce : 'nonce
        ; receipt_chain_hash : 'receipt_chain_hash
        ; delegate : 'delegate
        ; voting_for : 'state_hash
        ; timing : 'timing
        ; permissions : 'permissions
        ; zkapp : 'zkapp_opt
        }
      [@@deriving sexp, equal, compare, hash, yojson, fields, hlist, annot]

      let to_latest = Fn.id
    end
  end]
end

let token = Poly.token_id

module Key = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Public_key.Compressed.Stable.V1.t
      [@@deriving sexp, equal, hash, compare, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Identifier = Account_id

type key = Key.t [@@deriving sexp, equal, hash, compare, yojson]

module Timing = Account_timing

module Binable_arg = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( Public_key.Compressed.Stable.V1.t
        , Token_id.Stable.V2.t
        , Token_symbol.Stable.V1.t
        , Balance.Stable.V1.t
        , Nonce.Stable.V1.t
        , Receipt.Chain_hash.Stable.V1.t
        , Public_key.Compressed.Stable.V1.t option
        , State_hash.Stable.V1.t
        , Timing.Stable.V2.t
        , Permissions.Stable.V2.t
        , Zkapp_account.Stable.V2.t option )
        (* TODO: Cache the digest of this? *)
        Poly.Stable.V2.t
      [@@deriving sexp, equal, hash, compare, yojson]

      let to_latest = Fn.id

      let public_key (t : t) : key = t.public_key
    end
  end]
end

let check = Fn.id

[%%versioned_binable
module Stable = struct
  module V2 = struct
    type t = Binable_arg.Stable.V2.t
    [@@deriving sexp, equal, hash, compare, yojson]

    include
      Binable.Of_binable_without_uuid
        (Binable_arg.Stable.V2)
        (struct
          type nonrec t = t

          let to_binable = check

          let of_binable = check
        end)

    let to_latest = Fn.id

    let public_key (t : t) : key = t.public_key
  end
end]

[%%define_locally Stable.Latest.(public_key)]

let identifier ({ public_key; token_id; _ } : t) =
  Account_id.create public_key token_id

type value =
  ( Public_key.Compressed.t
  , Token_id.t
  , Token_symbol.t
  , Balance.t
  , Nonce.t
  , Receipt.Chain_hash.t
  , Public_key.Compressed.t option
  , State_hash.t
  , Timing.t
  , Permissions.t
  , Zkapp_account.t option )
  Poly.t
[@@deriving sexp]

let key_gen = Public_key.Compressed.gen

let initialize account_id : t =
  let public_key = Account_id.public_key account_id in
  let token_id = Account_id.token_id account_id in
  let delegate =
    (* Only allow delegation if this account is for the default token. *)
    if Token_id.(equal default token_id) then Some public_key else None
  in
  { public_key
  ; token_id
  ; token_symbol = ""
  ; balance = Balance.zero
  ; nonce = Nonce.zero
  ; receipt_chain_hash = Receipt.Chain_hash.empty
  ; delegate
  ; voting_for = State_hash.dummy
  ; timing = Timing.Untimed
  ; permissions = Permissions.user_default
  ; zkapp = None
  }

let hash_zkapp_account_opt = function
  | None ->
      Lazy.force Zkapp_account.default_digest
  | Some (a : Zkapp_account.t) ->
      Zkapp_account.digest a

let delegate_opt = Option.value ~default:Public_key.Compressed.empty

let to_input (t : t) =
  let open Random_oracle.Input.Chunked in
  let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
  Poly.Fields.fold ~init:[]
    ~public_key:(f Public_key.Compressed.to_input)
    ~token_id:(f Token_id.to_input) ~balance:(f Balance.to_input)
    ~token_symbol:(f Token_symbol.to_input) ~nonce:(f Nonce.to_input)
    ~receipt_chain_hash:(f Receipt.Chain_hash.to_input)
    ~delegate:(f (Fn.compose Public_key.Compressed.to_input delegate_opt))
    ~voting_for:(f State_hash.to_input) ~timing:(f Timing.to_input)
    ~zkapp:(f (Fn.compose field hash_zkapp_account_opt))
    ~permissions:(f Permissions.to_input)
  |> List.reduce_exn ~f:append

let crypto_hash_prefix = Hash_prefix.account

let crypto_hash t =
  Random_oracle.hash ~init:crypto_hash_prefix
    (Random_oracle.pack_input (to_input t))

[%%ifdef consensus_mechanism]

type var =
  ( Public_key.Compressed.var
  , Token_id.Checked.t
  , Token_symbol.var
  , Balance.var
  , Nonce.Checked.t
  , Receipt.Chain_hash.var
  , Public_key.Compressed.var
  , State_hash.var
  , Timing.var
  , Permissions.Checked.t
    (* TODO: This is a hack that lets us avoid unhashing zkApp accounts when we don't need to *)
  , Field.Var.t * Zkapp_account.t option As_prover.Ref.t )
  Poly.t

let identifier_of_var ({ public_key; token_id; _ } : var) =
  Account_id.Checked.create public_key token_id

let typ' zkapp =
  Typ.of_hlistable
    [ Public_key.Compressed.typ
    ; Token_id.typ
    ; Token_symbol.typ
    ; Balance.typ
    ; Nonce.typ
    ; Receipt.Chain_hash.typ
    ; Typ.transport Public_key.Compressed.typ ~there:delegate_opt
        ~back:(fun delegate ->
          if Public_key.Compressed.(equal empty) delegate then None
          else Some delegate )
    ; State_hash.typ
    ; Timing.typ
    ; Permissions.typ
    ; zkapp
    ]
    ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
    ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

let typ : (var, value) Typ.t =
  let zkapp :
      ( Field.Var.t * Zkapp_account.t option As_prover.Ref.t
      , Zkapp_account.t option )
      Typ.t =
    let account :
        (Zkapp_account.t option As_prover.Ref.t, Zkapp_account.t option) Typ.t =
      Typ.Internal.ref ()
    in
    Typ.(Field.typ * account)
    |> Typ.transport ~there:(fun x -> (hash_zkapp_account_opt x, x)) ~back:snd
  in
  typ' zkapp

let var_of_t
    ({ public_key
     ; token_id
     ; token_symbol
     ; balance
     ; nonce
     ; receipt_chain_hash
     ; delegate
     ; voting_for
     ; timing
     ; permissions
     ; zkapp
     } :
      value ) =
  { Poly.public_key = Public_key.Compressed.var_of_t public_key
  ; token_id = Token_id.Checked.constant token_id
  ; token_symbol = Token_symbol.var_of_value token_symbol
  ; balance = Balance.var_of_t balance
  ; nonce = Nonce.Checked.constant nonce
  ; receipt_chain_hash = Receipt.Chain_hash.var_of_t receipt_chain_hash
  ; delegate = Public_key.Compressed.var_of_t (delegate_opt delegate)
  ; voting_for = State_hash.var_of_t voting_for
  ; timing = Timing.var_of_t timing
  ; permissions = Permissions.Checked.constant permissions
  ; zkapp = Field.Var.constant (hash_zkapp_account_opt zkapp)
  }

module Checked = struct
  module Unhashed = struct
    type t =
      ( Public_key.Compressed.var
      , Token_id.Checked.t
      , Token_symbol.var
      , Balance.var
      , Nonce.Checked.t
      , Receipt.Chain_hash.var
      , Public_key.Compressed.var
      , State_hash.var
      , Timing.var
      , Permissions.Checked.t
      , Zkapp_account.Checked.t )
      Poly.t

    let typ : (t, Stable.Latest.t) Typ.t =
      typ'
        (Typ.transport Zkapp_account.typ
           ~there:(fun t -> Option.value t ~default:Zkapp_account.default)
           ~back:(fun t -> Some t) )
  end

  let to_input (t : var) =
    let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
    let open Random_oracle.Input.Chunked in
    List.reduce_exn ~f:append
      (Poly.Fields.fold ~init:[]
         ~zkapp:(f (fun (x, _) -> field x))
         ~permissions:(f Permissions.Checked.to_input)
         ~public_key:(f Public_key.Compressed.Checked.to_input)
         ~token_id:(f Token_id.Checked.to_input)
         ~token_symbol:(f Token_symbol.var_to_input)
         ~balance:(f Balance.var_to_input) ~nonce:(f Nonce.Checked.to_input)
         ~receipt_chain_hash:(f Receipt.Chain_hash.var_to_input)
         ~delegate:(f Public_key.Compressed.Checked.to_input)
         ~voting_for:(f State_hash.var_to_input)
         ~timing:(f Timing.var_to_input) )

  let digest t =
    make_checked (fun () ->
        Random_oracle.Checked.(
          hash ~init:crypto_hash_prefix (pack_input (to_input t))) )

  let balance_upper_bound = Bignum_bigint.(one lsl Balance.length_in_bits)

  let amount_upper_bound = Bignum_bigint.(one lsl Amount.length_in_bits)

  let min_balance_at_slot ~global_slot ~cliff_time ~cliff_amount
      ~(vesting_period : Mina_numbers.Global_slot_span.Checked.var)
      ~vesting_increment ~initial_minimum_balance =
    let%bind before_cliff =
      Global_slot_since_genesis.Checked.(global_slot < cliff_time)
    in
    let%bind else_branch =
      make_checked (fun () ->
          let _, (slot_diff : Mina_numbers.Global_slot_span.Checked.var) =
            Tick.Run.run_checked
              (Global_slot_since_genesis.Checked.diff_or_zero global_slot
                 cliff_time )
          in
          let cliff_decrement = cliff_amount in
          let min_balance_less_cliff_decrement =
            Tick.Run.run_checked
              (Balance.Checked.sub_amount_or_zero initial_minimum_balance
                 cliff_decrement )
          in
          let (num_periods : Mina_numbers.Global_slot_span.Checked.var), _ =
            Tick.Run.run_checked
              (Global_slot_span.Checked.div_mod slot_diff vesting_period)
          in
          let vesting_decrement =
            Tick.Run.Field.mul
              (Global_slot_span.Checked.to_field num_periods)
              (Amount.pack_var vesting_increment)
          in
          let min_balance_less_cliff_and_vesting_decrements =
            Tick.Run.run_checked
              (Balance.Checked.sub_amount_or_zero
                 min_balance_less_cliff_decrement
                 Amount.(Checked.Unsafe.of_field vesting_decrement) )
          in
          min_balance_less_cliff_and_vesting_decrements )
    in
    Balance.Checked.if_ before_cliff ~then_:initial_minimum_balance
      ~else_:else_branch

  let has_locked_tokens ~global_slot (t : var) =
    let open Timing.As_record in
    let { is_timed = _
        ; initial_minimum_balance
        ; cliff_time
        ; cliff_amount
        ; vesting_period
        ; vesting_increment
        } =
      t.timing
    in
    let%bind cur_min_balance =
      min_balance_at_slot ~global_slot ~initial_minimum_balance ~cliff_time
        ~cliff_amount ~vesting_period ~vesting_increment
    in
    let%map zero_min_balance =
      Balance.equal_var Balance.(var_of_t zero) cur_min_balance
    in
    (*Note: Untimed accounts will always have zero min balance*)
    Boolean.not zero_min_balance

  let has_permission ?signature_verifies ~to_ (account : var) =
    let signature_verifies =
      match signature_verifies with
      | Some signature_verifies ->
          signature_verifies
      | None -> (
          match to_ with
          | `Send ->
              Boolean.true_
          | `Receive ->
              Boolean.false_
          | `Set_delegate ->
              Boolean.true_
          | `Increment_nonce ->
              Boolean.true_
          | `Access ->
              failwith
                "Account.Checked.has_permission: signature_verifies argument \
                 must be given for access permission" )
    in
    match to_ with
    | `Send ->
        Permissions.Auth_required.Checked.eval_no_proof account.permissions.send
          ~signature_verifies
    | `Receive ->
        Permissions.Auth_required.Checked.eval_no_proof
          account.permissions.receive ~signature_verifies
    | `Set_delegate ->
        Permissions.Auth_required.Checked.eval_no_proof
          account.permissions.set_delegate ~signature_verifies
    | `Increment_nonce ->
        Permissions.Auth_required.Checked.eval_no_proof
          account.permissions.increment_nonce ~signature_verifies
    | `Access ->
        Permissions.Auth_required.Checked.eval_no_proof
          account.permissions.access ~signature_verifies
end

[%%endif]

let digest = crypto_hash

let empty =
  { Poly.public_key = Public_key.Compressed.empty
  ; token_id = Token_id.default
  ; token_symbol = Token_symbol.default
  ; balance = Balance.zero
  ; nonce = Nonce.zero
  ; receipt_chain_hash = Receipt.Chain_hash.empty
  ; delegate = None
  ; voting_for = State_hash.dummy
  ; timing = Timing.Untimed
  ; permissions =
      Permissions.user_default
      (* TODO: This should maybe be Permissions.empty *)
  ; zkapp = None
  }

let empty_digest = digest empty

let create account_id balance =
  let public_key = Account_id.public_key account_id in
  let token_id = Account_id.token_id account_id in
  let delegate =
    (* Only allow delegation if this account is for the default token. *)
    if Token_id.(equal default) token_id then Some public_key else None
  in
  { Poly.public_key
  ; token_id
  ; token_symbol = Token_symbol.default
  ; balance
  ; nonce = Nonce.zero
  ; receipt_chain_hash = Receipt.Chain_hash.empty
  ; delegate
  ; voting_for = State_hash.dummy
  ; timing = Timing.Untimed
  ; permissions = Permissions.user_default
  ; zkapp = None
  }

let create_timed account_id balance ~initial_minimum_balance ~cliff_time
    ~cliff_amount ~vesting_period ~vesting_increment =
  if Global_slot_span.(equal vesting_period zero) then
    Or_error.errorf
      !"Error creating timed account for account id %{sexp: Account_id.t}: \
        vesting period must be greater than zero"
      account_id
  else
    let public_key = Account_id.public_key account_id in
    let token_id = Account_id.token_id account_id in
    let delegate =
      (* Only allow delegation if this account is for the default token. *)
      if Token_id.(equal default) token_id then Some public_key else None
    in
    Or_error.return
      { Poly.public_key
      ; token_id
      ; token_symbol = Token_symbol.default
      ; balance
      ; nonce = Nonce.zero
      ; receipt_chain_hash = Receipt.Chain_hash.empty
      ; delegate
      ; voting_for = State_hash.dummy
      ; zkapp = None
      ; permissions = Permissions.user_default
      ; timing =
          Timing.Timed
            { initial_minimum_balance
            ; cliff_time
            ; cliff_amount
            ; vesting_period
            ; vesting_increment
            }
      }

(* no vesting after cliff time + 1 slot *)
let create_time_locked public_key balance ~initial_minimum_balance ~cliff_time =
  create_timed public_key balance ~initial_minimum_balance ~cliff_time
    ~vesting_period:Global_slot_span.(succ zero)
    ~vesting_increment:initial_minimum_balance

let initial_minimum_balance Poly.{ timing; _ } =
  match timing with
  | Timing.Untimed ->
      None
  | Timed t ->
      Some t.initial_minimum_balance

let cliff_time Poly.{ timing; _ } =
  match timing with Timing.Untimed -> None | Timed t -> Some t.cliff_time

let cliff_amount Poly.{ timing; _ } =
  match timing with Timing.Untimed -> None | Timed t -> Some t.cliff_amount

let vesting_increment Poly.{ timing } =
  match timing with
  | Timing.Untimed ->
      None
  | Timed t ->
      Some t.vesting_increment

let vesting_period Poly.{ timing; _ } =
  match timing with Timing.Untimed -> None | Timed t -> Some t.vesting_period

let min_balance_at_slot ~global_slot ~cliff_time ~cliff_amount ~vesting_period
    ~vesting_increment ~initial_minimum_balance =
  let open Unsigned in
  if Global_slot_since_genesis.(global_slot < cliff_time) then
    initial_minimum_balance
    (* If vesting period is zero then everything vests immediately at the cliff *)
  else if Global_slot_span.(equal vesting_period zero) then Balance.zero
  else
    match Balance.(initial_minimum_balance - cliff_amount) with
    | None ->
        Balance.zero
    | Some min_balance_past_cliff -> (
        (* take advantage of fact that global slots are uint32's *)
        let num_periods =
          UInt32.(
            let global_slot_u32 =
              Global_slot_since_genesis.to_uint32 global_slot
            in
            let cliff_time_u32 =
              Global_slot_since_genesis.to_uint32 cliff_time
            in
            let vesting_period_u32 =
              Global_slot_span.to_uint32 vesting_period
            in
            Infix.((global_slot_u32 - cliff_time_u32) / vesting_period_u32)
            |> to_int64 |> UInt64.of_int64)
        in
        let vesting_decrement =
          let vesting_increment = Amount.to_uint64 vesting_increment in
          if
            try
              UInt64.(compare Infix.(max_int / num_periods) vesting_increment)
              < 0
            with Division_by_zero -> false
          then
            (* The vesting decrement will overflow, use [max_int] instead. *)
            UInt64.max_int |> Amount.of_uint64
          else
            UInt64.Infix.(num_periods * vesting_increment) |> Amount.of_uint64
        in
        match Balance.(min_balance_past_cliff - vesting_decrement) with
        | None ->
            Balance.zero
        | Some amt ->
            amt )

let incremental_balance_between_slots ~start_slot ~end_slot ~cliff_time
    ~cliff_amount ~vesting_period ~vesting_increment ~initial_minimum_balance :
    Unsigned.UInt64.t =
  let open Unsigned in
  if Global_slot_since_genesis.(end_slot <= start_slot) then UInt64.zero
  else
    let min_balance_at_start_slot =
      min_balance_at_slot ~global_slot:start_slot ~cliff_time ~cliff_amount
        ~vesting_period ~vesting_increment ~initial_minimum_balance
      |> Balance.to_amount |> Amount.to_uint64
    in
    let min_balance_at_end_slot =
      min_balance_at_slot ~global_slot:end_slot ~cliff_time ~cliff_amount
        ~vesting_period ~vesting_increment ~initial_minimum_balance
      |> Balance.to_amount |> Amount.to_uint64
    in
    UInt64.Infix.(min_balance_at_start_slot - min_balance_at_end_slot)

let has_locked_tokens ~global_slot (account : t) =
  match account.timing with
  | Untimed ->
      false
  | Timed
      { initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      } ->
      let curr_min_balance =
        min_balance_at_slot ~global_slot ~cliff_time ~cliff_amount
          ~vesting_period ~vesting_increment ~initial_minimum_balance
      in
      Balance.(curr_min_balance > zero)

let final_vesting_slot ~initial_minimum_balance ~cliff_time ~cliff_amount
    ~vesting_period ~vesting_increment =
  let open Unsigned in
  let to_vest =
    Balance.(initial_minimum_balance - cliff_amount)
    |> Option.value_map ~default:UInt64.zero ~f:Balance.to_uint64
  in
  let vest_incr = Amount.to_uint64 vesting_increment in
  let periods =
    let open UInt64 in
    let open Infix in
    (to_vest / vest_incr)
    + if equal (rem to_vest vest_incr) zero then zero else one
  in
  let open UInt32 in
  let open Infix in
  Global_slot_since_genesis.of_uint32
  @@ Global_slot_since_genesis.to_uint32 cliff_time
     + (UInt64.to_uint32 periods * Global_slot_span.to_uint32 vesting_period)

let timing_final_vesting_slot = function
  | Timing.Untimed ->
      Global_slot_since_genesis.zero
  | Timed
      { initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      } ->
      final_vesting_slot ~initial_minimum_balance ~cliff_time ~cliff_amount
        ~vesting_period ~vesting_increment

let has_permission ~control ~to_ (account : t) =
  match to_ with
  | `Access ->
      Permissions.Auth_required.check account.permissions.access control
  | `Send ->
      Permissions.Auth_required.check account.permissions.send control
  | `Receive ->
      Permissions.Auth_required.check account.permissions.receive control
  | `Set_delegate ->
      Permissions.Auth_required.check account.permissions.set_delegate control
  | `Increment_nonce ->
      Permissions.Auth_required.check account.permissions.increment_nonce
        control

(** [true] iff account has permissions set that enable them to transfer Mina (assuming the command is signed) *)
let has_permission_to_send account =
  has_permission ~control:Control.Tag.Signature ~to_:`Access account
  && has_permission ~control:Control.Tag.Signature ~to_:`Send account

(** [true] iff account has permissions set that enable them to receive Mina *)
let has_permission_to_receive account =
  has_permission ~control:Control.Tag.None_given ~to_:`Access account
  && has_permission ~control:Control.Tag.None_given ~to_:`Receive account

(** [true] iff account has permissions set that enable them to set their delegate (assuming the command is signed) *)
let has_permission_to_set_delegate account =
  has_permission ~control:Control.Tag.Signature ~to_:`Access account
  && has_permission ~control:Control.Tag.Signature ~to_:`Set_delegate account

(** [true] iff account has permissions set that enable them to increment their nonce (assuming the command is signed) *)
let has_permission_to_increment_nonce account =
  has_permission ~control:Control.Tag.Signature ~to_:`Access account
  && has_permission ~control:Control.Tag.Signature ~to_:`Increment_nonce account

let liquid_balance_at_slot ~global_slot (account : t) =
  match account.timing with
  | Untimed ->
      account.balance
  | Timed
      { initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      } ->
      Balance.sub_amount account.balance
        (Balance.to_amount
           (min_balance_at_slot ~global_slot ~cliff_time ~cliff_amount
              ~vesting_period ~vesting_increment ~initial_minimum_balance ) )
      |> Option.value_exn

let gen : t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let%bind public_key = Public_key.Compressed.gen in
  let%bind token_id = Token_id.gen in
  let%map balance = Currency.Balance.gen in
  create (Account_id.create public_key token_id) balance

let gen_with_constrained_balance ~low ~high : t Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let%bind public_key = Public_key.Compressed.gen in
  let%bind token_id = Token_id.gen in
  let%map balance = Currency.Balance.gen_incl low high in
  create (Account_id.create public_key token_id) balance

let gen_any_vesting_range =
  let open Quickcheck.Generator.Let_syntax in
  let open Global_slot_since_genesis in
  (* vesting period must be at least one to avoid division by zero *)
  let%bind vesting_period = Int.gen_incl 1 1000 >>| Global_slot_span.of_int in
  let%bind vesting_end = gen_incl (of_int 1) max_value in
  let%map cliff_time = gen_incl (of_int 1) vesting_end in
  (cliff_time, vesting_end, vesting_period)

let gen_with_vesting_period vesting_period =
  let open Quickcheck.Generator.Let_syntax in
  let open Global_slot_since_genesis in
  let min_vesting_end =
    Global_slot_span.(succ vesting_period |> to_uint32)
    |> Global_slot_since_genesis.of_uint32
  in
  let%bind vesting_end = gen_incl min_vesting_end max_value in
  let max_cliff_time = Option.value_exn @@ sub vesting_end vesting_period in
  let%map cliff_time = gen_incl (of_int 1) max_cliff_time in
  (cliff_time, vesting_end, vesting_period)

let gen_vesting_details ~(cliff_time : Global_slot_since_genesis.t)
    ~(vesting_end : Global_slot_since_genesis.t)
    ~(vesting_period : Global_slot_span.t) (initial_minimum_balance : Balance.t)
    : Timing.as_record Quickcheck.Generator.t =
  let open Unsigned in
  let open Quickcheck in
  let open Generator.Let_syntax in
  let vesting_slots =
    let open Global_slot_since_genesis in
    let open UInt32.Infix in
    to_uint32 vesting_end - to_uint32 cliff_time
  in
  (* We need to arrange vesting schedule so that all funds are vested before the
     maximum global slot, which is 2 ^ 32. *)
  let vesting_periods_count =
    Unsigned.UInt32.div vesting_slots
      (Global_slot_span.to_uint32 vesting_period)
    |> UInt64.of_uint32
  in
  let max_cliff_amt =
    Balance.(initial_minimum_balance - Amount.of_uint64 vesting_periods_count)
    |> Option.value_map ~f:Balance.to_amount ~default:Amount.zero
  in
  let%map cliff_amount =
    if UInt64.(compare vesting_periods_count zero) > 0 then
      Amount.(gen_incl zero max_cliff_amt)
    else return @@ Balance.to_amount initial_minimum_balance
  in
  let to_vest =
    Balance.(initial_minimum_balance - cliff_amount)
    |> Option.value_map ~default:Unsigned.UInt64.zero ~f:Balance.to_uint64
  in
  let vesting_increment =
    if Unsigned.UInt64.(equal vesting_periods_count zero) then Amount.one
      (* This value does not matter anyway. *)
    else
      let vi = UInt64.Infix.(to_vest / vesting_periods_count) in
      let rnd = UInt64.Infix.(to_vest mod vesting_periods_count) in
      (if UInt64.(compare rnd zero) > 0 then UInt64.succ vi else vi)
      |> Amount.of_uint64
  in
  { Timing.As_record.is_timed = true
  ; initial_minimum_balance
  ; cliff_time
  ; cliff_amount
  ; vesting_period
  ; vesting_increment
  }

let gen_timing (account_balance : Balance.t) =
  let open Quickcheck.Generator.Let_syntax in
  let%bind initial_minimum_balance = Balance.(gen_incl one account_balance)
  and cliff_time, vesting_end, vesting_period = gen_any_vesting_range in
  gen_vesting_details ~vesting_period ~cliff_time ~vesting_end
    initial_minimum_balance

let gen_timing_at_least_one_vesting_period (account_balance : Balance.t) =
  let open Quickcheck.Generator.Let_syntax in
  let%bind initial_minimum_balance = Balance.(gen_incl one account_balance)
  (* vesting period must be at least one to avoid division by zero *)
  and cliff_time, vesting_end, vesting_period =
    gen_with_vesting_period @@ Global_slot_span.of_int 2
  in
  gen_vesting_details ~vesting_period ~cliff_time ~vesting_end
    initial_minimum_balance

let gen_timed : t Quickcheck.Generator.t =
  let open Quickcheck in
  let open Generator.Let_syntax in
  let%bind account =
    gen_with_constrained_balance ~low:Balance.one ~high:Balance.max_int
  in
  let%map timing = gen_timing account.balance in
  { account with timing = Timing.of_record timing }

let deriver obj =
  let open Fields_derivers_zkapps in
  let ( !. ) = ( !. ) ~t_fields_annots:Poly.t_fields_annots in
  let receipt_chain_hash =
    needs_custom_js ~js_type:field ~name:"ReceiptChainHash" field
  in
  finish "Account" ~t_toplevel_annots:Poly.t_toplevel_annots
  @@ Poly.Fields.make_creator ~public_key:!.public_key
       ~token_id:!.Token_id.deriver ~token_symbol:!.string ~balance:!.balance
       ~nonce:!.uint32 ~receipt_chain_hash:!.receipt_chain_hash
       ~delegate:!.(option ~js_type:Or_undefined (public_key @@ o ()))
       ~voting_for:!.field ~timing:!.Timing.deriver
       ~permissions:!.Permissions.deriver
       ~zkapp:!.(option ~js_type:Or_undefined (Zkapp_account.deriver @@ o ()))
       obj
