open Core_kernel
open Mina_stdlib

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('u, 's) t =
            ('u, 's) Mina_wire_types.Mina_base.User_command.Poly.V2.t =
        | Signed_command of 'u
        | Zkapp_command of 's
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end

    module V1 = struct
      type ('u, 's) t = Signed_command of 'u | Snapp_command of 's
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest : _ t -> _ V2.t = function
        | Signed_command x ->
            Signed_command x
        | Snapp_command _ ->
            failwith "Snapp_command"
    end
  end]
end

type ('u, 's) t_ = ('u, 's) Poly.Stable.Latest.t =
  | Signed_command of 'u
  | Zkapp_command of 's

module Gen_make (C : Signed_command_intf.Gen_intf) = struct
  let to_signed_command f =
    Quickcheck.Generator.map f ~f:(fun c -> Signed_command c)

  open C.Gen

  let payment ?sign_type ~key_gen ?nonce ~max_amount ~fee_range () =
    to_signed_command
      (payment ?sign_type ~key_gen ?nonce ~max_amount ~fee_range ())

  let payment_with_random_participants ?sign_type ~keys ?nonce ~max_amount
      ~fee_range () =
    to_signed_command
      (payment_with_random_participants ?sign_type ~keys ?nonce ~max_amount
         ~fee_range () )

  let stake_delegation ~key_gen ?nonce ~fee_range () =
    to_signed_command (stake_delegation ~key_gen ?nonce ~fee_range ())

  let stake_delegation_with_random_participants ~keys ?nonce ~fee_range () =
    to_signed_command
      (stake_delegation_with_random_participants ~keys ?nonce ~fee_range ())

  let sequence ?length ?sign_type a =
    Quickcheck.Generator.map
      (sequence ?length ?sign_type a)
      ~f:(List.map ~f:(fun c -> Signed_command c))
end

module Gen = Gen_make (Signed_command)

let gen_signed ~signature_kind =
  let module G = Signed_command.Gen in
  let open Quickcheck.Let_syntax in
  let%bind keys =
    Quickcheck.Generator.list_with_length 2
      Mina_base_import.Signature_keypair.gen
  in
  let sign_type = `Real signature_kind in
  G.payment_with_random_participants ~sign_type ~keys:(Array.of_list keys)
    ~max_amount:10000 ~fee_range:1000 ()

let gen =
  Gen.to_signed_command (gen_signed ~signature_kind:Mina_signature_kind.Testnet)

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      (Signed_command.Stable.V2.t, Zkapp_command.Stable.V1.t) Poly.Stable.V2.t
    [@@deriving sexp, compare, equal, hash, yojson]

    let to_latest = Fn.id
  end
end]

module Serializable_type = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( Signed_command.Stable.V2.t
        , Zkapp_command.Serializable_type.Stable.V1.t )
        Poly.Stable.V2.t

      let to_latest = Fn.id
    end
  end]
end

type t = (Signed_command.t, Zkapp_command.t) Poly.t
[@@deriving sexp_of, to_yojson]

let write_all_proofs_to_disk ~signature_kind ~proof_cache_db :
    Stable.Latest.t -> t = function
  | Signed_command sc ->
      Signed_command sc
  | Zkapp_command zc ->
      Zkapp_command
        (Zkapp_command.write_all_proofs_to_disk ~signature_kind ~proof_cache_db
           zc )

let read_all_proofs_from_disk : t -> Stable.Latest.t = function
  | Signed_command sc ->
      Signed_command sc
  | Zkapp_command zc ->
      Zkapp_command (Zkapp_command.read_all_proofs_from_disk zc)

let to_serializable_type : t -> Serializable_type.t = function
  | Signed_command sc ->
      Signed_command sc
  | Zkapp_command zc ->
      Zkapp_command (Zkapp_command.to_serializable_type zc)

type ('u, 'a, 'b) with_forest =
  (Signed_command.t, ('u, 'a, 'b) Zkapp_command.with_forest) Poly.t
[@@deriving equal]

let forget_digests_and_proofs_and_aux (t : (_, _, _) with_forest) :
    ( (_, (unit, _) Control.Poly.t, _) Account_update.Poly.t
    , unit
    , unit )
    with_forest =
  match t with
  | Signed_command sc ->
      Signed_command sc
  | Zkapp_command zc ->
      Zkapp_command (Zkapp_command.forget_digests_and_proofs_and_aux zc)

let equal_ignoring_proofs_and_hashes_and_aux
    (type update_auth_proof_l update_aux_l update_auth_proof_r update_aux_r
    account_update_digest_l forest_digest_l account_update_digest_r
    forest_digest_r )
    (t1 :
      ( ( _
        , (update_auth_proof_l, _) Control.Poly.t
        , update_aux_l )
        Account_update.Poly.t
      , account_update_digest_l
      , forest_digest_l )
      with_forest )
    (t2 :
      ( ( _
        , (update_auth_proof_r, _) Control.Poly.t
        , update_aux_r )
        Account_update.Poly.t
      , account_update_digest_r
      , forest_digest_r )
      with_forest ) =
  let ignore2 _ _ = true in
  let t1' = forget_digests_and_proofs_and_aux t1 in
  let t2' = forget_digests_and_proofs_and_aux t2 in
  equal_with_forest ignore2 ignore2 ignore2 t1' t2'

let to_base64 : Stable.Latest.t -> string = function
  | Signed_command sc ->
      Signed_command.to_base64 sc
  | Zkapp_command zc ->
      Zkapp_command.to_base64 zc

let of_base64 s : Stable.Latest.t Or_error.t =
  match Signed_command.of_base64 s with
  | Ok sc ->
      Ok (Signed_command sc)
  | Error err1 -> (
      match Zkapp_command.of_base64 s with
      | Ok zc ->
          Ok (Zkapp_command zc)
      | Error err2 ->
          Error
            (Error.of_string
               (sprintf
                  "Could decode Base64 neither to signed command (%s), nor to \
                   zkApp (%s)"
                  (Error.to_string_hum err1) (Error.to_string_hum err2) ) ) )

module Zero_one_or_two = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = [ `Zero | `One of 'a | `Two of 'a * 'a ]
      [@@deriving sexp, compare, equal, hash, yojson]
    end
  end]
end

module Verifiable = struct
  type t =
    ( Signed_command.Stable.Latest.t
    , Zkapp_command.Verifiable.t )
    Poly.Stable.Latest.t
  [@@deriving sexp_of]

  let fee_payer (t : t) =
    match t with
    | Signed_command x ->
        Signed_command.fee_payer x
    | Zkapp_command p ->
        Account_update.Fee_payer.account_id p.fee_payer

  module Serializable = struct
    type t =
      ( Signed_command.Stable.Latest.t
      , Zkapp_command.Verifiable.Serializable.t )
      Poly.Stable.Latest.t
    [@@deriving bin_io_unversioned]
  end

  let to_serializable (t : t) : Serializable.t =
    match t with
    | Signed_command c ->
        Signed_command c
    | Zkapp_command cmd ->
        Zkapp_command (Zkapp_command.Verifiable.to_serializable cmd)

  let of_serializable ~proof_cache_db (t : Serializable.t) : t =
    match t with
    | Signed_command c ->
        Signed_command c
    | Zkapp_command cmd ->
        Zkapp_command
          (Zkapp_command.Verifiable.of_serializable ~proof_cache_db cmd)
end

let to_verifiable (t : t) ~failed ~find_vk : Verifiable.t Or_error.t =
  match t with
  | Signed_command c ->
      Ok (Signed_command c)
  | Zkapp_command cmd ->
      Zkapp_command.Verifiable.create ~failed ~find_vk cmd
      |> Or_error.map ~f:(fun cmd -> Zkapp_command cmd)

module Make_to_all_verifiable
    (Strategy : Zkapp_command.Verifiable.Create_all_intf) =
struct
  let to_all_verifiable (ts : t Strategy.Command_wrapper.t list) ~load_vk_cache
      : Verifiable.t Strategy.Command_wrapper.t list Or_error.t =
    (* TODO: it seems we're just doing noop with the Strategy.Command_wrapper,
       need double-check.
    *)
    let open Or_error.Let_syntax in
    let partitioner (cmd : t Strategy.Command_wrapper.t) =
      match Strategy.Command_wrapper.unwrap cmd with
      | Zkapp_command c ->
          First (Strategy.Command_wrapper.map cmd ~f:(Fn.const c))
      | Signed_command c ->
          Second (Strategy.Command_wrapper.map cmd ~f:(Fn.const c))
    in
    let process_left zk_cmds =
      (* TODO: we could optimize this by skipping the fee payer and non-proof authorizations *)
      let accounts_referenced =
        List.fold_left zk_cmds ~init:Account_id.Set.empty ~f:(fun set zk_cmd ->
            Strategy.Command_wrapper.unwrap zk_cmd
            |> Zkapp_command.accounts_referenced |> Account_id.Set.of_list
            |> Set.union set )
      in
      let vk_cache = load_vk_cache accounts_referenced in
      Strategy.create_all zk_cmds vk_cache
    in
    let process_right =
      List.map ~f:(fun cmd ->
          Strategy.Command_wrapper.map cmd ~f:(fun c -> Signed_command c) )
    in
    let finalizer vzk_cmds_m is_cmds_mapped ~f =
      let%map vzk_cmds = vzk_cmds_m in
      let vzk_cmds_mapped =
        List.map vzk_cmds ~f:(fun cmd ->
            Strategy.Command_wrapper.map cmd ~f:(fun c -> Zkapp_command c) )
      in
      f vzk_cmds_mapped is_cmds_mapped
    in
    List.process_separately ts ~partitioner ~process_left ~process_right
      ~finalizer
end

module Unapplied_sequence =
  Make_to_all_verifiable (Zkapp_command.Verifiable.From_unapplied_sequence)
module Applied_sequence =
  Make_to_all_verifiable (Zkapp_command.Verifiable.From_applied_sequence)

let of_verifiable (t : Verifiable.t) : t =
  match t with
  | Signed_command x ->
      Signed_command x
  | Zkapp_command p ->
      Zkapp_command (Zkapp_command.of_verifiable p)

let fee : (_, _, _) with_forest -> Currency.Fee.t = function
  | Signed_command x ->
      Signed_command.fee x
  | Zkapp_command p ->
      Zkapp_command.fee p

let has_insufficient_fee ~minimum_fee t = Currency.Fee.(fee t < minimum_fee)

let is_disabled = function
  | Zkapp_command _ ->
      Node_config_unconfigurable_constants.zkapps_disabled
  | _ ->
      false

(* always `Accessed` for fee payer *)
let accounts_accessed (t : (_, _, _) with_forest) (status : Transaction_status.t)
    : (Account_id.t * [ `Accessed | `Not_accessed ]) list =
  match t with
  | Signed_command x ->
      Signed_command.account_access_statuses x status
  | Zkapp_command ps ->
      Zkapp_command.account_access_statuses ps status

let accounts_referenced (t : (_, _, _) with_forest) =
  List.map (accounts_accessed t Applied) ~f:(fun (acct_id, _status) -> acct_id)

let fee_payer (t : (_, _, _) with_forest) =
  match t with
  | Signed_command x ->
      Signed_command.fee_payer x
  | Zkapp_command p ->
      Zkapp_command.fee_payer p

(** The application nonce is the nonce of the fee payer at which a user command can be applied. *)
let applicable_at_nonce (t : (_, _, _) with_forest) =
  match t with
  | Signed_command x ->
      Signed_command.nonce x
  | Zkapp_command p ->
      Zkapp_command.applicable_at_nonce p

let expected_target_nonce t = Account.Nonce.succ (applicable_at_nonce t)

let extract_vks : t -> (Account_id.t * Verification_key_wire.t) List.t =
  function
  | Signed_command _ ->
      []
  | Zkapp_command cmd ->
      Zkapp_command.extract_vks cmd

(** The target nonce is what the nonce of the fee payer will be after a user command is successfully applied. *)
let target_nonce_on_success (t : (_, _, _) with_forest) =
  match t with
  | Signed_command x ->
      Account.Nonce.succ (Signed_command.nonce x)
  | Zkapp_command p ->
      Zkapp_command.target_nonce_on_success p

let fee_token (t : (_, _, _) with_forest) =
  match t with
  | Signed_command x ->
      Signed_command.fee_token x
  | Zkapp_command x ->
      Zkapp_command.fee_token x

let valid_until (t : (_, _, _) with_forest) =
  match t with
  | Signed_command x ->
      Signed_command.valid_until x
  | Zkapp_command { fee_payer; _ } -> (
      match fee_payer.body.valid_until with
      | Some valid_until ->
          valid_until
      | None ->
          Mina_numbers.Global_slot_since_genesis.max_value )

module Valid = struct
  type t_ = t

  type t = (Signed_command.With_valid_signature.t, Zkapp_command.Valid.t) Poly.t
  [@@deriving sexp_of, to_yojson]

  module Gen = Gen_make (Signed_command.With_valid_signature)
end

module For_tests = struct
  let check_verifiable ~signature_kind (t : Verifiable.t) : Valid.t Or_error.t =
    match t with
    | Signed_command x -> (
        match Signed_command.check ~signature_kind x with
        | Some c ->
            Ok (Signed_command c)
        | None ->
            Or_error.error_string "Invalid signature" )
    | Zkapp_command p ->
        Ok (Zkapp_command (Zkapp_command.Valid.For_tests.of_verifiable p))
end

let forget_check (t : Valid.t) : t =
  match t with
  | Zkapp_command x ->
      Zkapp_command (Zkapp_command.Valid.forget x)
  | Signed_command c ->
      Signed_command (c :> Signed_command.t)

let to_valid_unsafe (t : t) =
  `If_this_is_used_it_should_have_a_comment_justifying_it
    ( match t with
    | Zkapp_command x ->
        let (`If_this_is_used_it_should_have_a_comment_justifying_it x) =
          Zkapp_command.Valid.to_valid_unsafe x
        in
        Zkapp_command x
    | Signed_command x ->
        (* This is safe due to being immediately wrapped again. *)
        let (`If_this_is_used_it_should_have_a_comment_justifying_it x) =
          Signed_command.to_valid_unsafe x
        in
        Signed_command x )

let filter_by_participant (commands : t list) public_key =
  List.filter commands ~f:(fun user_command ->
      Core_kernel.List.exists
        (accounts_referenced user_command)
        ~f:
          (Fn.compose
             (Signature_lib.Public_key.Compressed.equal public_key)
             Account_id.public_key ) )

(* A metric on user commands that should correspond roughly to resource costs
   for validation/application *)
let weight : (_, _, _) with_forest -> int = function
  | Signed_command signed_command ->
      Signed_command.payload signed_command |> Signed_command_payload.weight
  | Zkapp_command zkapp_command ->
      Zkapp_command.weight zkapp_command

(* Fee per weight unit *)
let fee_per_wu (user_command : (_, _, _) with_forest) : Currency.Fee_rate.t =
  (*TODO: return Or_error*)
  Currency.Fee_rate.make_exn (fee user_command) (weight user_command)

let valid_size ~genesis_constants = function
  | Signed_command _ ->
      Ok ()
  | Zkapp_command zkapp_command ->
      Zkapp_command.valid_size ~genesis_constants zkapp_command

let has_zero_vesting_period = function
  | Signed_command _ ->
      false
  | Zkapp_command p ->
      Zkapp_command.has_zero_vesting_period p

let is_incompatible_version = function
  | Signed_command _ ->
      false
  | Zkapp_command p ->
      Zkapp_command.is_incompatible_version p

let has_invalid_call_forest :
       ((Account_update.Body.t, _, _) Account_update.Poly.t, _, _) with_forest
    -> bool = function
  | Signed_command _ ->
      false
  | Zkapp_command cmd ->
      List.exists cmd.account_updates ~f:(fun call_forest ->
          let root_may_use_token =
            call_forest.elt.account_update.body.may_use_token
          in
          not (Account_update.May_use_token.equal root_may_use_token No) )

module Well_formedness_error = struct
  (* syntactically-evident errors such that a user command can never succeed *)
  type t =
    | Insufficient_fee
    | Zero_vesting_period
    | Zkapp_too_big of (Error.t[@to_yojson Error_json.error_to_yojson])
    | Zkapp_invalid_call_forest
    | Transaction_type_disabled
    | Incompatible_version
  [@@deriving compare, to_yojson, sexp]

  let to_string = function
    | Insufficient_fee ->
        "Insufficient fee"
    | Zero_vesting_period ->
        "Zero vesting period"
    | Zkapp_too_big err ->
        sprintf "Zkapp too big (%s)" (Error.to_string_hum err)
    | Zkapp_invalid_call_forest ->
        "Zkapp has an invalid call forest (root account updates may not use \
         tokens)"
    | Incompatible_version ->
        "Set verification-key permission is updated to an incompatible version"
    | Transaction_type_disabled ->
        "Transaction type disabled"
end

let check_well_formedness (type aux) ~(genesis_constants : Genesis_constants.t)
    (t : ((_, _, aux) Account_update.Poly.t, _, _) with_forest) :
    (unit, Well_formedness_error.t list) result =
  let preds =
    let open Well_formedness_error in
    [ ( has_insufficient_fee
          ~minimum_fee:genesis_constants.minimum_user_command_fee
      , Insufficient_fee )
    ; (has_zero_vesting_period, Zero_vesting_period)
    ; (is_incompatible_version, Incompatible_version)
    ; (is_disabled, Transaction_type_disabled)
    ; (has_invalid_call_forest, Zkapp_invalid_call_forest)
    ]
  in
  let errs0 =
    List.fold preds ~init:[] ~f:(fun acc (f, err) ->
        if f t then err :: acc else acc )
  in
  let errs =
    match valid_size ~genesis_constants t with
    | Ok () ->
        errs0
    | Error err ->
        Zkapp_too_big err :: errs0
  in
  if List.is_empty errs then Ok () else Error errs

type fee_payer_summary_t = Signature.t * Account.key * int
[@@deriving yojson, hash]

let fee_payer_summary : (_, _, _) with_forest -> fee_payer_summary_t = function
  | Zkapp_command cmd ->
      let fp = Zkapp_command.fee_payer_account_update cmd in
      let open Account_update in
      let body = Fee_payer.body fp in
      ( Fee_payer.authorization fp
      , Body.Fee_payer.public_key body
      , Body.Fee_payer.nonce body |> Unsigned.UInt32.to_int )
  | Signed_command cmd ->
      Signed_command.
        (signature cmd, fee_payer_pk cmd, nonce cmd |> Unsigned.UInt32.to_int)

let fee_payer_summary_json tx =
  fee_payer_summary_t_to_yojson (fee_payer_summary tx)

let fee_payer_summary_string tx =
  let signature, pk, nonce = fee_payer_summary tx in
  sprintf "%s (%s %d)"
    (Signature.to_base58_check signature)
    (Signature_lib.Public_key.Compressed.to_base58_check pk)
    nonce
