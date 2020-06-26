(* similar to account.ml *)


open Core_kernel
open Coda_base


open Snark_params
open Tick



open Currency
open Coda_numbers


module Index = struct
  type t = int [@@deriving to_yojson, sexp] 



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



  module Unpacked = struct
    type var = Tick.Boolean.var list

    type value = Vector.t

    let typ ~ledger_depth : (var, value) Tick.Typ.t =
      Typ.transport
        (Typ.list ~length:ledger_depth Boolean.typ)
        ~there:(to_bits ~ledger_depth) ~back:of_bits
  end


end


module Poly = struct
  module Stable = struct
    module V1 = struct
      type ( 'dm
           , 'pk
           , 'receipt_chain_hash
           , 'state_hash)
           t =
        { domain: 'dm
        ; public_key: 'pk
        ; receipt_chain_hash: 'receipt_chain_hash
        ; voting_for: 'state_hash }
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end

  type ( 'dm
       , 'pk
       , 'receipt_chain_hash
       , 'state_hash)
       t =
        { domain: 'dm
        ; public_key: 'pk
        ; receipt_chain_hash: 'receipt_chain_hash
        ; voting_for: 'state_hash}
  [@@deriving sexp, eq, compare, hash, yojson, fields]



  let of_hlist
      ([ domain
       ; public_key
       ; receipt_chain_hash
       ; voting_for ] :
        (unit, _) H_list.t) =
    { domain
    ; public_key
    ; receipt_chain_hash
    ; voting_for }

  let to_hlist
      { domain
      ; public_key
      ; receipt_chain_hash
      ; voting_for } =
    H_list.
      [ domain
      ; public_key
      ; receipt_chain_hash
      ; voting_for ]

end

module DomainPlus = struct




type domainPlus = t [@@deriving sexp, eq, hash, compare, yojson]

module Identifier = Domain

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Domain.Stable.V1.t
      , Public_key.Compressed.Stable.V1.t
      , Receipt.Chain_hash.Stable.V1.t
      , State_hash.Stable.V1.t)
      Poly.Stable.V1.t
    [@@deriving sexp, eq, hash, compare, yojson]

    let to_latest = Fn.id

    let domain (t : t) : domainPlus = t.domain
  end
end]

type t = Stable.Latest.t [@@deriving sexp, eq, hash, compare, yojson]

[%%define_locally
Stable.Latest.(domain)]

let identifier ({domain; _} : t) =
  domain

type value =
  ( Domain.t
  , Public_key.Compressed.t
  , Receipt.Chain_hash.t
  , State_hash.t)
  Poly.t
[@@deriving sexp]

(* let key_gen = Public_key.Compressed.gen *)

let initialize domain : t =
  { domain
  ; public_key = Public_key.Compressed.empty
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; voting_for= State_hash.dummy }

let to_input (t : t) =
  let open Random_oracle.Input in
  let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
  let bits conv = f (Fn.compose bitstring conv) in
  Poly.Fields.fold ~init:[]
    ~domain:(f (fun x -> bitstring [x]))
    ~public_key:(f Public_key.Compressed.to_input)
    ~receipt_chain_hash:(f Receipt.Chain_hash.to_input)
    ~voting_for:(f State_hash.to_input) 
  |> List.reduce_exn ~f:append

let crypto_hash_prefix = Random_oracle.salt (domaccount :> string) 

let crypto_hash t =
  Random_oracle.hash ~init:crypto_hash_prefix
    (Random_oracle.pack_input (to_input t))



type var =
  ( Domain.var
  , Public_key.Compressed.var
  , Receipt.Chain_hash.var
  , State_hash.var)
  Poly.t

let identifier_of_var ({domain; _} : var) = domain

let typ : (var, value) Typ.t =
  let spec =
    Data_spec.
      [ Domain.typ
      ; Public_key.Compressed.typ
      ; Receipt.Chain_hash.typ
      ; State_hash.typ]
  in
  Typ.of_hlistable spec ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
    ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

let var_of_t
    ({ domain
     ; public_key
     ; receipt_chain_hash
     ; voting_for } :
      value) =
  { Poly.domain= Domain.var_of_t domain
  ; public_key= Public_key.Compressed.var_of_t public_key
  ; receipt_chain_hash= Receipt.Chain_hash.var_of_t receipt_chain_hash
  ; voting_for= State_hash.var_of_t voting_for }

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
             ~domain:(f (fun x -> bitstring [x]))
             ~public_key:(f Public_key.Compressed.Checked.to_input)
             ~receipt_chain_hash:(f Receipt.Chain_hash.var_to_input)
             ~voting_for:(f State_hash.var_to_input) )

  let digest t =
    make_checked (fun () ->
        Random_oracle.Checked.(
          hash ~init:crypto_hash_prefix
            (pack_input (Run.run_checked (to_input t)))) )
end



let digest = crypto_hash

let empty =
  { Poly.domain = Domain.Compressed.empty
  ; public_key= Public_key.Compressed.empty
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; voting_for= State_hash.dummy }

let empty_digest = digest empty

let create domain =
  let public_key = Public_key.Compressed.empty 
  in
  { Poly.domain
  ; public_key
  ; receipt_chain_hash= Receipt.Chain_hash.empty
  ; voting_for= State_hash.dummy  }

  (* likely not needed *) (*
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
      ; token_owner= false
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
 *)
let gen =
  let open Quickcheck.Let_syntax in
  let%bind public_key = Public_key.Compressed.gen in
  let%bind token_id = Token_id.gen in
  let%map balance = Currency.Balance.gen in
  create (Account_id.create public_key token_id) balance



  index: ledgers, 
  prover: 
type t at 31
  https://github.com/CodaProtocol/coda/blob/1f85b55b67742598116490408322872b05b45b91/src/lib/merkle_mask/masking_merkle_tree.ml