[%%import "/src/config.mlh"]

open Core_kernel
open Mina_base_util

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%endif]

module Frozen_ledger_hash = Frozen_ledger_hash0
module Ledger_hash = Ledger_hash0

(* Semantically this type represents a function
     { has_valid_signature: bool; has_valid_proof: bool } -> bool

     These are all of them:
     00 01 10 11 | intuitive definition       | Make sense
     0  0  0  0  | Impossible                 | yes
     0  0  0  1  | Both                       | yes
     0  0  1  0  | Proof and not signature    | no
     0  0  1  1  | Proof                      | yes
     0  1  0  0  | Signature and not proof    | no
     0  1  0  1  | Signature                  | yes
     0  1  1  0  | Exactly one                | no
     0  1  1  1  | Either                     | yes
     1  0  0  0  | Neither                    | no
     1  0  0  1  | Neither or both            | no
     1  0  1  0  | Neither or proof, not both | no
     ...
     1  1  1  1  | None                       | yes

     The ones marked as "not making sense" don't make sense because it is pointless
     to demand a signature failed to verify since you can always make a failing signature
     or proof.

     The ones that make sense are
     0  0  0  0  | Impossible                 | yes
     0  0  0  1  | Both                       | yes
     0  0  1  1  | Proof                      | yes
     0  1  0  1  | Signature                  | yes
     0  1  1  1  | Either                     | yes
     1  1  1  1  | None                       | yes

     "Making sense" can be captured by the idea that these are the *increasing*
     boolean functions on the type { has_valid_signature: bool; has_valid_proof: bool }.
*)
module Auth_required = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Mina_wire_types.Mina_base.Permissions.Auth_required.V2.t =
        | None
        | Either
        | Proof
        | Signature
        | Impossible (* Both and either can both be subsumed in verification key.
                        It is good to have "Either" as a separate thing to spare the owner from
                        having to make a proof instead of a signature. Both, I'm not sure if there's
                        a good justification for. *)
      [@@deriving sexp, equal, compare, hash, yojson, enum]

      let to_latest = Fn.id
    end
  end]

  let from ~auth_tag : t =
    match auth_tag with
    | Control.Tag.Proof ->
        Proof
    | Signature ->
        Signature
    | None_given ->
        None

  let verification_key_perm_fallback_to_signature_with_older_version = function
    | Impossible | Proof ->
        Signature
    | t ->
        t

  (* permissions such that [check permission (Proof _)] is true *)
  let gen_for_proof_authorization : t Quickcheck.Generator.t =
    Quickcheck.Generator.of_list [ None; Either; Proof ]

  (* permissions such that [check permission (Signature _)] is true *)
  let gen_for_signature_authorization : t Quickcheck.Generator.t =
    Quickcheck.Generator.of_list [ None; Either; Signature ]

  (* permissions such that [check permission None_given] is true *)
  let gen_for_none_given_authorization : t Quickcheck.Generator.t =
    Quickcheck.Generator.return None

  let to_string = function
    | None ->
        "None"
    | Either ->
        "Either"
    | Proof ->
        "Proof"
    | Signature ->
        "Signature"
    | Impossible ->
        "Impossible"

  let of_string = function
    | "None" ->
        Stable.Latest.None
    | "Either" ->
        Either
    | "Proof" ->
        Proof
    | "Signature" ->
        Signature
    | "Impossible" ->
        Impossible
    | _ ->
        failwith "auth_required_of_string: unknown variant"

  (* The encoding is chosen so that it is easy to write this function

      let spec_eval t ~signature_verifies =
        let impossible = (constant t && not (signature_sufficient t)) in
        let result =
          not impossible &&
          ( (signature_verifies && signature_sufficient t)
            || not (signature_necessary t) )
        in
        { result; proof_must_verify= not (signature_sufficient t) } *)

  (* Here is the mapping between our type and the bits
       { constant: bool
       ; signature_necessary: bool
       ; signature_sufficient: bool
       }

       Not constant
        Signature not necessary
          Signature not sufficient
            Proof
          Signature sufficient
            Either
        Signature necessary
          Signature not sufficient
            Both
          Signature sufficient
            Signature

       Constant
        Signature not sufficient
          Impossible
        Signature sufficient
          None
  *)
  module Encoding = struct
    type 'bool t =
      { constant : 'bool
      ; signature_necessary : 'bool
      ; signature_sufficient : 'bool
      }
    [@@deriving hlist, fields]

    let to_input ~field_of_bool t =
      let [ x; y; z ] = to_hlist t in
      let bs = [| x; y; z |] in
      Random_oracle.Input.Chunked.packeds
        (Array.map bs ~f:(fun b -> (field_of_bool b, 1)))

    let map t ~f =
      { constant = f t.constant
      ; signature_necessary = f t.signature_necessary
      ; signature_sufficient = f t.signature_sufficient
      }

    let _ = map

    [%%ifdef consensus_mechanism]

    let if_ b ~then_:t ~else_:e =
      let open Pickles.Impls.Step in
      { constant = Boolean.if_ b ~then_:t.constant ~else_:e.constant
      ; signature_necessary =
          Boolean.if_ b ~then_:t.signature_necessary
            ~else_:e.signature_necessary
      ; signature_sufficient =
          Boolean.if_ b ~then_:t.signature_sufficient
            ~else_:e.signature_sufficient
      }

    [%%endif]
  end

  let encode : t -> bool Encoding.t = function
    | Impossible ->
        { constant = true
        ; signature_necessary = true
        ; signature_sufficient = false
        }
    | None ->
        { constant = true
        ; signature_necessary = false
        ; signature_sufficient = true
        }
    | Proof ->
        { constant = false
        ; signature_necessary = false
        ; signature_sufficient = false
        }
    | Signature ->
        { constant = false
        ; signature_necessary = true
        ; signature_sufficient = true
        }
    | Either ->
        { constant = false
        ; signature_necessary = false
        ; signature_sufficient = true
        }

  let decode : bool Encoding.t -> t = function
    | { constant = true; signature_necessary = _; signature_sufficient = false }
      ->
        Impossible
    | { constant = true; signature_necessary = _; signature_sufficient = true }
      ->
        None
    | { constant = false
      ; signature_necessary = false
      ; signature_sufficient = false
      } ->
        Proof
    | { constant = false
      ; signature_necessary = true
      ; signature_sufficient = true
      } ->
        Signature
    | { constant = false
      ; signature_necessary = false
      ; signature_sufficient = true
      } ->
        Either
    | { constant = false
      ; signature_necessary = true
      ; signature_sufficient = false
      } ->
        failwith
          "Permissions.decode: Found encoding of Both, but Both is not an \
           exposed option"

  let%test_unit "decode encode" =
    List.iter [ Impossible; Proof; Signature; Either ] ~f:(fun t ->
        [%test_eq: t] t (decode (encode t)) )

  [%%ifdef consensus_mechanism]

  module Checked = struct
    type t = Boolean.var Encoding.t

    let if_ = Encoding.if_

    let to_input : t -> _ =
      Encoding.to_input ~field_of_bool:(fun (b : Boolean.var) ->
          (b :> Field.Var.t) )

    let constant t = Encoding.map (encode t) ~f:Boolean.var_of_value

    let eval_no_proof
        ({ constant; signature_necessary = _; signature_sufficient } : t)
        ~signature_verifies =
      (* ways authorization can succeed when no proof is present:
         - None
           {constant= true; signature_necessary= _; signature_sufficient= true}
         - Either && signature_verifies
           {constant= false; signature_necessary= false; signature_sufficient= true}
         - Signature && signature_verifies
           {constant= false; signature_necessary= true; signature_sufficient= true}
      *)
      let open Pickles.Impls.Step.Boolean in
      signature_sufficient
      &&& (constant ||| ((not constant) &&& signature_verifies))

    let eval_proof ({ constant; signature_necessary; signature_sufficient } : t)
        =
      (* ways authorization can succeed if a proof is present:
         - None
           {constant= true; signature_necessary= _; signature_sufficient= true}
         - Either
           {constant= false; signature_necessary= false; signature_sufficient= true}
         - Proof
           {constant= false; signature_necessary= false; signature_sufficient= false}
      *)
      let open Pickles.Impls.Step.Boolean in
      let impossible = constant &&& not signature_sufficient in
      (not signature_necessary) &&& not impossible

    let spec_eval ({ constant; signature_necessary; signature_sufficient } : t)
        ~signature_verifies =
      let open Pickles.Impls.Step.Boolean in
      let impossible = constant &&& not signature_sufficient in
      let result =
        (not impossible)
        &&& ( signature_verifies &&& signature_sufficient
            ||| not signature_necessary )
      in
      let didn't_fail_yet = result in
      (* If the transaction already failed to verify, we don't need to assert
         that the proof should verify. *)
      (result, `proof_must_verify (didn't_fail_yet &&& not signature_sufficient))

    let verification_key_perm_fallback_to_signature_with_older_version
        ({ signature_sufficient; _ } as t : t) =
      if_
        Pickles.Impls.Step.Boolean.(not signature_sufficient)
        ~then_:(constant Signature) ~else_:t
  end

  let typ =
    let t =
      let open Encoding in
      Typ.of_hlistable
        [ Boolean.typ; Boolean.typ; Boolean.typ ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
    in
    Typ.transport t ~there:encode ~back:decode

  [%%endif]

  let to_input x = Encoding.to_input (encode x) ~field_of_bool

  let check (t : t) (c : Control.Tag.t) =
    match (t, c) with
    | Impossible, _ ->
        false
    | None, _ ->
        true
    | Proof, Proof ->
        true
    | Signature, Signature ->
        true
    (* The signatures and proofs have already been checked by this point. *)
    | Either, (Proof | Signature) ->
        true
    | Signature, Proof ->
        false
    | Proof, Signature ->
        false
    | (Proof | Signature | Either), None_given ->
        false
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('controller, 'txn_version) t =
            ( 'controller
            , 'txn_version )
            Mina_wire_types.Mina_base.Permissions.Poly.V2.t =
        { edit_state : 'controller
        ; access : 'controller
        ; send : 'controller
        ; receive : 'controller
        ; set_delegate : 'controller
        ; set_permissions : 'controller
        ; set_verification_key : 'controller * 'txn_version
        ; set_zkapp_uri : 'controller
        ; edit_action_state : 'controller
        ; set_token_symbol : 'controller
        ; increment_nonce : 'controller
        ; set_voting_for : 'controller
        ; set_timing : 'controller
        }
      [@@deriving annot, sexp, equal, compare, hash, yojson, hlist, fields]
    end
  end]

  let to_input controller txn_version t =
    let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
    Stable.Latest.Fields.fold ~init:[] ~edit_state:(f controller)
      ~send:(f controller) ~set_delegate:(f controller)
      ~set_permissions:(f controller)
      ~set_verification_key:
        (f (fun (c, v) ->
             Random_oracle.Input.Chunked.append (controller c) (txn_version v) )
        )
      ~receive:(f controller) ~set_zkapp_uri:(f controller)
      ~edit_action_state:(f controller) ~set_token_symbol:(f controller)
      ~increment_nonce:(f controller) ~set_voting_for:(f controller)
      ~set_timing:(f controller) ~access:(f controller)
    |> List.rev
    |> List.reduce_exn ~f:Random_oracle.Input.Chunked.append
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      ( Auth_required.Stable.V2.t
      , Mina_numbers.Txn_version.Stable.V1.t )
      Poly.Stable.V2.t
    [@@deriving sexp, equal, compare, hash, yojson]

    let to_latest = Fn.id
  end
end]

let gen ~auth_tag : t Quickcheck.Generator.t =
  let auth_required_gen =
    (* for Auth_required permissions p, choose such that [check p authorization] is true *)
    match auth_tag with
    | Control.Tag.Proof ->
        Auth_required.gen_for_proof_authorization
    | Signature ->
        Auth_required.gen_for_signature_authorization
    | None_given ->
        Auth_required.gen_for_none_given_authorization
  in
  let open Quickcheck.Generator.Let_syntax in
  let%bind edit_state = auth_required_gen in
  let%bind send = auth_required_gen in
  let%bind receive = auth_required_gen in
  let%bind set_delegate = auth_required_gen in
  let%bind set_permissions = auth_required_gen in
  let%bind set_verification_key_auth = auth_required_gen in
  let txn_version =
    Mina_numbers.Txn_version.of_int @@ Protocol_version.(transaction current)
  in
  let%bind set_zkapp_uri = auth_required_gen in
  let%bind edit_action_state = auth_required_gen in
  let%bind set_token_symbol = auth_required_gen in
  let%bind increment_nonce = auth_required_gen in
  let%bind set_voting_for = auth_required_gen in
  let%bind set_timing = auth_required_gen in
  let%bind access =
    (* Access permission is significantly more restrictive, do not arbitrarily
       set it when tests may not be intending to exercise it.
    *)
    Auth_required.gen_for_none_given_authorization
  in
  return
    { Poly.edit_state
    ; send
    ; receive
    ; set_delegate
    ; set_permissions
    ; set_verification_key = (set_verification_key_auth, txn_version)
    ; set_zkapp_uri
    ; edit_action_state
    ; set_token_symbol
    ; increment_nonce
    ; set_voting_for
    ; set_timing
    ; access
    }

[%%ifdef consensus_mechanism]

module Checked = struct
  type t =
    ( Auth_required.Checked.t
    , Mina_numbers.Txn_version.Checked.t )
    Poly.Stable.Latest.t

  let to_input (x : t) =
    Poly.to_input Auth_required.Checked.to_input
      Mina_numbers.Txn_version.Checked.to_input x

  let if_ b ~(then_ : t) ~(else_ : t) : t Snark_params.Tick.Checked.t =
    let open Snark_params.Tick in
    let edit_state =
      Auth_required.Checked.if_ b ~then_:then_.edit_state
        ~else_:else_.edit_state
    in
    let send =
      Auth_required.Checked.if_ b ~then_:then_.send ~else_:else_.send
    in
    let receive =
      Auth_required.Checked.if_ b ~then_:then_.receive ~else_:else_.receive
    in
    let set_delegate =
      Auth_required.Checked.if_ b ~then_:then_.set_delegate
        ~else_:else_.set_delegate
    in
    let set_permissions =
      Auth_required.Checked.if_ b ~then_:then_.set_permissions
        ~else_:else_.set_permissions
    in
    let set_verification_key_auth =
      Auth_required.Checked.if_ b
        ~then_:(fst then_.set_verification_key)
        ~else_:(fst else_.set_verification_key)
    in
    let%map txn_version =
      Mina_numbers.Txn_version.Checked.if_ b
        ~then_:(snd then_.set_verification_key)
        ~else_:(snd else_.set_verification_key)
    in
    let set_zkapp_uri =
      Auth_required.Checked.if_ b ~then_:then_.set_zkapp_uri
        ~else_:else_.set_zkapp_uri
    in
    let edit_action_state =
      Auth_required.Checked.if_ b ~then_:then_.edit_action_state
        ~else_:else_.edit_action_state
    in
    let set_token_symbol =
      Auth_required.Checked.if_ b ~then_:then_.set_token_symbol
        ~else_:else_.set_token_symbol
    in
    let increment_nonce =
      Auth_required.Checked.if_ b ~then_:then_.increment_nonce
        ~else_:else_.increment_nonce
    in
    let set_voting_for =
      Auth_required.Checked.if_ b ~then_:then_.set_voting_for
        ~else_:else_.set_voting_for
    in
    let set_timing =
      Auth_required.Checked.if_ b ~then_:then_.set_timing
        ~else_:else_.set_timing
    in
    let access =
      Auth_required.Checked.if_ b ~then_:then_.access ~else_:else_.access
    in
    { Poly.edit_state
    ; send
    ; receive
    ; set_delegate
    ; set_permissions
    ; set_verification_key = (set_verification_key_auth, txn_version)
    ; set_zkapp_uri
    ; edit_action_state
    ; set_token_symbol
    ; increment_nonce
    ; set_voting_for
    ; set_timing
    ; access
    }

  let constant (t : Stable.Latest.t) : t =
    let open Core_kernel.Field in
    let a f = Auth_required.Checked.constant (get f t) in
    Poly.Fields.map ~edit_state:a ~send:a ~receive:a ~set_delegate:a
      ~set_permissions:a
      ~set_verification_key:(fun f ->
        let auth, txn_version = get f t in
        ( Auth_required.Checked.constant auth
        , Mina_numbers.Txn_version.Checked.constant txn_version ) )
      ~set_zkapp_uri:a ~edit_action_state:a ~set_token_symbol:a
      ~increment_nonce:a ~set_voting_for:a ~set_timing:a ~access:a
end

let typ =
  let open Poly.Stable.Latest in
  Typ.of_hlistable
    [ Auth_required.typ
    ; Auth_required.typ
    ; Auth_required.typ
    ; Auth_required.typ
    ; Auth_required.typ
    ; Auth_required.typ
    ; Typ.tuple2 Auth_required.typ Mina_numbers.Txn_version.typ
    ; Auth_required.typ
    ; Auth_required.typ
    ; Auth_required.typ
    ; Auth_required.typ
    ; Auth_required.typ
    ; Auth_required.typ
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

[%%endif]

let to_input (x : t) =
  Poly.to_input Auth_required.to_input Mina_numbers.Txn_version.to_input x

let user_default : t =
  { edit_state = Signature
  ; send = Signature
  ; receive = None
  ; set_delegate = Signature
  ; set_permissions = Signature
  ; set_verification_key = (Signature, Mina_numbers.Txn_version.current)
  ; set_zkapp_uri = Signature
  ; edit_action_state = Signature
  ; set_token_symbol = Signature
  ; increment_nonce = Signature
  ; set_voting_for = Signature
  ; set_timing = Signature
  ; access = None
  }

let empty : t =
  { edit_state = None
  ; send = None
  ; receive = None
  ; access = None
  ; set_delegate = None
  ; set_permissions = None
  ; set_verification_key = (None, Mina_numbers.Txn_version.current)
  ; set_zkapp_uri = None
  ; edit_action_state = None
  ; set_token_symbol = None
  ; increment_nonce = None
  ; set_voting_for = None
  ; set_timing = None
  }

(* deriving-fields-related stuff *)

let auth_required =
  Fields_derivers_zkapps.Derivers.iso_string ~name:"AuthRequired"
    ~js_type:(Custom "AuthRequired") ~doc:"Kind of authorization required"
    ~to_string:Auth_required.to_string ~of_string:Auth_required.of_string

module As_record = struct
  type t = { auth : Auth_required.t; txn_version : Mina_numbers.Txn_version.t }
  [@@deriving fields, annot]

  let deriver obj =
    let open Fields_derivers_zkapps.Derivers in
    let ( !. ) = ( !. ) ~t_fields_annots in
    let transaction_version =
      needs_custom_js ~js_type:uint32 ~name:"TransactionVersion" uint32
    in
    Fields.make_creator obj ~auth:!.auth_required
      ~txn_version:!.transaction_version
    |> finish "VerificationKeyPermission" ~t_toplevel_annots
end

let to_record (auth, txn_version) = { As_record.auth; txn_version }

let of_record { As_record.auth; txn_version } = (auth, txn_version)

let deriver obj =
  let open Fields_derivers_zkapps.Derivers in
  let ( !. ) = ( !. ) ~t_fields_annots:Poly.t_fields_annots in
  Poly.Fields.make_creator obj ~edit_state:!.auth_required ~send:!.auth_required
    ~receive:!.auth_required ~set_delegate:!.auth_required
    ~set_permissions:!.auth_required
    ~set_verification_key:!.(iso_record ~to_record ~of_record As_record.deriver)
    ~set_zkapp_uri:!.auth_required ~edit_action_state:!.auth_required
    ~set_token_symbol:!.auth_required ~increment_nonce:!.auth_required
    ~set_voting_for:!.auth_required ~set_timing:!.auth_required
    ~access:!.auth_required
  |> finish "Permissions" ~t_toplevel_annots:Poly.t_toplevel_annots

let%test_unit "json roundtrip" =
  let open Fields_derivers_zkapps.Derivers in
  let full = o () in
  let _a = deriver full in
  [%test_eq: t] user_default (user_default |> to_json full |> of_json full)

let%test_unit "json value" =
  let open Fields_derivers_zkapps.Derivers in
  let full = o () in
  let _a = deriver full in
  [%test_eq: string]
    (user_default |> to_json full |> Yojson.Safe.to_string)
    ( {json|{
        editState: "Signature",
        access: "None",
        send: "Signature",
        receive: "None",
        setDelegate: "Signature",
        setPermissions: "Signature",
        setVerificationKey: {
          auth: "Signature",
          txnVersion: "3"
          },
        setZkappUri: "Signature",
        editActionState: "Signature",
        setTokenSymbol: "Signature",
        incrementNonce: "Signature",
        setVotingFor: "Signature",
        setTiming: "Signature"
      }|json}
    |> Yojson.Safe.from_string |> Yojson.Safe.to_string )
