(* account.ml *)

open Coda_base
open Core


open Core_kernel
open Snarky


open Snark_params
open Tick



open Currency
open Coda_numbers
open Fold_lib
open Import

module Index = struct

  type t = int [@@deriving to_yojson, sexp]

  let to_latest = Fn.id




  let to_int = Int.to_int

  let gen ~ledger_depth = Int.gen_incl 0 ((1 lsl ledger_depth) - 1)

  module Table = Int.Table

  module Vector = struct
    include Int

    let empty = zero

    let get t i = (t lsr i) land 1 = 1

    let set v i b = if b then v lor (one lsl i) else v land lnot (one lsl i)
  end

  let to_bits ~ledger_depth t = List.init ledger_depth ~f:(Vector.get t)

  let of_bits =
    List.foldi ~init:Vector.empty ~f:(fun i t b -> Vector.set t i b)

  let fold_bits ~ledger_depth t =
    { Fold.fold=
        (fun ~init ~f ->
          let rec go acc i =
            if i = ledger_depth then acc
            else go (f acc (Vector.get t i)) (i + 1)
          in
          go init 0 ) }

  let fold ~ledger_depth t =
    Fold.group3 ~default:false (fold_bits ~ledger_depth t)
end

(*module Nonce = Account_nonce*)

module Poly = struct
  module Stable = struct
    module V1 = struct
      type ( 'domain
           , 'pkd
           , 'cert
           , 'receipt_chain_hash
           , 'state_hash)
           t =
        { domain: 'domain
        ; public_key: 'pkd
        ; signature: 'cert
        ; receipt_chain_hash: 'receipt_chain_hash
        ; voting_for: 'state_hash }
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end

  type ( 'domain
        , 'pkd
        , 'cert
        , 'receipt_chain_hash
        , 'state_hash )
       t =
    { domain: 'domain
    ; public_key: 'pkd
    ; signature: 'cert
    ; receipt_chain_hash: 'receipt_chain_hash
    ; voting_for: 'state_hash }
  [@@deriving sexp, eq, compare, hash, yojson, fields]



  let of_hlist
      ([ domain
       ; public_key
       ; signature
       ; receipt_chain_hash
       ; voting_for ] :
        (unit, _) H_list.t) =
    { domain
    ; public_key
    ; signature
    ; receipt_chain_hash
    ; voting_for }

  let to_hlist
      { domain
      ; public_key
      ; signature
      ; receipt_chain_hash
      ; voting_for } =
    H_list.
      [ domain
      ; public_key
      ; signature
      ; receipt_chain_hash
      ; voting_for ]

end

module Key = struct

      type t = string (*Certchainw.Domain.t*)
      [@@deriving sexp, eq, hash, compare, yojson]

      let to_latest = Fn.id

end

module Identifier = Domainaccount_id

type key = Key.t [@@deriving sexp, eq, hash, compare, yojson]




    type t =
      ( Domain.t
      , Public_key.Compressed.Stable.V1.t
      , Signature_lib.Schnorr.Signature.t
      , Receipt.Chain_hash.Stable.V1.t
      , State_hash.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving sexp, eq, hash, compare, yojson]

    let to_latest = Fn.id

    let domain (t : t) : key = t.domain








let identifier ({domain;  _} : t) =
  Domainaccount_id.create domain

type value =
  ( Domain.t
  , Public_key.Compressed.t
  , Signature.t
  , Receipt.Chain_hash.t
  , State_hash.t )
  Poly.t
[@@deriving sexp]

let key_gen = Public_key.Compressed.gen

let initialize account_id : t =
  let public_key = Account_id.public_key account_id in
  let token_id = Account_id.token_id account_id in
  let delegate =
    (* Only allow delegation if this account is for the default token. *)
    if Token_id.(equal default) token_id then public_key
    else Public_key.Compressed.empty
  in
  { public_key
  ; token_id
  ; token_permissions= Token_permissions.default
  ; balance= Balance.zero
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; delegate
  ; voting_for= State_hash.dummy
  ; timing= Timing.Untimed }

let to_input (t : t) =
  let open Random_oracle.Input in
  let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
  let bits conv = f (Fn.compose bitstring conv) in
  Poly.Fields.fold ~init:[]
    ~public_key:(f Public_key.Compressed.to_input)
    ~token_id:(f Token_id.to_input) ~balance:(bits Balance.to_bits)
    ~token_permissions:(f Token_permissions.to_input)
    ~nonce:(bits Nonce.Bits.to_bits)
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
  , Token_id.var
  , Token_permissions.var
  , Balance.var
  , Nonce.Checked.t
  , Receipt.Chain_hash.var
  , State_hash.var
  , Timing.var )
  Poly.t

let identifier_of_var ({public_key; token_id; _} : var) =
  Account_id.Checked.create public_key token_id

let typ : (var, value) Typ.t =
  let spec =
    Data_spec.
      [ Public_key.Compressed.typ
      ; Token_id.typ
      ; Token_permissions.typ
      ; Balance.typ
      ; Nonce.typ
      ; Receipt.Chain_hash.typ
      ; Public_key.Compressed.typ
      ; State_hash.typ
      ; Timing.typ ]
  in
  Typ.of_hlistable spec ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
    ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

let var_of_t
    ({ public_key
     ; token_id
     ; token_permissions
     ; balance
     ; nonce
     ; receipt_chain_hash
     ; delegate
     ; voting_for
     ; timing } :
      value) =
  { Poly.public_key= Public_key.Compressed.var_of_t public_key
  ; token_id= Token_id.var_of_t token_id
  ; token_permissions= Token_permissions.var_of_t token_permissions
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
    make_checked (fun () ->
        List.reduce_exn ~f:append
          (Poly.Fields.fold ~init:[]
             ~public_key:(f Public_key.Compressed.Checked.to_input)
             ~token_id:
               (* We use [run_checked] here to avoid routing the [Checked.t]
                  monad throughout this calculation.
               *)
               (f (fun x -> Run.run_checked (Token_id.Checked.to_input x)))
             ~token_permissions:(f Token_permissions.var_to_input)
             ~balance:(bits Balance.var_to_bits)
             ~nonce:(bits !Nonce.Checked.to_bits)
             ~receipt_chain_hash:(f Receipt.Chain_hash.var_to_input)
             ~delegate:(f Public_key.Compressed.Checked.to_input)
             ~voting_for:(f State_hash.var_to_input)
             ~timing:(bits Timing.var_to_bits)) )

  let digest t =
    make_checked (fun () ->
        Random_oracle.Checked.(
          hash ~init:crypto_hash_prefix
            (pack_input (Run.run_checked (to_input t)))) )
end

[%%endif]

let digest = crypto_hash

let empty =
  { Poly.public_key= Public_key.Compressed.empty
  ; token_id= Token_id.default
  ; token_permissions= Token_permissions.default
  ; balance= Balance.zero
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; delegate= Public_key.Compressed.empty
  ; voting_for= State_hash.dummy
  ; timing= Timing.Untimed }

let empty_digest = digest empty

let create account_id balance =
  let public_key = Account_id.public_key account_id in
  let token_id = Account_id.token_id account_id in
  let delegate =
    (* Only allow delegation if this account is for the default token. *)
    if Token_id.(equal default) token_id then public_key
    else Public_key.Compressed.empty
  in
  { Poly.public_key
  ; token_id
  ; token_permissions= Token_permissions.default
  ; balance
  ; nonce= Nonce.zero
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; delegate
  ; voting_for= State_hash.dummy
  ; timing= Timing.Untimed }

let create_timed account_id balance ~initial_minimum_balance ~cliff_time
    ~vesting_period ~vesting_increment =
  if Balance.(initial_minimum_balance > balance) then
    Or_error.errorf
      !"create_timed: initial minimum balance %{sexp: Balance.t} greater than \
        balance %{sexp: Balance.t}"
      initial_minimum_balance balance
  else if Global_slot.(equal vesting_period zero) then
    Or_error.errorf "create_timed: vesting period must be greater than zero"
  else
    let public_key = Account_id.public_key account_id in
    let token_id = Account_id.token_id account_id in
    let delegate =
      (* Only allow delegation if this account is for the default token. *)
      if Token_id.(equal default) token_id then public_key
      else Public_key.Compressed.empty
    in
    Or_error.return
      { Poly.public_key
      ; token_id
      ; token_permissions= Token_permissions.default
      ; balance
      ; nonce= Nonce.zero
      ; receipt_chain_hash= Receipt.Chain_hash.empty
      ; delegate
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
  let%bind token_id = Token_id.gen in
  let%map balance = Currency.Balance.gen in
  create (Account_id.create public_key token_id) balance

let gen_timed =
  let open Quickcheck.Let_syntax in
  let%bind public_key = Public_key.Compressed.gen in
  let%bind token_id = Token_id.gen in
  let account_id = Account_id.create public_key token_id in
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
  create_timed account_id balance ~initial_minimum_balance ~cliff_time
    ~vesting_period ~vesting_increment