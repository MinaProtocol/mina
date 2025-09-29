open Core_kernel
module Js = Js_of_ocaml.Js
module Impl = Pickles.Impls.Step
module Field = Impl.Field

(* Ledger - local mina transaction logic for prototyping and testing zkapps *)

type public_key = Signature_lib.Public_key.Compressed.t

module Account_update = Mina_base.Account_update
module Zkapp_command = Mina_base.Zkapp_command

let ledger_class : < .. > Js.t =
  Js.Unsafe.eval_string {js|(function(v) { this.value = v; return this })|js}

module Ledger : Mina_base.Ledger_intf.S = struct
  module Account = Mina_base.Account
  module Account_id = Mina_base.Account_id
  module Ledger_hash = Mina_base.Ledger_hash
  module Token_id = Mina_base.Token_id

  type t_ =
    { next_location : int
    ; accounts : Account.t Int.Map.t
    ; locations : int Account_id.Map.t
    }

  type t = t_ ref

  type location = int

  let get (t : t) (loc : location) : Account.t option = Map.find !t.accounts loc

  let location_of_account (t : t) (a : Account_id.t) : location option =
    Map.find !t.locations a

  let set (t : t) (loc : location) (a : Account.t) : unit =
    t := { !t with accounts = Map.set !t.accounts ~key:loc ~data:a }

  let next_location (t : t) : int =
    let loc = !t.next_location in
    t := { !t with next_location = loc + 1 } ;
    loc

  let get_or_create (t : t) (id : Account_id.t) :
      (Mina_base.Ledger_intf.account_state * Account.t * location) Or_error.t =
    let loc = location_of_account t id in
    let res =
      match loc with
      | None ->
          let loc = next_location t in
          let a = Account.create id Currency.Balance.zero in
          t := { !t with locations = Map.set !t.locations ~key:id ~data:loc } ;
          set t loc a ;
          (`Added, a, loc)
      | Some loc ->
          (`Existed, Option.value_exn (get t loc), loc)
    in
    Ok res

  let[@warning "-32"] get_or_create_account (t : t) (id : Account_id.t)
      (a : Account.t) :
      (Mina_base.Ledger_intf.account_state * location) Or_error.t =
    match location_of_account t id with
    | Some loc ->
        let a' = Option.value_exn (get t loc) in
        if Account.equal a a' then Ok (`Existed, loc)
        else
          Or_error.errorf
            !"account %{sexp: Account_id.t} already present with different \
              contents"
            id
    | None ->
        let loc = next_location t in
        t := { !t with locations = Map.set !t.locations ~key:id ~data:loc } ;
        set t loc a ;
        Ok (`Added, loc)

  let create_new_account (t : t) (id : Account_id.t) (a : Account.t) :
      unit Or_error.t =
    match location_of_account t id with
    | Some _ ->
        Or_error.errorf !"account %{sexp: Account_id.t} already present" id
    | None ->
        let loc = next_location t in
        t := { !t with locations = Map.set !t.locations ~key:id ~data:loc } ;
        set t loc a ;
        Ok ()

  let[@warning "-32"] remove_accounts_exn (t : t) (ids : Account_id.t list) :
      unit =
    let locs = List.filter_map ids ~f:(fun id -> Map.find !t.locations id) in
    t :=
      { !t with
        locations = List.fold ids ~init:!t.locations ~f:Map.remove
      ; accounts = List.fold locs ~init:!t.accounts ~f:Map.remove
      }

  (* TODO *)
  let merkle_root (_ : t) : Ledger_hash.t = Field.Constant.zero

  let empty ~depth:_ () : t =
    ref
      { next_location = 0
      ; accounts = Int.Map.empty
      ; locations = Account_id.Map.empty
      }

  let with_ledger (type a) ~depth ~(f : t -> a) : a = f (empty ~depth ())

  let create_masked (t : t) : t = ref !t

  let apply_mask (t : t) ~(masked : t) = t := !masked
end

module Transaction_logic = Mina_transaction_logic.Make (Ledger)

type ledger_class = < value : Ledger.t Js.prop >

let ledger_constr : (Ledger.t -> ledger_class Js.t) Js.constr =
  Obj.magic ledger_class

let create_new_account_exn (t : Ledger.t) account_id account =
  Ledger.create_new_account t account_id account |> Or_error.ok_exn

let default_token_id =
  Mina_base.Token_id.default |> Mina_base.Token_id.to_field_unsafe

let account_id (pk : public_key) token =
  Mina_base.Account_id.create pk (Mina_base.Token_id.of_field token)

module To_js = struct
  let option (transform : 'a -> 'b) (x : 'a option) =
    Js.Optdef.option (Option.map x ~f:transform)
end

let check_account_update_signatures zkapp_command =
  let ({ fee_payer; account_updates; memo } : Zkapp_command.t) =
    zkapp_command
  in
  let tx_commitment = Zkapp_command.commitment zkapp_command in
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let full_tx_commitment =
    Zkapp_command.Transaction_commitment.create_complete tx_commitment
      ~memo_hash:(Mina_base.Signed_command_memo.hash memo)
      ~fee_payer_hash:
        (Zkapp_command.Digest.Account_update.create ~signature_kind
           (Account_update.of_fee_payer fee_payer) )
  in
  let key_to_string = Signature_lib.Public_key.Compressed.to_base58_check in
  let check_signature who s pk msg =
    match Signature_lib.Public_key.decompress pk with
    | None ->
        failwith
          (sprintf "Check signature: Invalid key on %s: %s" who
             (key_to_string pk) )
    | Some pk_ ->
        if
          not
            (Signature_lib.Schnorr.Chunked.verify
               ~signature_kind:Mina_signature_kind.t_DEPRECATED s
               (Kimchi_pasta.Pasta.Pallas.of_affine pk_)
               (Random_oracle_input.Chunked.field msg) )
        then
          failwith
            (sprintf "Check signature: Invalid signature on %s for key %s" who
               (key_to_string pk) )
        else ()
  in

  check_signature "fee payer" fee_payer.authorization fee_payer.body.public_key
    full_tx_commitment ;
  List.iteri (Zkapp_command.Call_forest.to_account_updates account_updates)
    ~f:(fun i p ->
      let commitment =
        if p.body.use_full_commitment then full_tx_commitment else tx_commitment
      in
      match p.authorization with
      | Signature s ->
          check_signature
            (sprintf "account_update %d" i)
            s p.body.public_key commitment
      | Proof _ | None_given ->
          () )

let add_account_exn (l : Ledger.t) pk (balance : string) =
  let account_id = account_id pk default_token_id in
  let bal_u64 = Unsigned.UInt64.of_string balance in
  let balance = Currency.Balance.of_uint64 bal_u64 in
  let a : Mina_base.Account.t = Mina_base.Account.create account_id balance in
  create_new_account_exn l account_id a

let create () : ledger_class Js.t =
  let l = Ledger.empty ~depth:20 () in
  new%js ledger_constr l

let account_to_json =
  let deriver =
    lazy (Mina_base.Account.deriver @@ Fields_derivers_zkapps.o ())
  in
  let to_json (account : Mina_base.Account.t) : Js.Unsafe.any =
    Mina_base.Account.to_poly account
    |> Fields_derivers_zkapps.to_json (Lazy.force deriver)
    |> Yojson.Safe.to_string |> Js.string |> Util.json_parse
  in
  to_json

let get_account l (pk : public_key) (token : Impl.field) :
    Js.Unsafe.any Js.optdef =
  let loc = Ledger.location_of_account l##.value (account_id pk token) in
  let account = Option.bind loc ~f:(Ledger.get l##.value) in
  To_js.option account_to_json account

let add_account l (pk : public_key) (balance : Js.js_string Js.t) =
  add_account_exn l##.value pk (Js.to_string balance)

let protocol_state_of_json =
  let deriver =
    lazy
      ( Mina_base.Zkapp_precondition.Protocol_state.View.deriver
      @@ Fields_derivers_zkapps.o () )
  in
  fun (json : Js.js_string Js.t) :
      Mina_base.Zkapp_precondition.Protocol_state.View.t ->
    json |> Js.to_string |> Yojson.Safe.from_string
    |> Fields_derivers_zkapps.of_json (Lazy.force deriver)

let proof_cache_db = Proof_cache_tag.create_identity_db ()

let apply_zkapp_command_transaction l (txn : Zkapp_command.Stable.Latest.t)
    (account_creation_fee : string)
    (network_state : Mina_base.Zkapp_precondition.Protocol_state.View.t) =
  let signature_kind = Mina_signature_kind_type.Testnet in
  let txn =
    Zkapp_command.write_all_proofs_to_disk ~signature_kind ~proof_cache_db txn
  in
  check_account_update_signatures txn ;
  let ledger = l##.value in
  let application_result =
    Transaction_logic.apply_zkapp_command_unchecked ~signature_kind
      ~global_slot:network_state.global_slot_since_genesis
      ~state_view:network_state
      ~constraint_constants:
        { Genesis_constants.Compiled.constraint_constants with
          account_creation_fee = Currency.Fee.of_string account_creation_fee
        }
      ledger txn
  in
  let applied, _ =
    match application_result with
    | Ok res ->
        res
    | Error err ->
        Util.raise_error (Error.to_string_hum err)
  in
  match applied.command.status with
  | Applied ->
      ()
  | Failed failures ->
      Util.raise_error
        ( Mina_base.Transaction_status.Failure.Collection.to_yojson failures
        |> Yojson.Safe.to_string )

let apply_json_transaction l (tx_json : Js.js_string Js.t)
    (account_creation_fee : Js.js_string Js.t) (network_json : Js.js_string Js.t)
    =
  let txn =
    Zkapp_command.of_json @@ Yojson.Safe.from_string @@ Js.to_string tx_json
  in
  let network_state = protocol_state_of_json network_json in
  apply_zkapp_command_transaction l txn
    (Js.to_string account_creation_fee)
    network_state

let method_ class_ (name : string) (f : _ Js.t -> _) =
  let prototype = Js.Unsafe.get class_ (Js.string "prototype") in
  Js.Unsafe.set prototype (Js.string name) (Js.wrap_meth_callback f)

let () =
  let static_method name f =
    Js.Unsafe.set ledger_class (Js.string name) (Js.wrap_callback f)
  in
  let method_ name (f : ledger_class Js.t -> _) = method_ ledger_class name f in
  static_method "create" create ;

  method_ "getAccount" get_account ;
  method_ "addAccount" add_account ;
  method_ "applyJsonTransaction" apply_json_transaction
