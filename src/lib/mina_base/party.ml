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
        [@@deriving compare, equal, sexp, hash, yojson, hlist, fields]

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
            t) =
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
      let open Fields_derivers_snapps.Derivers in
      Fields.make_creator obj ~initial_minimum_balance:!.balance
        ~cliff_time:!.global_slot ~cliff_amount:!.amount
        ~vesting_period:!.global_slot ~vesting_increment:!.amount
      |> finish ~name:"Timing"
  end

  open Snapp_basic

  [%%versioned
  module Stable = struct
    module V1 = struct
      (* TODO: Have to check that the public key is not = Public_key.Compressed.empty here.  *)
      type t =
        { app_state :
            F.Stable.V1.t Set_or_keep.Stable.V1.t Snapp_state.V.Stable.V1.t
        ; delegate : Public_key.Compressed.Stable.V1.t Set_or_keep.Stable.V1.t
        ; verification_key :
            ( Pickles.Side_loaded.Verification_key.Stable.V2.t
            , F.Stable.V1.t )
            With_hash.Stable.V1.t
            Set_or_keep.Stable.V1.t
        ; permissions : Permissions.Stable.V2.t Set_or_keep.Stable.V1.t
        ; snapp_uri : string Set_or_keep.Stable.V1.t
        ; token_symbol :
            Account.Token_symbol.Stable.V1.t Set_or_keep.Stable.V1.t
        ; timing : Timing_info.Stable.V1.t Set_or_keep.Stable.V1.t
        ; voting_for : State_hash.Stable.V1.t Set_or_keep.Stable.V1.t
        }
      [@@deriving compare, equal, sexp, hash, yojson, fields, hlist]

      let to_latest = Fn.id
    end
  end]

  let gen ?(snapp_account = false) ?permissions_auth () :
      t Quickcheck.Generator.t =
    let open Quickcheck.Let_syntax in
    let%bind app_state =
      let%bind fields =
        let field_gen = Snark_params.Tick.Field.gen in
        Quickcheck.Generator.list_with_length 8 (Set_or_keep.gen field_gen)
      in
      (* won't raise because length is correct *)
      Quickcheck.Generator.return (Snapp_state.V.of_list_exn fields)
    in
    let%bind delegate = Set_or_keep.gen Public_key.Compressed.gen in
    let%bind verification_key =
      if snapp_account then
        Set_or_keep.gen
          (Quickcheck.Generator.return
             (let data = Pickles.Side_loaded.Verification_key.dummy in
              let hash = Snapp_account.digest_vk data in
              { With_hash.data; hash }))
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
    let%bind snapp_uri =
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
        ; snapp_uri
        ; token_symbol
        ; timing
        ; voting_for
        }
        : t )

  module Checked = struct
    open Pickles.Impls.Step

    type t =
      { app_state : Field.t Set_or_keep.Checked.t Snapp_state.V.t
      ; delegate : Public_key.Compressed.var Set_or_keep.Checked.t
      ; verification_key :
          ( Boolean.var
          , ( Side_loaded_verification_key.t option
            , Field.Constant.t )
            With_hash.t
            Data_as_hash.t )
          Snapp_basic.Flagged_option.t
          Set_or_keep.Checked.t
      ; permissions : Permissions.Checked.t Set_or_keep.Checked.t
      ; snapp_uri : string Data_as_hash.t Set_or_keep.Checked.t
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
         ; snapp_uri
         ; token_symbol
         ; timing
         ; voting_for
         } :
          t) =
      let open Random_oracle_input.Chunked in
      List.reduce_exn ~f:append
        [ Snapp_state.to_input app_state
            ~f:(Set_or_keep.Checked.to_input ~f:field)
        ; Set_or_keep.Checked.to_input delegate
            ~f:Public_key.Compressed.Checked.to_input
        ; Set_or_keep.Checked.to_input verification_key ~f:(fun x ->
              field (Data_as_hash.hash x.data))
        ; Set_or_keep.Checked.to_input permissions
            ~f:Permissions.Checked.to_input
        ; Set_or_keep.Checked.to_input snapp_uri ~f:Data_as_hash.to_input
        ; Set_or_keep.Checked.to_input token_symbol
            ~f:Account.Token_symbol.var_to_input
        ; Set_or_keep.Checked.to_input timing ~f:Timing_info.Checked.to_input
        ; Set_or_keep.Checked.to_input voting_for ~f:State_hash.var_to_input
        ]
  end

  let noop : t =
    { app_state =
        Vector.init Snapp_state.Max_state_size.n ~f:(fun _ -> Set_or_keep.Keep)
    ; delegate = Keep
    ; verification_key = Keep
    ; permissions = Keep
    ; snapp_uri = Keep
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
       ; snapp_uri
       ; token_symbol
       ; timing
       ; voting_for
       } :
        t) =
    let open Random_oracle_input.Chunked in
    List.reduce_exn ~f:append
      [ Snapp_state.to_input app_state
          ~f:(Set_or_keep.to_input ~dummy:Field.zero ~f:field)
      ; Set_or_keep.to_input delegate
          ~dummy:(Snapp_predicate.Eq_data.Tc.public_key ()).default
          ~f:Public_key.Compressed.to_input
      ; Set_or_keep.to_input
          (Set_or_keep.map verification_key ~f:With_hash.hash)
          ~dummy:Field.zero ~f:field
      ; Set_or_keep.to_input permissions ~dummy:Permissions.user_default
          ~f:Permissions.to_input
      ; Set_or_keep.to_input
          (Set_or_keep.map ~f:Account.hash_snapp_uri snapp_uri)
          ~dummy:(Account.hash_snapp_uri_opt None)
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
      [ Snapp_state.typ (Set_or_keep.typ ~dummy:Field.Constant.zero Field.typ)
      ; Set_or_keep.typ ~dummy:Public_key.Compressed.empty
          Public_key.Compressed.typ
      ; Set_or_keep.optional_typ
          (Data_as_hash.typ ~hash:With_hash.hash)
          ~to_option:(function
            | { With_hash.data = Some data; hash } ->
                Some { With_hash.data; hash }
            | { With_hash.data = None; _ } ->
                None)
          ~of_option:(function
            | Some { With_hash.data; hash } ->
                { With_hash.data = Some data; hash }
            | None ->
                { With_hash.data = None; hash = Field.Constant.zero })
        |> Typ.transport_var
             ~there:
               (Set_or_keep.Checked.map
                  ~f:(fun { Snapp_basic.Flagged_option.data; _ } -> data))
             ~back:(fun x ->
               Set_or_keep.Checked.map x ~f:(fun data ->
                   { Snapp_basic.Flagged_option.data
                   ; is_some = Set_or_keep.Checked.is_set x
                   }))
      ; Set_or_keep.typ ~dummy:Permissions.user_default Permissions.typ
      ; Set_or_keep.optional_typ
          (Data_as_hash.optional_typ ~hash:Account.hash_snapp_uri
             ~non_preimage:(Account.hash_snapp_uri_opt None)
             ~dummy_value:"")
          ~to_option:Fn.id ~of_option:Fn.id
      ; Set_or_keep.typ ~dummy:Account.Token_symbol.default
          Account.Token_symbol.typ
      ; Set_or_keep.typ ~dummy:Timing_info.dummy Timing_info.typ
      ; Set_or_keep.typ ~dummy:State_hash.dummy State_hash.typ
      ]
      ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let deriver obj =
    let open Fields_derivers_snapps in
    finish ~name:"PartyUpdate"
    @@ Fields.make_creator
         ~app_state:!.(Snapp_state.deriver @@ Set_or_keep.deriver field)
         ~delegate:!.(Set_or_keep.deriver public_key)
         ~verification_key:!.(Set_or_keep.deriver verification_key_with_hash)
         ~permissions:!.(Set_or_keep.deriver Permissions.deriver)
         ~snapp_uri:!.(Set_or_keep.deriver string)
         ~token_symbol:!.(Set_or_keep.deriver string)
         ~timing:!.(Set_or_keep.deriver Timing_info.deriver)
         ~voting_for:!.(Set_or_keep.deriver State_hash.deriver)
         obj

  let%test_unit "json roundtrip" =
    let app_state =
      Snapp_state.V.of_list_exn
        Set_or_keep.
          [ Set (F.negate F.one); Keep; Keep; Keep; Keep; Keep; Keep; Keep ]
    in
    let verification_key =
      Set_or_keep.Set
        (let data =
           Pickles.Side_loaded.Verification_key.(
             dummy |> to_base58_check |> of_base58_check_exn)
         in
         let hash = Snapp_account.digest_vk data in
         { With_hash.data; hash })
    in
    let update : t =
      { app_state
      ; delegate = Set_or_keep.Set Public_key.Compressed.empty
      ; verification_key
      ; permissions = Set_or_keep.Set Permissions.user_default
      ; snapp_uri = Set_or_keep.Set "https://www.example.com"
      ; token_symbol = Set_or_keep.Set "TOKEN"
      ; timing = Set_or_keep.Set Timing_info.dummy
      ; voting_for = Set_or_keep.Set State_hash.dummy
      }
    in
    let module Fd = Fields_derivers_snapps.Derivers in
    let full = deriver (Fd.o ()) in
    [%test_eq: t] update (update |> Fd.to_json full |> Fd.of_json full)
end

module Events = Snapp_account.Events
module Sequence_events = Snapp_account.Sequence_events

module Body = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ( 'pk
             , 'update
             , 'token_id
             , 'amount
             , 'events
             , 'call_data
             , 'int
             , 'bool
             , 'protocol_state )
             t =
          { public_key : 'pk
          ; update : 'update
          ; token_id : 'token_id
          ; balance_change : 'amount
          ; increment_nonce : 'bool
          ; events : 'events
          ; sequence_events : 'events
          ; call_data : 'call_data
          ; call_depth : 'int
          ; protocol_state : 'protocol_state
          ; use_full_commitment : 'bool
          }
        [@@deriving hlist, sexp, equal, yojson, hash, compare, fields]
      end
    end]
  end

  (* Why isn't this derived automatically? *)
  let hash_fold_array f init x = Array.fold ~init ~f x

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Public_key.Compressed.Stable.V1.t
        , Update.Stable.V1.t
        , Token_id.Stable.V1.t
        , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
        , Pickles.Backend.Tick.Field.Stable.V1.t array list
        , Pickles.Backend.Tick.Field.Stable.V1.t (* Opaque to txn logic *)
        , int
        , bool
        , Snapp_predicate.Protocol_state.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

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
          ( Public_key.Compressed.Stable.V1.t
          , Update.Stable.V1.t
          , unit
          , Fee.Stable.V1.t
          , Pickles.Backend.Tick.Field.Stable.V1.t array list
          , Pickles.Backend.Tick.Field.Stable.V1.t (* Opaque to txn logic *)
          , int
          , unit
          , Snapp_predicate.Protocol_state.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving sexp, equal, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    let dummy : t =
      { public_key = Public_key.Compressed.empty
      ; update = Update.dummy
      ; token_id = ()
      ; balance_change = Fee.zero
      ; increment_nonce = ()
      ; events = []
      ; sequence_events = []
      ; call_data = Field.zero
      ; call_depth = 0
      ; protocol_state = Snapp_predicate.Protocol_state.accept
      ; use_full_commitment = ()
      }

    let deriver obj =
      let open Fields_derivers_snapps in
      let fee obj =
        iso_string obj ~name:"Fee" ~to_string:Fee.to_string
          ~of_string:Fee.of_string
      in
      Poly.Fields.make_creator obj ~public_key:!.public_key
        ~update:!.Update.deriver ~token_id:!.unit ~balance_change:!.fee
        ~increment_nonce:!.unit
        ~events:!.(list @@ array field @@ o ())
        ~sequence_events:!.(list @@ array field @@ o ())
        ~call_data:!.field ~call_depth:!.int
        ~protocol_state:!.Snapp_predicate.Protocol_state.deriver
        ~use_full_commitment:!.unit
      |> finish ~name:"FeePayerPartyBody"
           ~doc:"Body component of a snapp Fee Payer Party"

    let%test_unit "json roundtrip" =
      let open Fields_derivers_snapps.Derivers in
      let full = o () in
      let _a = deriver full in
      [%test_eq: t] dummy (dummy |> to_json full |> of_json full)
  end

  let of_fee_payer (t : Fee_payer.t) : t =
    { t with
      balance_change =
        { Signed_poly.sgn = Sgn.Neg
        ; magnitude = Amount.of_fee t.balance_change
        }
    ; token_id = Token_id.default
    ; increment_nonce = true
    ; use_full_commitment = true
    }

  module Checked = struct
    type t =
      ( Public_key.Compressed.var
      , Update.Checked.t
      , Token_id.Checked.t
      , Amount.Signed.var
      , Events.var
      , Field.Var.t
      , int As_prover.Ref.t
      , Boolean.var
      , Snapp_predicate.Protocol_state.Checked.t )
      Poly.t

    let to_input
        ({ public_key
         ; update
         ; token_id
         ; balance_change
         ; increment_nonce
         ; events
         ; sequence_events
         ; call_data
         ; call_depth = _depth (* ignored *)
         ; protocol_state
         ; use_full_commitment
         } :
          t) =
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
        ; Snapp_predicate.Protocol_state.Checked.to_input protocol_state
        ; Random_oracle_input.Chunked.packed
            ((use_full_commitment :> Field.Var.t), 1)
        ]

    let digest (t : t) =
      Random_oracle.Checked.(
        hash ~init:Hash_prefix.snapp_body (pack_input (to_input t)))
  end

  let typ () : (Checked.t, t) Typ.t =
    let open Poly in
    Typ.of_hlistable
      [ Public_key.Compressed.typ
      ; Update.typ ()
      ; Token_id.typ
      ; Amount.Signed.typ
      ; Boolean.typ
      ; Events.typ
      ; Events.typ
      ; Field.typ
      ; Typ.Internal.ref ()
      ; Snapp_predicate.Protocol_state.typ
      ; Impl.Boolean.typ
      ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

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
    ; protocol_state = Snapp_predicate.Protocol_state.accept
    ; use_full_commitment = false
    }

  let deriver obj =
    let open Fields_derivers_snapps in
    let token_id_deriver obj =
      iso_string obj ~name:"TokenId" ~to_string:Token_id.to_string
        ~of_string:Token_id.of_string
    in
    let balance_change_deriver obj =
      let sign_to_string = function
        | Sgn.Pos ->
            "Positive"
        | Sgn.Neg ->
            "Negative"
      in
      let sign_of_string = function
        | "Positive" ->
            Sgn.Pos
        | "Negative" ->
            Sgn.Neg
        | _ ->
            failwith "impossible"
      in
      let sign_deriver =
        iso_string ~name:"Sign" ~to_string:sign_to_string
          ~of_string:sign_of_string
      in
      Currency.Signed_poly.Fields.make_creator obj ~magnitude:!.amount
        ~sgn:!.sign_deriver
      |> finish ~name:"Balance Change"
    in
    Poly.Fields.make_creator obj ~public_key:!.public_key
      ~update:!.Update.deriver ~token_id:!.token_id_deriver
      ~balance_change:!.balance_change_deriver ~increment_nonce:!.bool
      ~events:!.(list @@ array field @@ o ())
      ~sequence_events:!.(list @@ array field @@ o ())
      ~call_data:!.field ~call_depth:!.int
      ~protocol_state:!.Snapp_predicate.Protocol_state.deriver
      ~use_full_commitment:!.bool
    |> finish ~name:"PartyBody" ~doc:"Body component of a snapp Party"

  let%test_unit "json roundtrip" =
    let open Fields_derivers_snapps.Derivers in
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
       ; call_depth = _ (* ignored *)
       ; protocol_state
       ; use_full_commitment
       } :
        t) =
    List.reduce_exn ~f:Random_oracle_input.Chunked.append
      [ Public_key.Compressed.to_input public_key
      ; Update.to_input update
      ; Token_id.to_input token_id
      ; Amount.Signed.to_input balance_change
      ; Random_oracle_input.Chunked.packed (field_of_bool increment_nonce, 1)
      ; Events.to_input events
      ; Events.to_input sequence_events
      ; Random_oracle_input.Chunked.field call_data
      ; Snapp_predicate.Protocol_state.to_input protocol_state
      ; Random_oracle_input.Chunked.packed (field_of_bool use_full_commitment, 1)
      ]

  let digest (t : t) =
    Random_oracle.(hash ~init:Hash_prefix.snapp_body (pack_input (to_input t)))

  module Digested = struct
    type t = Random_oracle.Digest.t

    module Checked = struct
      type t = Random_oracle.Checked.Digest.t
    end
  end
end

module Predicate = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Full of Snapp_predicate.Account.Stable.V2.t
        | Nonce of Account.Nonce.Stable.V1.t
        | Accept
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let to_full = function
    | Full s ->
        s
    | Nonce n ->
        { Snapp_predicate.Account.accept with
          nonce = Check { lower = n; upper = n }
        }
    | Accept ->
        Snapp_predicate.Account.accept

  let of_full (p : Snapp_predicate.Account.t) =
    let module A = Snapp_predicate.Account in
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
    let open Fields_derivers_snapps.Derivers in
    iso_record ~of_record:of_full ~to_record:to_full
      Snapp_predicate.Account.deriver obj

  let%test_unit "json roundtrip accept" =
    let predicate : t = Accept in
    let module Fd = Fields_derivers_snapps.Derivers in
    let full = deriver (Fd.o ()) in
    [%test_eq: t] predicate (predicate |> Fd.to_json full |> Fd.of_json full)

  let%test_unit "json roundtrip nonce" =
    let predicate : t = Nonce (Account_nonce.of_int 928472) in
    let module Fd = Fields_derivers_snapps.Derivers in
    let full = deriver (Fd.o ()) in
    [%test_eq: t] predicate (predicate |> Fd.to_json full |> Fd.of_json full)

  let%test_unit "json roundtrip full" =
    let n = Account_nonce.of_int 4513 in
    let predicate : t =
      Full
        { Snapp_predicate.Account.accept with
          nonce = Check { lower = n; upper = n }
        ; public_key = Check Public_key.Compressed.empty
        }
    in
    let module Fd = Fields_derivers_snapps.Derivers in
    let full = deriver (Fd.o ()) in
    [%test_eq: t] predicate (predicate |> Fd.to_json full |> Fd.of_json full)

  let%test_unit "to_json" =
    let predicate : t = Nonce (Account_nonce.of_int 34928) in
    let module Fd = Fields_derivers_snapps.Derivers in
    let full = deriver (Fd.o ()) in
    [%test_eq: string]
      (predicate |> Fd.to_json full |> Yojson.Safe.to_string)
      ( {json|{
          balance: null,
          nonce: {lower: "34928", upper: "34928"},
          receiptChainHash: null, publicKey: null, delegate: null,
          state: [null,null,null,null,null,null,null,null],
          sequenceState: null, provedState: null
        }|json}
      |> Yojson.Safe.from_string |> Yojson.Safe.to_string )

  let digest (t : t) =
    let digest x =
      Random_oracle.(
        hash ~init:Hash_prefix_states.party_predicate (pack_input x))
    in
    to_full t |> Snapp_predicate.Account.to_input |> digest

  module Checked = struct
    type t = Snapp_predicate.Account.Checked.t

    let digest (t : t) =
      let digest x =
        Random_oracle.Checked.(
          hash ~init:Hash_prefix_states.party_predicate (pack_input x))
      in
      Snapp_predicate.Account.Checked.to_input t |> digest
  end

  let typ () : (Snapp_predicate.Account.Checked.t, t) Typ.t =
    Typ.transport (Snapp_predicate.Account.typ ()) ~there:to_full
      ~back:(fun s -> Full s)
end

module Predicated = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('body, 'predicate) t = { body : 'body; predicate : 'predicate }
        [@@deriving hlist, sexp, equal, yojson, hash, compare, fields]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = (Body.Stable.V1.t, Predicate.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let deriver obj =
    let open Fields_derivers_snapps.Derivers in
    Poly.Fields.make_creator obj ~body:!.Body.deriver
      ~predicate:!.Predicate.deriver
    |> finish ~name:"SnappPartyPredicated"

  let to_input ({ body; predicate } : t) =
    List.reduce_exn ~f:Random_oracle_input.Chunked.append
      [ Body.to_input body
      ; Random_oracle_input.Chunked.field (Predicate.digest predicate)
      ]

  let digest (t : t) =
    Random_oracle.(hash ~init:Hash_prefix.party (pack_input (to_input t)))

  let typ () : (_, t) Typ.t =
    let open Poly in
    Typ.of_hlistable
      [ Body.typ (); Predicate.typ () ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  module Checked = struct
    type t = (Body.Checked.t, Predicate.Checked.t) Poly.t

    let to_input ({ body; predicate } : t) =
      List.reduce_exn ~f:Random_oracle_input.Chunked.append
        [ Body.Checked.to_input body
        ; Random_oracle_input.Chunked.field (Predicate.Checked.digest predicate)
        ]

    let digest (t : t) =
      Random_oracle.Checked.(
        hash ~init:Hash_prefix.party (pack_input (to_input t)))
  end

  module Proved = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Body.Stable.V1.t
          , Snapp_predicate.Account.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving sexp, equal, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    module Digested = struct
      type t = (Body.Digested.t, Snapp_predicate.Digested.t) Poly.t

      module Checked = struct
        type t = (Body.Digested.Checked.t, Field.Var.t) Poly.t
      end
    end

    module Checked = struct
      type t = (Body.Checked.t, Snapp_predicate.Account.Checked.t) Poly.t
    end
  end

  module Signed = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = (Body.Stable.V1.t, Account_nonce.Stable.V1.t) Poly.Stable.V1.t
        [@@deriving sexp, equal, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    module Checked = struct
      type t = (Body.Checked.t, Account_nonce.Checked.t) Poly.t
    end

    let dummy : t = { body = Body.dummy; predicate = Account_nonce.zero }
  end

  module Fee_payer = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Body.Fee_payer.Stable.V1.t
          , Account_nonce.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving sexp, equal, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    module Checked = struct
      type t = (Body.Checked.t, Account_nonce.Checked.t) Poly.t
    end

    let dummy : t =
      { body = Body.Fee_payer.dummy; predicate = Account_nonce.zero }

    let to_signed (t : t) : Signed.t =
      { body = Body.of_fee_payer t.body; predicate = t.predicate }

    let deriver obj =
      let open Fields_derivers_snapps.Derivers in
      Poly.Fields.make_creator obj ~body:!.Body.Fee_payer.deriver
        ~predicate:!.uint32
      |> finish ~name:"SnappPartyPredicatedFeePayer"
           ~doc:"A party to a snapp transaction with a nonce predicate"
  end

  module Empty = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = (Body.Stable.V1.t, unit) Poly.Stable.V1.t
        [@@deriving sexp, equal, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    let dummy : t = { body = Body.dummy; predicate = () }

    let create body : t = { body; predicate = () }
  end

  let of_signed ({ body; predicate } : Signed.t) : t =
    { body; predicate = Nonce predicate }

  let of_fee_payer ({ body; predicate } : Fee_payer.t) : t =
    { body = Body.of_fee_payer body; predicate = Nonce predicate }
end

module Poly (Data : Type) (Auth : Type) = struct
  type t = { data : Data.t; authorization : Auth.t }
end

module Proved = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
            Poly(Predicated.Proved.Stable.V1)
              (Pickles.Side_loaded.Proof.Stable.V2)
            .t =
        { data : Predicated.Proved.Stable.V1.t
        ; authorization : Pickles.Side_loaded.Proof.Stable.V2.t
        }
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]
end

module Signed = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Poly(Predicated.Signed.Stable.V1)(Signature.Stable.V1).t =
        { data : Predicated.Signed.Stable.V1.t
        ; authorization : Signature.Stable.V1.t
        }
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let account_id (t : t) : Account_id.t =
    Account_id.create t.data.body.public_key t.data.body.token_id
end

module Fee_payer = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Poly(Predicated.Fee_payer.Stable.V1)(Signature.Stable.V1).t =
        { data : Predicated.Fee_payer.Stable.V1.t
        ; authorization : Signature.Stable.V1.t
        }
      [@@deriving sexp, equal, yojson, hash, compare, fields]

      let to_latest = Fn.id
    end
  end]

  let account_id (t : t) : Account_id.t =
    Account_id.create t.data.body.public_key Token_id.default

  let to_signed (t : t) : Signed.t =
    { authorization = t.authorization
    ; data = Predicated.Fee_payer.to_signed t.data
    }

  let deriver obj =
    let open Fields_derivers_snapps.Derivers in
    Fields.make_creator obj
      ~data:!.Predicated.Fee_payer.deriver
      ~authorization:!.Control.signature_deriver
    |> finish ~name:"SnappPartyFeePayer"
         ~doc:"A party to a snapp transaction with a signature authorization"

  let%test_unit "json roundtrip" =
    let dummy : t =
      { data = Predicated.Fee_payer.dummy; authorization = Signature.dummy }
    in
    let open Fields_derivers_snapps.Derivers in
    let full = o () in
    let _a = deriver full in
    [%test_eq: t] dummy (dummy |> to_json full |> of_json full)
end

module Empty = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Poly(Predicated.Empty.Stable.V1)(Unit.Stable.V1).t =
        { data : Predicated.Empty.Stable.V1.t; authorization : unit }
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Poly(Predicated.Stable.V1)(Control.Stable.V2).t =
      { data : Predicated.Stable.V1.t; authorization : Control.Stable.V2.t }
    [@@deriving sexp, equal, yojson, hash, compare, fields]

    let to_latest = Fn.id
  end
end]

let account_id (t : t) : Account_id.t =
  Account_id.create t.data.body.public_key t.data.body.token_id

let of_signed ({ data; authorization } : Signed.t) : t =
  { authorization = Signature authorization; data = Predicated.of_signed data }

let of_fee_payer ({ data; authorization } : Fee_payer.t) : t =
  { authorization = Signature authorization
  ; data = Predicated.of_fee_payer data
  }

(** The change in balance to apply to the target account of this party.
    When this is negative, the amount will be withdrawn from the account and
    made available to later parties in the same transaction.
    When this is positive, the amount will be deposited into the account from
    the funds made available by previous parties in the same transaction.
*)
let balance_change (t : t) : Amount.Signed.t = t.data.body.balance_change

let protocol_state (t : t) : Snapp_predicate.Protocol_state.t =
  t.data.body.protocol_state

let public_key (t : t) : Public_key.Compressed.t = t.data.body.public_key

let token_id (t : t) : Token_id.t = t.data.body.token_id

let use_full_commitment (t : t) : bool = t.data.body.use_full_commitment

let increment_nonce (t : t) : bool = t.data.body.increment_nonce

let deriver obj =
  let open Fields_derivers_snapps.Derivers in
  Fields.make_creator obj ~data:!.Predicated.deriver
    ~authorization:!.Control.deriver
  |> finish ~name:"SnappParty" ~doc:"A party to a snapp transaction"

let%test_unit "json roundtrip dummy" =
  let dummy : t =
    { data = { body = Body.dummy; predicate = Predicate.Accept }
    ; authorization = Control.dummy_of_tag Signature
    }
  in
  let module Fd = Fields_derivers_snapps.Derivers in
  let full = deriver @@ Fd.o () in
  [%test_eq: t] dummy (dummy |> Fd.to_json full |> Fd.of_json full)
