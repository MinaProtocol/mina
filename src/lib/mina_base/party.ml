[%%import "/src/config.mlh"]

open Core_kernel
open Mina_base_util

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%endif]

open Signature_lib
module Impl = Pickles.Impls.Step
open Mina_numbers
open Currency
open Pickles_types
module Digest = Random_oracle.Digest

module type Type = sig
  type t
end

module Call_type = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Call | Delegate_call
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let gen =
    Quickcheck.Generator.(map bool) ~f:(function
      | true ->
          Call
      | false ->
          Delegate_call )

  let to_string = function Call -> "call" | Delegate_call -> "delegate_call"

  let of_string = function
    | "call" ->
        Call
    | "delegate_call" ->
        Delegate_call
    | s ->
        failwithf "Invalid call type: %s" s ()

  let quickcheck_generator =
    Quickcheck.Generator.map Bool.quickcheck_generator ~f:(function
      | false ->
          Call
      | true ->
          Delegate_call )
end

module Update = struct
  module Timing_info = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { initial_minimum_balance : Balance.Stable.V1.t
          ; cliff_time : Global_slot.Stable.V1.t
          ; cliff_amount : Amount.Stable.V1.t
          ; vesting_period : Global_slot.Stable.V1.t
          ; vesting_increment : Amount.Stable.V1.t
          }
        [@@deriving annot, compare, equal, sexp, hash, yojson, hlist, fields]

        let to_latest = Fn.id
      end
    end]

    type value = t

    let gen =
      let open Quickcheck.Let_syntax in
      let%bind initial_minimum_balance = Balance.gen in
      let%bind cliff_time = Global_slot.gen in
      let%bind cliff_amount =
        Amount.gen_incl Amount.zero (Balance.to_amount initial_minimum_balance)
      in
      let%bind vesting_period =
        Global_slot.gen_incl Global_slot.(succ zero) (Global_slot.of_int 10)
      in
      let%map vesting_increment =
        Amount.gen_incl Amount.one (Amount.of_int 100)
      in
      { initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment
      }

    let to_input (t : t) =
      List.reduce_exn ~f:Random_oracle_input.Chunked.append
        [ Balance.to_input t.initial_minimum_balance
        ; Global_slot.to_input t.cliff_time
        ; Amount.to_input t.cliff_amount
        ; Global_slot.to_input t.vesting_period
        ; Amount.to_input t.vesting_increment
        ]

    let dummy =
      let slot_unused = Global_slot.zero in
      let balance_unused = Balance.zero in
      let amount_unused = Amount.zero in
      { initial_minimum_balance = balance_unused
      ; cliff_time = slot_unused
      ; cliff_amount = amount_unused
      ; vesting_period = slot_unused
      ; vesting_increment = amount_unused
      }

    let to_account_timing (t : t) : Account_timing.t =
      Timed
        { initial_minimum_balance = t.initial_minimum_balance
        ; cliff_time = t.cliff_time
        ; cliff_amount = t.cliff_amount
        ; vesting_period = t.vesting_period
        ; vesting_increment = t.vesting_increment
        }

    let of_account_timing (t : Account_timing.t) : t option =
      match t with
      | Untimed ->
          None
      | Timed t ->
          Some
            { initial_minimum_balance = t.initial_minimum_balance
            ; cliff_time = t.cliff_time
            ; cliff_amount = t.cliff_amount
            ; vesting_period = t.vesting_period
            ; vesting_increment = t.vesting_increment
            }

    module Checked = struct
      type t =
        { initial_minimum_balance : Balance.Checked.t
        ; cliff_time : Global_slot.Checked.t
        ; cliff_amount : Amount.Checked.t
        ; vesting_period : Global_slot.Checked.t
        ; vesting_increment : Amount.Checked.t
        }
      [@@deriving hlist]

      let constant (t : value) : t =
        { initial_minimum_balance = Balance.var_of_t t.initial_minimum_balance
        ; cliff_time = Global_slot.Checked.constant t.cliff_time
        ; cliff_amount = Amount.var_of_t t.cliff_amount
        ; vesting_period = Global_slot.Checked.constant t.vesting_period
        ; vesting_increment = Amount.var_of_t t.vesting_increment
        }

      let to_input
          ({ initial_minimum_balance
           ; cliff_time
           ; cliff_amount
           ; vesting_period
           ; vesting_increment
           } :
            t ) =
        List.reduce_exn ~f:Random_oracle_input.Chunked.append
          [ Balance.var_to_input initial_minimum_balance
          ; Global_slot.Checked.to_input cliff_time
          ; Amount.var_to_input cliff_amount
          ; Global_slot.Checked.to_input vesting_period
          ; Amount.var_to_input vesting_increment
          ]

      let to_account_timing (t : t) : Account_timing.var =
        { is_timed = Boolean.true_
        ; initial_minimum_balance = t.initial_minimum_balance
        ; cliff_time = t.cliff_time
        ; cliff_amount = t.cliff_amount
        ; vesting_period = t.vesting_period
        ; vesting_increment = t.vesting_increment
        }

      let of_account_timing (t : Account_timing.var) : t =
        { initial_minimum_balance = t.initial_minimum_balance
        ; cliff_time = t.cliff_time
        ; cliff_amount = t.cliff_amount
        ; vesting_period = t.vesting_period
        ; vesting_increment = t.vesting_increment
        }
    end

    let typ : (Checked.t, t) Typ.t =
      Typ.of_hlistable
        [ Balance.typ
        ; Global_slot.typ
        ; Amount.typ
        ; Global_slot.typ
        ; Amount.typ
        ]
        ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

    let deriver obj =
      let open Fields_derivers_zkapps.Derivers in
      let ( !. ) = ( !. ) ~t_fields_annots in
      Fields.make_creator obj ~initial_minimum_balance:!.balance
        ~cliff_time:!.global_slot ~cliff_amount:!.amount
        ~vesting_period:!.global_slot ~vesting_increment:!.amount
      |> finish "Timing" ~t_toplevel_annots
  end

  open Zkapp_basic

  [%%versioned
  module Stable = struct
    module V1 = struct
      (* TODO: Have to check that the public key is not = Public_key.Compressed.empty here.  *)
      type t =
        { app_state :
            F.Stable.V1.t Set_or_keep.Stable.V1.t Zkapp_state.V.Stable.V1.t
        ; delegate : Public_key.Compressed.Stable.V1.t Set_or_keep.Stable.V1.t
        ; verification_key :
            ( Pickles.Side_loaded.Verification_key.Stable.V2.t
            , F.Stable.V1.t )
            With_hash.Stable.V1.t
            Set_or_keep.Stable.V1.t
        ; permissions : Permissions.Stable.V2.t Set_or_keep.Stable.V1.t
        ; zkapp_uri : string Set_or_keep.Stable.V1.t
        ; token_symbol :
            Account.Token_symbol.Stable.V1.t Set_or_keep.Stable.V1.t
        ; timing : Timing_info.Stable.V1.t Set_or_keep.Stable.V1.t
        ; voting_for : State_hash.Stable.V1.t Set_or_keep.Stable.V1.t
        }
      [@@deriving annot, compare, equal, sexp, hash, yojson, fields, hlist]

      let to_latest = Fn.id
    end
  end]

  let gen ?(zkapp_account = false) ?vk ?permissions_auth () :
      t Quickcheck.Generator.t =
    let open Quickcheck.Let_syntax in
    let%bind app_state =
      let%bind fields =
        let field_gen = Snark_params.Tick.Field.gen in
        Quickcheck.Generator.list_with_length 8 (Set_or_keep.gen field_gen)
      in
      (* won't raise because length is correct *)
      Quickcheck.Generator.return (Zkapp_state.V.of_list_exn fields)
    in
    let%bind delegate = Set_or_keep.gen Public_key.Compressed.gen in
    let%bind verification_key =
      if zkapp_account then
        Set_or_keep.gen
          (Quickcheck.Generator.return
             ( match vk with
             | None ->
                 let data = Pickles.Side_loaded.Verification_key.dummy in
                 let hash = Zkapp_account.digest_vk data in
                 { With_hash.data; hash }
             | Some vk ->
                 vk ) )
      else return Set_or_keep.Keep
    in
    let%bind permissions =
      match permissions_auth with
      | None ->
          return Set_or_keep.Keep
      | Some auth_tag ->
          let%map permissions = Permissions.gen ~auth_tag in
          Set_or_keep.Set permissions
    in
    let%bind zkapp_uri =
      let uri_gen =
        Quickcheck.Generator.of_list
          [ "https://www.example.com"
          ; "https://www.minaprotocol.com"
          ; "https://www.gurgle.com"
          ; "https://faceplant.com"
          ]
      in
      Set_or_keep.gen uri_gen
    in
    let%bind token_symbol =
      let token_gen =
        Quickcheck.Generator.of_list
          [ "MINA"; "TOKEN1"; "TOKEN2"; "TOKEN3"; "TOKEN4"; "TOKEN5" ]
      in
      Set_or_keep.gen token_gen
    in
    let%bind voting_for = Set_or_keep.gen Field.gen in
    (* a new account for the Party.t is in the ledger when we use
       this generated update in tests, so the timing must be Keep
    *)
    let timing = Set_or_keep.Keep in
    return
      ( { app_state
        ; delegate
        ; verification_key
        ; permissions
        ; zkapp_uri
        ; token_symbol
        ; timing
        ; voting_for
        }
        : t )

  module Checked = struct
    open Pickles.Impls.Step

    type t =
      { app_state : Field.t Set_or_keep.Checked.t Zkapp_state.V.t
      ; delegate : Public_key.Compressed.var Set_or_keep.Checked.t
      ; verification_key :
          ( Boolean.var
          , ( Side_loaded_verification_key.t option
            , Field.Constant.t )
            With_hash.t
            Data_as_hash.t )
          Zkapp_basic.Flagged_option.t
          Set_or_keep.Checked.t
      ; permissions : Permissions.Checked.t Set_or_keep.Checked.t
      ; zkapp_uri : string Data_as_hash.t Set_or_keep.Checked.t
      ; token_symbol : Account.Token_symbol.var Set_or_keep.Checked.t
      ; timing : Timing_info.Checked.t Set_or_keep.Checked.t
      ; voting_for : State_hash.var Set_or_keep.Checked.t
      }
    [@@deriving hlist]

    let to_input
        ({ app_state
         ; delegate
         ; verification_key
         ; permissions
         ; zkapp_uri
         ; token_symbol
         ; timing
         ; voting_for
         } :
          t ) =
      let open Random_oracle_input.Chunked in
      List.reduce_exn ~f:append
        [ Zkapp_state.to_input app_state
            ~f:(Set_or_keep.Checked.to_input ~f:field)
        ; Set_or_keep.Checked.to_input delegate
            ~f:Public_key.Compressed.Checked.to_input
        ; Set_or_keep.Checked.to_input verification_key ~f:(fun x ->
              field (Data_as_hash.hash x.data) )
        ; Set_or_keep.Checked.to_input permissions
            ~f:Permissions.Checked.to_input
        ; Set_or_keep.Checked.to_input zkapp_uri ~f:Data_as_hash.to_input
        ; Set_or_keep.Checked.to_input token_symbol
            ~f:Account.Token_symbol.var_to_input
        ; Set_or_keep.Checked.to_input timing ~f:Timing_info.Checked.to_input
        ; Set_or_keep.Checked.to_input voting_for ~f:State_hash.var_to_input
        ]
  end

  let noop : t =
    { app_state =
        Vector.init Zkapp_state.Max_state_size.n ~f:(fun _ -> Set_or_keep.Keep)
    ; delegate = Keep
    ; verification_key = Keep
    ; permissions = Keep
    ; zkapp_uri = Keep
    ; token_symbol = Keep
    ; timing = Keep
    ; voting_for = Keep
    }

  let dummy = noop

  let to_input
      ({ app_state
       ; delegate
       ; verification_key
       ; permissions
       ; zkapp_uri
       ; token_symbol
       ; timing
       ; voting_for
       } :
        t ) =
    let open Random_oracle_input.Chunked in
    List.reduce_exn ~f:append
      [ Zkapp_state.to_input app_state
          ~f:(Set_or_keep.to_input ~dummy:Field.zero ~f:field)
      ; Set_or_keep.to_input delegate
          ~dummy:(Zkapp_precondition.Eq_data.Tc.public_key ()).default
          ~f:Public_key.Compressed.to_input
      ; Set_or_keep.to_input
          (Set_or_keep.map verification_key ~f:With_hash.hash)
          ~dummy:Field.zero ~f:field
      ; Set_or_keep.to_input permissions ~dummy:Permissions.user_default
          ~f:Permissions.to_input
      ; Set_or_keep.to_input
          (Set_or_keep.map ~f:Account.hash_zkapp_uri zkapp_uri)
          ~dummy:(Account.hash_zkapp_uri_opt None)
          ~f:field
      ; Set_or_keep.to_input token_symbol ~dummy:Account.Token_symbol.default
          ~f:Account.Token_symbol.to_input
      ; Set_or_keep.to_input timing ~dummy:Timing_info.dummy
          ~f:Timing_info.to_input
      ; Set_or_keep.to_input voting_for ~dummy:State_hash.dummy
          ~f:State_hash.to_input
      ]

  let typ () : (Checked.t, t) Typ.t =
    let open Pickles.Impls.Step in
    Typ.of_hlistable
      [ Zkapp_state.typ (Set_or_keep.typ ~dummy:Field.Constant.zero Field.typ)
      ; Set_or_keep.typ ~dummy:Public_key.Compressed.empty
          Public_key.Compressed.typ
      ; Set_or_keep.optional_typ
          (Data_as_hash.typ ~hash:With_hash.hash)
          ~to_option:(function
            | { With_hash.data = Some data; hash } ->
                Some { With_hash.data; hash }
            | { With_hash.data = None; _ } ->
                None )
          ~of_option:(function
            | Some { With_hash.data; hash } ->
                { With_hash.data = Some data; hash }
            | None ->
                { With_hash.data = None; hash = Field.Constant.zero } )
        |> Typ.transport_var
             ~there:
               (Set_or_keep.Checked.map
                  ~f:(fun { Zkapp_basic.Flagged_option.data; _ } -> data) )
             ~back:(fun x ->
               Set_or_keep.Checked.map x ~f:(fun data ->
                   { Zkapp_basic.Flagged_option.data
                   ; is_some = Set_or_keep.Checked.is_set x
                   } ) )
      ; Set_or_keep.typ ~dummy:Permissions.user_default Permissions.typ
      ; Set_or_keep.optional_typ
          (Data_as_hash.optional_typ ~hash:Account.hash_zkapp_uri
             ~non_preimage:(Account.hash_zkapp_uri_opt None)
             ~dummy_value:"" )
          ~to_option:Fn.id ~of_option:Fn.id
      ; Set_or_keep.typ ~dummy:Account.Token_symbol.default
          Account.Token_symbol.typ
      ; Set_or_keep.typ ~dummy:Timing_info.dummy Timing_info.typ
      ; Set_or_keep.typ ~dummy:State_hash.dummy State_hash.typ
      ]
      ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let deriver obj =
    let open Fields_derivers_zkapps in
    let ( !. ) = ( !. ) ~t_fields_annots in
    let string_with_hash =
      with_checked
        ~checked:(Data_as_hash.deriver string)
        ~name:"StringWithHash" string
    in
    finish "PartyUpdate" ~t_toplevel_annots
    @@ Fields.make_creator
         ~app_state:!.(Zkapp_state.deriver @@ Set_or_keep.deriver field)
         ~delegate:!.(Set_or_keep.deriver public_key)
         ~verification_key:!.(Set_or_keep.deriver verification_key_with_hash)
         ~permissions:!.(Set_or_keep.deriver Permissions.deriver)
         ~zkapp_uri:!.(Set_or_keep.deriver string_with_hash)
         ~token_symbol:!.(Set_or_keep.deriver string_with_hash)
         ~timing:!.(Set_or_keep.deriver Timing_info.deriver)
         ~voting_for:!.(Set_or_keep.deriver State_hash.deriver)
         obj

  let%test_unit "json roundtrip" =
    let app_state =
      Zkapp_state.V.of_list_exn
        Set_or_keep.
          [ Set (F.negate F.one); Keep; Keep; Keep; Keep; Keep; Keep; Keep ]
    in
    let verification_key =
      Set_or_keep.Set
        (let data =
           Pickles.Side_loaded.Verification_key.(
             dummy |> to_base58_check |> of_base58_check_exn)
         in
         let hash = Zkapp_account.digest_vk data in
         { With_hash.data; hash } )
    in
    let update : t =
      { app_state
      ; delegate = Set_or_keep.Set Public_key.Compressed.empty
      ; verification_key
      ; permissions = Set_or_keep.Set Permissions.user_default
      ; zkapp_uri = Set_or_keep.Set "https://www.example.com"
      ; token_symbol = Set_or_keep.Set "TOKEN"
      ; timing = Set_or_keep.Set Timing_info.dummy
      ; voting_for = Set_or_keep.Set State_hash.dummy
      }
    in
    let module Fd = Fields_derivers_zkapps.Derivers in
    let full = deriver (Fd.o ()) in
    [%test_eq: t] update (update |> Fd.to_json full |> Fd.of_json full)
end

module Events = Zkapp_account.Events
module Sequence_events = Zkapp_account.Sequence_events

module Account_precondition = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Full of Zkapp_precondition.Account.Stable.V2.t
        | Nonce of Account.Nonce.Stable.V1.t
        | Accept
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let gen : t Quickcheck.Generator.t =
    Quickcheck.Generator.variant3 Zkapp_precondition.Account.gen
      Account.Nonce.gen Unit.quickcheck_generator
    |> Quickcheck.Generator.map ~f:(function
         | `A x ->
             Full x
         | `B x ->
             Nonce x
         | `C () ->
             Accept )

  let to_full = function
    | Full s ->
        s
    | Nonce n ->
        { Zkapp_precondition.Account.accept with
          nonce = Check { lower = n; upper = n }
        }
    | Accept ->
        Zkapp_precondition.Account.accept

  let of_full (p : Zkapp_precondition.Account.t) =
    let module A = Zkapp_precondition.Account in
    if A.equal p A.accept then Accept
    else
      match p.nonce with
      | Ignore ->
          Full p
      | Check { lower; upper } as n ->
          if
            A.equal p { A.accept with nonce = n }
            && Account.Nonce.equal lower upper
          then Nonce lower
          else Full p

  module Tag = struct
    type t = Full | Nonce | Accept [@@deriving equal, compare, sexp, yojson]
  end

  let tag : t -> Tag.t = function
    | Full _ ->
        Full
    | Nonce _ ->
        Nonce
    | Accept ->
        Accept

  let deriver obj =
    let open Fields_derivers_zkapps.Derivers in
    iso_record ~of_record:of_full ~to_record:to_full
      Zkapp_precondition.Account.deriver obj

  let%test_unit "json roundtrip accept" =
    let account_precondition : t = Accept in
    let module Fd = Fields_derivers_zkapps.Derivers in
    let full = deriver (Fd.o ()) in
    [%test_eq: t] account_precondition
      (account_precondition |> Fd.to_json full |> Fd.of_json full)

  let%test_unit "json roundtrip nonce" =
    let account_precondition : t = Nonce (Account_nonce.of_int 928472) in
    let module Fd = Fields_derivers_zkapps.Derivers in
    let full = deriver (Fd.o ()) in
    [%test_eq: t] account_precondition
      (account_precondition |> Fd.to_json full |> Fd.of_json full)

  let%test_unit "json roundtrip full" =
    let n = Account_nonce.of_int 4513 in
    let account_precondition : t =
      Full
        { Zkapp_precondition.Account.accept with
          nonce = Check { lower = n; upper = n }
        ; delegate = Check Public_key.Compressed.empty
        }
    in
    let module Fd = Fields_derivers_zkapps.Derivers in
    let full = deriver (Fd.o ()) in
    [%test_eq: t] account_precondition
      (account_precondition |> Fd.to_json full |> Fd.of_json full)

  let%test_unit "to_json" =
    let account_precondition : t = Nonce (Account_nonce.of_int 34928) in
    let module Fd = Fields_derivers_zkapps.Derivers in
    let full = deriver (Fd.o ()) in
    [%test_eq: string]
      (account_precondition |> Fd.to_json full |> Yojson.Safe.to_string)
      ( {json|{
          balance: null,
          nonce: {lower: "34928", upper: "34928"},
          receiptChainHash: null, delegate: null,
          state: [null,null,null,null,null,null,null,null],
          sequenceState: null, provedState: null
        }|json}
      |> Yojson.Safe.from_string |> Yojson.Safe.to_string )

  let digest (t : t) =
    let digest x =
      Random_oracle.(
        hash ~init:Hash_prefix_states.party_account_precondition (pack_input x))
    in
    to_full t |> Zkapp_precondition.Account.to_input |> digest

  module Checked = struct
    type t = Zkapp_precondition.Account.Checked.t

    let digest (t : t) =
      let digest x =
        Random_oracle.Checked.(
          hash ~init:Hash_prefix_states.party_account_precondition
            (pack_input x))
      in
      Zkapp_precondition.Account.Checked.to_input t |> digest

    let nonce (t : t) = t.nonce
  end

  let typ () : (Zkapp_precondition.Account.Checked.t, t) Typ.t =
    Typ.transport (Zkapp_precondition.Account.typ ()) ~there:to_full
      ~back:(fun s -> Full s)

  let nonce = function
    | Full { nonce; _ } ->
        nonce
    | Nonce nonce ->
        Check { lower = nonce; upper = nonce }
    | Accept ->
        Ignore
end

module Body = struct
  (* Why isn't this derived automatically? *)
  let hash_fold_array f init x = Array.fold ~init ~f x

  module Events' = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Pickles.Backend.Tick.Field.Stable.V1.t array list
        [@@deriving sexp, equal, hash, compare, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Wire = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { public_key : Public_key.Compressed.Stable.V1.t
          ; token_id : Token_id.Stable.V1.t
          ; update : Update.Stable.V1.t
          ; balance_change :
              (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
          ; increment_nonce : bool
          ; events : Events'.Stable.V1.t
          ; sequence_events : Events'.Stable.V1.t
          ; call_data : Pickles.Backend.Tick.Field.Stable.V1.t
          ; protocol_state_precondition :
              Zkapp_precondition.Protocol_state.Stable.V1.t
          ; account_precondition : Account_precondition.Stable.V1.t
          ; use_full_commitment : bool
          ; caller : Call_type.Stable.V1.t
          }
        [@@deriving sexp, equal, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    let gen =
      let open Quickcheck.Generator.Let_syntax in
      let%map public_key = Public_key.Compressed.gen
      and token_id = Token_id.gen
      and update = Update.gen ()
      and balance_change = Currency.Amount.Signed.gen
      and increment_nonce = Quickcheck.Generator.bool
      and events = return []
      and sequence_events = return []
      and call_data = Field.gen
      and protocol_state_precondition = Zkapp_precondition.Protocol_state.gen
      and account_precondition = Account_precondition.gen
      and use_full_commitment = Quickcheck.Generator.bool
      and caller = Call_type.gen in
      { public_key
      ; token_id
      ; update
      ; balance_change
      ; increment_nonce
      ; events
      ; sequence_events
      ; call_data
      ; protocol_state_precondition
      ; account_precondition
      ; use_full_commitment
      ; caller
      }
  end

  module Graphql_repr = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { public_key : Public_key.Compressed.Stable.V1.t
          ; token_id : Token_id.Stable.V1.t
          ; update : Update.Stable.V1.t
          ; balance_change :
              (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
          ; increment_nonce : bool
          ; events : Events'.Stable.V1.t
          ; sequence_events : Events'.Stable.V1.t
          ; call_data : Pickles.Backend.Tick.Field.Stable.V1.t
          ; call_depth : int
          ; protocol_state_precondition :
              Zkapp_precondition.Protocol_state.Stable.V1.t
          ; account_precondition : Account_precondition.Stable.V1.t
          ; use_full_commitment : bool
          ; caller : Token_id.Stable.V1.t
          }
        [@@deriving annot, sexp, equal, yojson, hash, compare, fields]

        let to_latest = Fn.id
      end
    end]

    let deriver obj =
      let open Fields_derivers_zkapps in
      let ( !. ) = ( !. ) ~t_fields_annots in
      Fields.make_creator obj ~public_key:!.public_key ~update:!.Update.deriver
        ~token_id:!.Token_id.deriver ~balance_change:!.balance_change
        ~increment_nonce:!.bool ~events:!.Events.deriver
        ~sequence_events:!.Events.deriver ~call_data:!.field
        ~protocol_state_precondition:!.Zkapp_precondition.Protocol_state.deriver
        ~account_precondition:!.Account_precondition.deriver
        ~use_full_commitment:!.bool ~caller:!.Token_id.deriver ~call_depth:!.int
      |> finish "PartyBodyGraphql" ~t_toplevel_annots

    let dummy : t =
      { public_key = Public_key.Compressed.empty
      ; update = Update.dummy
      ; token_id = Token_id.default
      ; balance_change = Amount.Signed.zero
      ; increment_nonce = false
      ; events = []
      ; sequence_events = []
      ; call_data = Field.zero
      ; call_depth = 0
      ; protocol_state_precondition = Zkapp_precondition.Protocol_state.accept
      ; account_precondition = Account_precondition.Accept
      ; use_full_commitment = false
      ; caller = Token_id.default
      }
  end

  module Simple = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { public_key : Public_key.Compressed.Stable.V1.t
          ; token_id : Token_id.Stable.V1.t
          ; update : Update.Stable.V1.t
          ; balance_change :
              (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
          ; increment_nonce : bool
          ; events : Events'.Stable.V1.t
          ; sequence_events : Events'.Stable.V1.t
          ; call_data : Pickles.Backend.Tick.Field.Stable.V1.t
          ; call_depth : int
          ; protocol_state_precondition :
              Zkapp_precondition.Protocol_state.Stable.V1.t
          ; account_precondition : Account_precondition.Stable.V1.t
          ; use_full_commitment : bool
          ; caller : Call_type.Stable.V1.t
          }
        [@@deriving annot, sexp, equal, yojson, hash, compare, fields]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { public_key : Public_key.Compressed.Stable.V1.t
        ; token_id : Token_id.Stable.V1.t
        ; update : Update.Stable.V1.t
        ; balance_change :
            (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
        ; increment_nonce : bool
        ; events : Events'.Stable.V1.t
        ; sequence_events : Events'.Stable.V1.t
        ; call_data : Pickles.Backend.Tick.Field.Stable.V1.t
        ; protocol_state_precondition :
            Zkapp_precondition.Protocol_state.Stable.V1.t
        ; account_precondition : Account_precondition.Stable.V1.t
        ; use_full_commitment : bool
        ; caller : Token_id.Stable.V1.t
        }
      [@@deriving annot, sexp, equal, yojson, hash, hlist, compare, fields]

      let to_latest = Fn.id
    end
  end]

  let to_wire (p : t) caller : Wire.t =
    { public_key = p.public_key
    ; token_id = p.token_id
    ; update = p.update
    ; balance_change = p.balance_change
    ; increment_nonce = p.increment_nonce
    ; events = p.events
    ; sequence_events = p.sequence_events
    ; call_data = p.call_data
    ; protocol_state_precondition = p.protocol_state_precondition
    ; account_precondition = p.account_precondition
    ; use_full_commitment = p.use_full_commitment
    ; caller
    }

  (* * Balance change for the fee payer is always going to be Neg, so represent it using
       an unsigned fee,
     * token id is always going to be the default, so use unit value as a
       placeholder,
     * increment nonce must always be true for a fee payer, so use unit as a
       placeholder.
     TODO: what about use_full_commitment? it's unit here and bool there
  *)
  module Fee_payer = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { public_key : Public_key.Compressed.Stable.V1.t
          ; update : Update.Stable.V1.t
          ; fee : Fee.Stable.V1.t
          ; events : Events'.Stable.V1.t
          ; sequence_events : Events'.Stable.V1.t
          ; protocol_state_precondition :
              Zkapp_precondition.Protocol_state.Stable.V1.t
          ; nonce : Account_nonce.Stable.V1.t
          }
        [@@deriving annot, sexp, equal, yojson, hash, compare, hlist, fields]

        let to_latest = Fn.id
      end
    end]

    let gen : t Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%map public_key = Public_key.Compressed.gen
      and update = Update.gen ()
      and fee = Currency.Fee.gen
      and nonce = Account.Nonce.gen
      and events = return []
      and sequence_events = return []
      and protocol_state_precondition = Zkapp_precondition.Protocol_state.gen in
      { public_key
      ; update
      ; fee
      ; events
      ; sequence_events
      ; protocol_state_precondition
      ; nonce
      }

    let dummy : t =
      { public_key = Public_key.Compressed.empty
      ; update = Update.dummy
      ; fee = Fee.zero
      ; events = []
      ; sequence_events = []
      ; protocol_state_precondition = Zkapp_precondition.Protocol_state.accept
      ; nonce = Account_nonce.zero
      }

    let deriver obj =
      let open Fields_derivers_zkapps in
      let fee obj =
        iso_string obj ~name:"Fee" ~js_type:UInt64 ~to_string:Fee.to_string
          ~of_string:Fee.of_string
      in
      let ( !. ) ?skip_data = ( !. ) ?skip_data ~t_fields_annots in
      Fields.make_creator obj ~public_key:!.public_key ~update:!.Update.deriver
        ~fee:!.fee ~events:!.Events.deriver ~sequence_events:!.Events.deriver
        ~protocol_state_precondition:!.Zkapp_precondition.Protocol_state.deriver
        ~nonce:!.uint32
      |> finish "FeePayerPartyBody" ~t_toplevel_annots

    let%test_unit "json roundtrip" =
      let open Fields_derivers_zkapps.Derivers in
      let full = o () in
      let _a = deriver full in
      [%test_eq: t] dummy (dummy |> to_json full |> of_json full)
  end

  let of_fee_payer (t : Fee_payer.t) : t =
    { public_key = t.public_key
    ; token_id = Token_id.default
    ; update = t.update
    ; balance_change =
        { Signed_poly.sgn = Sgn.Neg; magnitude = Amount.of_fee t.fee }
    ; increment_nonce = true
    ; events = t.events
    ; sequence_events = t.sequence_events
    ; call_data = Field.zero
    ; protocol_state_precondition = t.protocol_state_precondition
    ; account_precondition = Account_precondition.Nonce t.nonce
    ; use_full_commitment = true
    ; caller = Token_id.default
    }

  let to_fee_payer_exn (t : t) : Fee_payer.t =
    let { public_key
        ; token_id = _
        ; update
        ; balance_change
        ; increment_nonce = _
        ; events
        ; sequence_events
        ; call_data = _
        ; protocol_state_precondition
        ; account_precondition
        ; use_full_commitment = _
        ; caller = _
        } =
      t
    in
    let fee =
      Currency.Fee.of_uint64
        (balance_change.magnitude |> Currency.Amount.to_uint64)
    in
    let nonce =
      match account_precondition with
      | Nonce nonce ->
          Mina_numbers.Account_nonce.of_uint32 nonce
      | Full _ | Accept ->
          failwith "Expected a nonce for fee payer account precondition"
    in
    { public_key
    ; update
    ; fee
    ; events
    ; sequence_events
    ; protocol_state_precondition
    ; nonce
    }

  module Checked = struct
    module Type_of_var (V : sig
      type var
    end) =
    struct
      type t = V.var
    end

    module Int_as_prover_ref = struct
      type t = int As_prover.Ref.t
    end

    type t =
      { public_key : Public_key.Compressed.var
      ; token_id : Token_id.Checked.t
      ; update : Update.Checked.t
      ; balance_change : Amount.Signed.var
      ; increment_nonce : Boolean.var
      ; events : Events.var
      ; sequence_events : Events.var
      ; call_data : Field.Var.t
      ; protocol_state_precondition :
          Zkapp_precondition.Protocol_state.Checked.t
      ; account_precondition : Account_precondition.Checked.t
      ; use_full_commitment : Boolean.var
      ; caller : Token_id.Checked.t
      }
    [@@deriving annot, hlist, fields]

    let to_input
        ({ public_key
         ; token_id
         ; update
         ; balance_change
         ; increment_nonce
         ; events
         ; sequence_events
         ; call_data
         ; protocol_state_precondition
         ; account_precondition
         ; use_full_commitment
         ; caller
         } :
          t ) =
      List.reduce_exn ~f:Random_oracle_input.Chunked.append
        [ Public_key.Compressed.Checked.to_input public_key
        ; Update.Checked.to_input update
        ; Token_id.Checked.to_input token_id
        ; Snark_params.Tick.Run.run_checked
            (Amount.Signed.Checked.to_input balance_change)
        ; Random_oracle_input.Chunked.packed
            ((increment_nonce :> Field.Var.t), 1)
        ; Events.var_to_input events
        ; Events.var_to_input sequence_events
        ; Random_oracle_input.Chunked.field call_data
        ; Zkapp_precondition.Protocol_state.Checked.to_input
            protocol_state_precondition
        ; Random_oracle_input.Chunked.field
            (Account_precondition.Checked.digest account_precondition)
        ; Random_oracle_input.Chunked.packed
            ((use_full_commitment :> Field.Var.t), 1)
        ; Token_id.Checked.to_input caller
        ]

    let digest (t : t) =
      Random_oracle.Checked.(
        hash ~init:Hash_prefix.zkapp_body (pack_input (to_input t)))
  end

  let typ () : (Checked.t, t) Typ.t =
    Typ.of_hlistable
      [ Public_key.Compressed.typ
      ; Token_id.typ
      ; Update.typ ()
      ; Amount.Signed.typ
      ; Boolean.typ
      ; Events.typ
      ; Events.typ
      ; Field.typ
      ; Zkapp_precondition.Protocol_state.typ
      ; Account_precondition.typ ()
      ; Impl.Boolean.typ
      ; Token_id.typ
      ]
      ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let dummy : t =
    { public_key = Public_key.Compressed.empty
    ; update = Update.dummy
    ; token_id = Token_id.default
    ; balance_change = Amount.Signed.zero
    ; increment_nonce = false
    ; events = []
    ; sequence_events = []
    ; call_data = Field.zero
    ; protocol_state_precondition = Zkapp_precondition.Protocol_state.accept
    ; account_precondition = Account_precondition.Accept
    ; use_full_commitment = false
    ; caller = Token_id.default
    }

  let deriver obj =
    let open Fields_derivers_zkapps in
    let ( !. ) = ( !. ) ~t_fields_annots in
    Fields.make_creator obj ~public_key:!.public_key ~update:!.Update.deriver
      ~token_id:!.Token_id.deriver ~balance_change:!.balance_change
      ~increment_nonce:!.bool ~events:!.Events.deriver
      ~sequence_events:!.Events.deriver ~call_data:!.field
      ~protocol_state_precondition:!.Zkapp_precondition.Protocol_state.deriver
      ~account_precondition:!.Account_precondition.deriver
      ~use_full_commitment:!.bool ~caller:!.Token_id.deriver
    |> finish "PartyBody" ~t_toplevel_annots

  let%test_unit "json roundtrip" =
    let open Fields_derivers_zkapps.Derivers in
    let full = o () in
    let _a = deriver full in
    [%test_eq: t] dummy (dummy |> to_json full |> of_json full)

  let to_input
      ({ public_key
       ; update
       ; token_id
       ; balance_change
       ; increment_nonce
       ; events
       ; sequence_events
       ; call_data
       ; protocol_state_precondition
       ; account_precondition
       ; use_full_commitment
       ; caller
       } :
        t ) =
    List.reduce_exn ~f:Random_oracle_input.Chunked.append
      [ Public_key.Compressed.to_input public_key
      ; Update.to_input update
      ; Token_id.to_input token_id
      ; Amount.Signed.to_input balance_change
      ; Random_oracle_input.Chunked.packed (field_of_bool increment_nonce, 1)
      ; Events.to_input events
      ; Events.to_input sequence_events
      ; Random_oracle_input.Chunked.field call_data
      ; Zkapp_precondition.Protocol_state.to_input protocol_state_precondition
      ; Random_oracle_input.Chunked.field
          (Account_precondition.digest account_precondition)
      ; Random_oracle_input.Chunked.packed (field_of_bool use_full_commitment, 1)
      ; Token_id.to_input caller
      ]

  let digest (t : t) =
    Random_oracle.(hash ~init:Hash_prefix.zkapp_body (pack_input (to_input t)))

  module Digested = struct
    type t = Random_oracle.Digest.t

    module Checked = struct
      type t = Random_oracle.Checked.Digest.t
    end
  end

  let gen caller =
    let open Quickcheck.Generator.Let_syntax in
    let%map public_key = Public_key.Compressed.gen
    and token_id = Token_id.gen
    and update = Update.gen ()
    and balance_change = Currency.Amount.Signed.gen
    and increment_nonce = Quickcheck.Generator.bool
    and events = return []
    and sequence_events = return []
    and call_data = Field.gen
    and protocol_state_precondition = Zkapp_precondition.Protocol_state.gen
    and account_precondition = Account_precondition.gen
    and use_full_commitment = Quickcheck.Generator.bool in
    { public_key
    ; token_id
    ; update
    ; balance_change
    ; increment_nonce
    ; events
    ; sequence_events
    ; call_data
    ; protocol_state_precondition
    ; account_precondition
    ; use_full_commitment
    ; caller
    }
end

module T = struct
  module Graphql_repr = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { body : Body.Graphql_repr.Stable.V1.t
          ; authorization : Control.Stable.V2.t
          }
        [@@deriving annot, sexp, equal, yojson, hash, compare, fields]

        let to_latest = Fn.id
      end
    end]

    let deriver obj =
      let open Fields_derivers_zkapps.Derivers in
      let ( !. ) = ( !. ) ~t_fields_annots in
      Fields.make_creator obj
        ~body:!.Body.Graphql_repr.deriver
        ~authorization:!.Control.deriver
      |> finish "ZkappParty" ~t_toplevel_annots
  end

  module Simple = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { body : Body.Simple.Stable.V1.t
          ; authorization : Control.Stable.V2.t
          }
        [@@deriving annot, sexp, equal, yojson, hash, compare, fields]

        let to_latest = Fn.id
      end
    end]
  end

  module Wire = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { body : Body.Wire.Stable.V1.t; authorization : Control.Stable.V2.t }
        [@@deriving sexp, equal, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    let gen : t Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%map body = Body.Wire.gen
      and authorization = Control.gen_with_dummies in
      { body; authorization }

    let quickcheck_generator : t Quickcheck.Generator.t = gen

    let quickcheck_obserber : t Quickcheck.Observer.t =
      Quickcheck.Observer.of_hash (module Stable.Latest)

    let quickcheck_shrinker : t Quickcheck.Shrinker.t =
      Quickcheck.Shrinker.empty ()
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      (** A party to a zkApp transaction *)
      type t = { body : Body.Stable.V1.t; authorization : Control.Stable.V2.t }
      [@@deriving annot, sexp, equal, yojson, hash, compare, fields]

      let to_latest = Fn.id
    end
  end]

  let of_graphql_repr
      ({ body =
           { public_key
           ; token_id
           ; update
           ; balance_change
           ; increment_nonce
           ; events
           ; sequence_events
           ; call_data
           ; protocol_state_precondition
           ; account_precondition
           ; use_full_commitment
           ; caller
           ; call_depth = _
           }
       ; authorization
       } :
        Graphql_repr.t ) : t =
    { authorization
    ; body =
        { Body.public_key
        ; token_id
        ; update
        ; balance_change
        ; increment_nonce
        ; events
        ; sequence_events
        ; call_data
        ; protocol_state_precondition
        ; account_precondition
        ; use_full_commitment
        ; caller
        }
    }

  let to_graphql_repr
      ({ body =
           { public_key
           ; token_id
           ; update
           ; balance_change
           ; increment_nonce
           ; events
           ; sequence_events
           ; call_data
           ; protocol_state_precondition
           ; account_precondition
           ; use_full_commitment
           ; caller
           }
       ; authorization
       } :
        t ) ~call_depth : Graphql_repr.t =
    { authorization
    ; body =
        { Body.Graphql_repr.public_key
        ; token_id
        ; update
        ; balance_change
        ; increment_nonce
        ; events
        ; sequence_events
        ; call_data
        ; protocol_state_precondition
        ; account_precondition
        ; use_full_commitment
        ; caller
        ; call_depth
        }
    }

  let gen caller : t Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%map body = Body.gen caller
    and authorization = Control.gen_with_dummies in
    { body; authorization }

  let to_wire (p : t) caller : Wire.t =
    { body = Body.to_wire p.body caller; authorization = p.authorization }

  let digest (t : t) = Body.digest t.body

  module Checked = struct
    type t = Body.Checked.t

    let digest (t : t) = Body.Checked.digest t
  end

  let deriver obj =
    let open Fields_derivers_zkapps.Derivers in
    let ( !. ) = ( !. ) ~t_fields_annots in
    Fields.make_creator obj ~body:!.Body.deriver
      ~authorization:!.Control.deriver
    |> finish "ZkappParty" ~t_toplevel_annots

  let%test_unit "json roundtrip dummy" =
    let dummy : t =
      { body = Body.dummy; authorization = Control.dummy_of_tag Signature }
    in
    let module Fd = Fields_derivers_zkapps.Derivers in
    let full = deriver @@ Fd.o () in
    [%test_eq: t] dummy (dummy |> Fd.to_json full |> Fd.of_json full)
end

module Fee_payer = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { body : Body.Fee_payer.Stable.V1.t
        ; authorization : Signature.Stable.V1.t
        }
      [@@deriving annot, sexp, equal, yojson, hash, compare, fields]

      let to_latest = Fn.id
    end
  end]

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Let_syntax in
    let%map body = Body.Fee_payer.gen in
    let authorization = Signature.dummy in
    { body; authorization }

  let quickcheck_generator : t Quickcheck.Generator.t = gen

  let quickcheck_obserber : t Quickcheck.Observer.t =
    Quickcheck.Observer.of_hash (module Stable.Latest)

  let quickcheck_shrinker : t Quickcheck.Shrinker.t =
    Quickcheck.Shrinker.empty ()

  let account_id (t : t) : Account_id.t =
    Account_id.create t.body.public_key Token_id.default

  let to_party (t : t) : T.t =
    { authorization = Control.Signature t.authorization
    ; body = Body.of_fee_payer t.body
    }

  let deriver obj =
    let open Fields_derivers_zkapps.Derivers in
    let ( !. ) = ( !. ) ~t_fields_annots in
    Fields.make_creator obj ~body:!.Body.Fee_payer.deriver
      ~authorization:!.Control.signature_deriver
    |> finish "ZkappPartyFeePayer" ~t_toplevel_annots

  let%test_unit "json roundtrip" =
    let dummy : t =
      { body = Body.Fee_payer.dummy; authorization = Signature.dummy }
    in
    let open Fields_derivers_zkapps.Derivers in
    let full = o () in
    let _a = deriver full in
    [%test_eq: t] dummy (dummy |> to_json full |> of_json full)
end

include T

let account_id (t : t) : Account_id.t =
  Account_id.create t.body.public_key t.body.token_id

let of_fee_payer ({ body; authorization } : Fee_payer.t) : t =
  { authorization = Signature authorization; body = Body.of_fee_payer body }

(** The change in balance to apply to the target account of this party.
      When this is negative, the amount will be withdrawn from the account and
      made available to later parties in the same transaction.
      When this is positive, the amount will be deposited into the account from
      the funds made available by previous parties in the same transaction.
*)
let balance_change (t : t) : Amount.Signed.t = t.body.balance_change

let protocol_state_precondition (t : t) : Zkapp_precondition.Protocol_state.t =
  t.body.protocol_state_precondition

let public_key (t : t) : Public_key.Compressed.t = t.body.public_key

let token_id (t : t) : Token_id.t = t.body.token_id

let use_full_commitment (t : t) : bool = t.body.use_full_commitment

let increment_nonce (t : t) : bool = t.body.increment_nonce
