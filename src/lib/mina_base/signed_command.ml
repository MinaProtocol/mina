[%%import "/src/config.mlh"]

open Core_kernel
open Mina_base_import
open Mina_numbers

(** See documentation of the {!Mina_wire_types} library *)
module Wire_types = Mina_wire_types.Mina_base.Signed_command

module Make_sig (A : Wire_types.Types.S) = struct
  module type S =
    Signed_command_intf.Full
      with type With_valid_signature.Stable.Latest.t =
        A.With_valid_signature.V2.t
end

module Make_str (_ : Wire_types.Concrete) = struct
  module Fee = Currency.Fee
  module Payload = Signed_command_payload

  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        [@@@with_all_version_tags]

        type ('payload, 'pk, 'signature) t =
              ( 'payload
              , 'pk
              , 'signature )
              Mina_wire_types.Mina_base.Signed_command.Poly.V1.t =
          { payload : 'payload; signer : 'pk; signature : 'signature }
        [@@deriving compare, sexp, hash, yojson, equal]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    [@@@with_top_version_tag]

    (* DO NOT DELETE VERSIONS!
       so we can always get transaction hashes from old transaction ids
       the version linter should be checking this

       IF YOU CREATE A NEW VERSION:
       update Transaction_hash.hash_of_transaction_id to handle it
       add hash_signed_command_vn for that version
    *)

    module V2 = struct
      type t =
        ( Payload.Stable.V2.t
        , Public_key.Stable.V1.t
        , Signature.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving compare, sexp, hash, yojson]

      let to_latest = Fn.id

      module T = struct
        (* can't use nonrec + deriving *)
        type typ = t [@@deriving compare, sexp, hash]

        type t = typ [@@deriving compare, sexp, hash]
      end

      include Comparable.Make (T)
      include Hashable.Make (T)

      let account_access_statuses ({ payload; _ } : t) status =
        Payload.account_access_statuses payload status

      let accounts_referenced (t : t) =
        List.map (account_access_statuses t Applied)
          ~f:(fun (acct_id, _status) -> acct_id)
    end

    module V1 = struct
      [@@@with_all_version_tags]

      type t =
        ( Payload.Stable.V1.t
        , Public_key.Stable.V1.t
        , Signature.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving compare, sexp, hash, yojson]

      let to_latest ({ payload; signer; signature } : t) : Latest.t =
        let payload : Signed_command_payload.t =
          let valid_until =
            Global_slot_legacy.to_uint32 payload.common.valid_until
            |> Global_slot_since_genesis.of_uint32
          in
          let common : Signed_command_payload.Common.t =
            { fee = payload.common.fee
            ; fee_payer_pk = payload.common.fee_payer_pk
            ; nonce = payload.common.nonce
            ; valid_until
            ; memo = payload.common.memo
            }
          in
          let body : Signed_command_payload.Body.t =
            match payload.body with
            | Payment payment_payload ->
                let payload' : Payment_payload.t =
                  { receiver_pk = payment_payload.receiver_pk
                  ; amount = payment_payload.amount
                  }
                in
                Payment payload'
            | Stake_delegation stake_delegation_payload ->
                Stake_delegation
                  (Stake_delegation.Stable.V1.to_latest stake_delegation_payload)
          in
          { common; body }
        in
        { payload; signer; signature }
    end
  end]

  (* type of signed commands, pre-Berkeley hard fork *)
  type t_v1 = Stable.V1.t

  let (_ : (t, (Payload.t, Public_key.t, Signature.t) Poly.t) Type_equal.t) =
    Type_equal.T

  include (Stable.Latest : module type of Stable.Latest with type t := t)

  let payload Poly.{ payload; _ } = payload

  let fee = Fn.compose Payload.fee payload

  let nonce = Fn.compose Payload.nonce payload

  (* for filtering *)
  let minimum_fee = Currency.Fee.minimum_user_command_fee

  let has_insufficient_fee t = Currency.Fee.(fee t < minimum_fee)

  let signer { Poly.signer; _ } = signer

  let fee_token (_ : t) = Token_id.default

  let fee_payer_pk ({ payload; _ } : t) = Payload.fee_payer_pk payload

  let fee_payer ({ payload; _ } : t) = Payload.fee_payer payload

  let fee_excess ({ payload; _ } : t) = Payload.fee_excess payload

  let token ({ payload; _ } : t) = Payload.token payload

  let receiver_pk ({ payload; _ } : t) = Payload.receiver_pk payload

  let receiver ({ payload; _ } : t) = Payload.receiver payload

  let amount = Fn.compose Payload.amount payload

  let memo = Fn.compose Payload.memo payload

  let valid_until = Fn.compose Payload.valid_until payload

  let tag ({ payload; _ } : t) = Payload.tag payload

  let tag_string (t : t) =
    match t.payload.body with
    | Payment _ ->
        "payment"
    | Stake_delegation _ ->
        "delegation"

  let to_input_legacy (payload : Payload.t) =
    Transaction_union_payload.(
      to_input_legacy (of_user_command_payload payload))

  let sign_payload ?signature_kind (private_key : Signature_lib.Private_key.t)
      (payload : Payload.t) : Signature.t =
    Signature_lib.Schnorr.Legacy.sign ?signature_kind private_key
      (to_input_legacy payload)

  let sign ?signature_kind (kp : Signature_keypair.t) (payload : Payload.t) : t
      =
    { payload
    ; signer = kp.public_key
    ; signature = sign_payload ?signature_kind kp.private_key payload
    }

  module For_tests = struct
    (* Pretend to sign a command. Much faster than actually signing. *)
    let fake_sign ?signature_kind:_ (kp : Signature_keypair.t)
        (payload : Payload.t) : t =
      { payload; signer = kp.public_key; signature = Signature.dummy }
  end

  module Gen = struct
    let gen_inner (sign' : Signature_lib.Keypair.t -> Payload.t -> t) ~key_gen
        ?(nonce = Account_nonce.zero) ~fee_range create_body =
      let open Quickcheck.Generator.Let_syntax in
      let min_fee = Fee.to_nanomina_int Currency.Fee.minimum_user_command_fee in
      let max_fee = min_fee + fee_range in
      let%bind (signer : Signature_keypair.t), (receiver : Signature_keypair.t)
          =
        key_gen
      and fee =
        Int.gen_incl min_fee max_fee >>| Currency.Fee.of_nanomina_int_exn
      and memo = String.quickcheck_generator in
      let%map body = create_body signer receiver in
      let payload : Payload.t =
        Payload.create ~fee
          ~fee_payer_pk:(Public_key.compress signer.public_key)
          ~nonce ~valid_until:None
          ~memo:(Signed_command_memo.create_by_digesting_string_exn memo)
          ~body
      in
      sign' signer payload

    let with_random_participants ~keys ~gen =
      let key_gen = Quickcheck_lib.gen_pair @@ Quickcheck_lib.of_array keys in
      gen ~key_gen

    module Payment = struct
      let gen_inner (sign' : Signature_lib.Keypair.t -> Payload.t -> t) ~key_gen
          ?nonce ?(min_amount = 1) ~max_amount ~fee_range () =
        gen_inner sign' ~key_gen ?nonce ~fee_range
        @@ fun { public_key = signer; _ } { public_key = receiver; _ } ->
        let open Quickcheck.Generator.Let_syntax in
        let%map amount =
          Int.gen_incl min_amount max_amount
          >>| Currency.Amount.of_nanomina_int_exn
        in
        Signed_command_payload.Body.Payment
          { receiver_pk = Public_key.compress receiver; amount }

      let gen ?(sign_type = `Fake) =
        match sign_type with
        | `Fake ->
            gen_inner For_tests.fake_sign
        | `Real ->
            gen_inner sign

      let gen_with_random_participants ?sign_type ~keys ?nonce ?min_amount
          ~max_amount ~fee_range =
        with_random_participants ~keys ~gen:(fun ~key_gen ->
            gen ?sign_type ~key_gen ?nonce ?min_amount ~max_amount ~fee_range )
    end

    module Stake_delegation = struct
      let gen ~key_gen ?nonce ~fee_range () =
        gen_inner For_tests.fake_sign ~key_gen ?nonce ~fee_range
          (fun { public_key = signer; _ } { public_key = new_delegate; _ } ->
            Quickcheck.Generator.return
            @@ Signed_command_payload.Body.Stake_delegation
                 (Set_delegate
                    { new_delegate = Public_key.compress new_delegate } ) )

      let gen_with_random_participants ~keys ?nonce ~fee_range =
        with_random_participants ~keys ~gen:(gen ?nonce ~fee_range)
    end

    let payment = Payment.gen

    let payment_with_random_participants = Payment.gen_with_random_participants

    let stake_delegation = Stake_delegation.gen

    let stake_delegation_with_random_participants =
      Stake_delegation.gen_with_random_participants

    let sequence :
           ?length:int
        -> ?sign_type:[ `Fake | `Real ]
        -> ( Signature_lib.Keypair.t
           * Currency.Amount.t
           * Mina_numbers.Account_nonce.t
           * Account_timing.t )
           array
        -> t list Quickcheck.Generator.t =
     fun ?length ?(sign_type = `Fake) account_info ->
      let open Quickcheck.Generator in
      let open Quickcheck.Generator.Let_syntax in
      let%bind n_commands =
        Option.value_map length ~default:small_non_negative_int ~f:return
      in
      if Int.(n_commands = 0) then return []
      else
        let n_accounts = Array.length account_info in
        let%bind command_senders, currency_splits =
          (* How many commands will be issued from each account? *)
          (let%bind command_splits =
             Quickcheck_lib.gen_division n_commands n_accounts
           in
           let command_splits' = Array.of_list command_splits in
           (* List of payment senders in the final order. *)
           let%bind command_senders =
             Quickcheck_lib.shuffle
             @@ List.concat_mapi command_splits ~f:(fun idx cmds ->
                    List.init cmds ~f:(Fn.const idx) )
           in
           (* within the accounts, how will the currency be split into separate
              payments? *)
           let%bind currency_splits =
             Quickcheck_lib.init_gen_array
               ~f:(fun i ->
                 let%bind spend_all = bool in
                 let _, balance, _, _ = account_info.(i) in
                 let amount_to_spend =
                   if spend_all then balance
                   else
                     Currency.Amount.of_nanomina_int_exn
                       (Currency.Amount.to_nanomina_int balance / 2)
                 in
                 Quickcheck_lib.gen_division_currency amount_to_spend
                   command_splits'.(i) )
               n_accounts
           in
           return (command_senders, currency_splits) )
          |> (* We need to ensure each command has enough currency for a fee of 2
                or more, so it'll be enough to buy the requisite transaction
                snarks. It's important that the backtracking from filter goes and
                redraws command_splits as well as currency_splits, so we don't get
                stuck in a situation where it's very unlikely for the predicate to
                pass. *)
          Quickcheck.Generator.filter ~f:(fun (_, splits) ->
              Array.for_all splits ~f:(fun split ->
                  List.for_all split ~f:(fun amt ->
                      Currency.Amount.(amt >= of_mina_int_exn 2) ) ) )
        in
        let account_nonces =
          Array.map ~f:(fun (_, _, nonce, _) -> nonce) account_info
        in
        let uncons_exn = function
          | [] ->
              failwith "uncons_exn"
          | x :: xs ->
              (x, xs)
        in
        Quickcheck_lib.map_gens command_senders ~f:(fun sender ->
            let this_split, rest_splits = uncons_exn currency_splits.(sender) in
            let sender_pk, _, _, _ = account_info.(sender) in
            currency_splits.(sender) <- rest_splits ;
            let nonce = account_nonces.(sender) in
            account_nonces.(sender) <- Account_nonce.succ nonce ;
            let%bind fee =
              (* use of_string here because json_of_ocaml won't handle
                 equivalent integer constants
              *)
              Currency.Fee.(
                gen_incl (of_string "6000000000")
                  (min (of_string "10000000000")
                     (Currency.Amount.to_fee this_split) ))
            in
            let amount =
              Option.value_exn Currency.Amount.(this_split - of_fee fee)
            in
            let%bind receiver =
              map ~f:(fun idx ->
                  let kp, _, _, _ = account_info.(idx) in
                  Public_key.compress kp.public_key )
              @@ Int.gen_uniform_incl 0 (n_accounts - 1)
            in
            let memo = Signed_command_memo.dummy in
            let payload =
              let sender_pk = Public_key.compress sender_pk.public_key in
              Payload.create ~fee ~fee_payer_pk:sender_pk ~valid_until:None
                ~nonce ~memo
                ~body:(Payment { receiver_pk = receiver; amount })
            in
            let sign' =
              match sign_type with
              | `Fake ->
                  For_tests.fake_sign
              | `Real ->
                  sign
            in
            return @@ sign' sender_pk payload )
  end

  module With_valid_signature = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t = Stable.V2.t [@@deriving sexp, equal, yojson, hash]

        let to_latest = Stable.V2.to_latest

        let compare = Stable.V2.compare

        let equal = Stable.V2.equal

        module Gen = Gen
      end
    end]

    module Gen = Stable.Latest.Gen
    include Comparable.Make (Stable.Latest)
  end

  let to_valid_unsafe t =
    `If_this_is_used_it_should_have_a_comment_justifying_it t

  (* so we can deserialize Base58Check transaction ids created before Berkeley hard fork *)
  module V1_all_tagged = struct
    include Stable.V1.With_all_version_tags

    let description = "Signed command"

    let version_byte = Base58_check.Version_bytes.signed_command_v1
  end

  let of_base58_check_exn_v1, to_base58_check_v1 =
    let module Base58_check_v1 = Codable.Make_base58_check (V1_all_tagged) in
    Base58_check_v1.(of_base58_check, to_base58_check)

  (* give transaction ids have version tag *)
  include Codable.Make_base64 (Stable.Latest.With_top_version_tag)

  let check_signature ?signature_kind ({ payload; signer; signature } : t) =
    Signature_lib.Schnorr.Legacy.verify ?signature_kind signature
      (Snark_params.Tick.Inner_curve.of_affine signer)
      (to_input_legacy payload)

  let public_keys t =
    let fee_payer = fee_payer_pk t in
    let receiver = receiver_pk t in
    [ fee_payer; receiver ]

  let check_valid_keys t =
    List.for_all (public_keys t) ~f:(fun pk ->
        Option.is_some (Public_key.decompress pk) )

  let create_with_signature_checked ?signature_kind signature signer payload =
    let open Option.Let_syntax in
    let%bind signer = Public_key.decompress signer in
    let t = Poly.{ payload; signature; signer } in
    Option.some_if (check_signature ?signature_kind t && check_valid_keys t) t

  let gen_test =
    let open Quickcheck.Let_syntax in
    let%bind keys =
      Quickcheck.Generator.list_with_length 2 Signature_keypair.gen
    in
    Gen.payment_with_random_participants ~sign_type:`Real
      ~keys:(Array.of_list keys) ~max_amount:10000 ~fee_range:1000 ()

  let%test_unit "completeness" =
    Quickcheck.test ~trials:20 gen_test ~f:(fun t -> assert (check_signature t))

  let%test_unit "json" =
    Quickcheck.test ~trials:20 ~sexp_of:sexp_of_t gen_test ~f:(fun t ->
        assert (Codable.For_tests.check_encoding (module Stable.Latest) ~equal t) )

  (* return type is `t option` here, interface coerces that to `With_valid_signature.t option` *)
  let check t = Option.some_if (check_signature t && check_valid_keys t) t

  (* return type is `t option` here, interface coerces that to `With_valid_signature.t option` *)
  let check_only_for_signature t = Option.some_if (check_signature t) t

  let forget_check t = t

  let filter_by_participant user_commands public_key =
    List.filter user_commands ~f:(fun user_command ->
        Core_kernel.List.exists
          (accounts_referenced user_command)
          ~f:
            (Fn.compose
               (Public_key.Compressed.equal public_key)
               Account_id.public_key ) )

  let%test "latest signed command version" =
    (* if this test fails, update `Transaction_hash.hash_of_transaction_id`
       for latest version, then update this test
    *)
    Int.equal Stable.Latest.version 2
end

include Wire_types.Make (Make_sig) (Make_str)
