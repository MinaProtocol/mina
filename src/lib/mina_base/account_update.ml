open Core_kernel
open Mina_base_util
open Snark_params.Tick
open Signature_lib
module Impl = Pickles.Impls.Step
open Mina_numbers
open Currency
open Pickles_types
module Digest = Random_oracle.Digest

module type Type = sig
  type t
end

module Events = Zkapp_account.Events
module Actions = Zkapp_account.Actions
module Zkapp_uri = Zkapp_account.Zkapp_uri

module Authorization_kind = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* TODO: yojson for Field.t in snarky (#12591) *)
      type t =
            Mina_wire_types.Mina_base.Account_update.Authorization_kind.V1.t =
        | Signature
        | Proof of (Field.t[@version_asserted])
        | None_given
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  module Structured = struct
    type t =
      { is_signed : bool
      ; is_proved : bool
      ; verification_key_hash : Snark_params.Tick.Field.t
      }
    [@@deriving hlist, annot, fields]

    let to_input ({ is_signed; is_proved; verification_key_hash } : t) =
      let f x = if x then Field.one else Field.zero in
      Random_oracle_input.Chunked.append
        (Random_oracle_input.Chunked.packeds
           [| (f is_signed, 1); (f is_proved, 1) |] )
        (Random_oracle_input.Chunked.field verification_key_hash)

    module Checked = struct
      type t =
        { is_signed : Boolean.var
        ; is_proved : Boolean.var
        ; verification_key_hash : Snark_params.Tick.Field.Var.t
        }
      [@@deriving hlist]

      let to_input { is_signed; is_proved; verification_key_hash } =
        let f (x : Boolean.var) = (x :> Field.Var.t) in
        Random_oracle_input.Chunked.append
          (Random_oracle_input.Chunked.packeds
             [| (f is_signed, 1); (f is_proved, 1) |] )
          (Random_oracle_input.Chunked.field verification_key_hash)
    end

    let typ =
      Typ.of_hlistable ~var_to_hlist:Checked.to_hlist
        ~var_of_hlist:Checked.of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
        [ Boolean.typ; Boolean.typ; Field.typ ]

    let deriver obj =
      let open Fields_derivers_zkapps in
      let ( !. ) = ( !. ) ~t_fields_annots in
      let verification_key_hash =
        needs_custom_js ~js_type:field ~name:"VerificationKeyHash" field
      in
      Fields.make_creator obj ~is_signed:!.bool ~is_proved:!.bool
        ~verification_key_hash:!.verification_key_hash
      |> finish "AuthorizationKindStructured" ~t_toplevel_annots
  end

  let to_control_tag : t -> Control.Tag.t = function
    | None_given ->
        None_given
    | Signature ->
        Signature
    | Proof _ ->
        Proof

  let to_structured : t -> Structured.t = function
    | None_given ->
        { is_signed = false
        ; is_proved = false
        ; verification_key_hash = Zkapp_account.dummy_vk_hash ()
        }
    | Signature ->
        { is_signed = true
        ; is_proved = false
        ; verification_key_hash = Zkapp_account.dummy_vk_hash ()
        }
    | Proof verification_key_hash ->
        { is_signed = false; is_proved = true; verification_key_hash }

  let of_structured_exn : Structured.t -> t = function
    | { is_signed = false; is_proved = false; _ } ->
        None_given
    | { is_signed = true; is_proved = false; _ } ->
        Signature
    | { is_signed = false; is_proved = true; verification_key_hash } ->
        Proof verification_key_hash
    | { is_signed = true; is_proved = true; _ } ->
        failwith "Invalid authorization kind"

  let gen =
    let%bind.Quickcheck vk_hash = Field.gen in
    Quickcheck.Generator.of_list [ None_given; Signature; Proof vk_hash ]

  let deriver obj =
    let open Fields_derivers_zkapps in
    iso_record ~to_record:to_structured ~of_record:of_structured_exn
      Structured.deriver obj

  let to_input x = Structured.to_input (to_structured x)

  module Checked = Structured.Checked

  let typ =
    Structured.typ |> Typ.transport ~there:to_structured ~back:of_structured_exn
end

module May_use_token = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Mina_wire_types.Mina_base.Account_update.May_use_token.V1.t =
        | No
            (** No permission to use any token other than the default Mina
                token.
            *)
        | Parents_own_token
            (** Has permission to use the token owned by the direct parent of
                this account update, which may be inherited by child account
                updates.
            *)
        | Inherit_from_parent
            (** Inherit the token permission available to the parent. *)
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let gen =
    Quickcheck.Generator.of_list [ No; Parents_own_token; Inherit_from_parent ]

  let to_string = function
    | No ->
        "No"
    | Parents_own_token ->
        "ParentsOwnToken"
    | Inherit_from_parent ->
        "InheritFromParent"

  let of_string = function
    | "No" ->
        No
    | "ParentsOwnToken" ->
        Parents_own_token
    | "InheritFromParent" ->
        Inherit_from_parent
    | s ->
        failwithf "Invalid call type: %s" s ()

  let parents_own_token = function Parents_own_token -> true | _ -> false

  let inherit_from_parent = function Inherit_from_parent -> true | _ -> false

  module As_record : sig
    type variant = t

    type 'bool t

    val parents_own_token : 'bool t -> 'bool

    val inherit_from_parent : 'bool t -> 'bool

    val map : f:('a -> 'b) -> 'a t -> 'b t

    val to_hlist : 'bool t -> (unit, 'bool -> 'bool -> unit) H_list.t

    val of_hlist : (unit, 'bool -> 'bool -> unit) H_list.t -> 'bool t

    val to_input :
      field_of_bool:('a -> 'b) -> 'a t -> 'b Random_oracle_input.Chunked.t

    val typ : (Snark_params.Tick.Boolean.var t, bool t) Snark_params.Tick.Typ.t

    val equal :
         and_:('bool -> 'bool -> 'bool)
      -> equal:('a -> 'a -> 'bool)
      -> 'a t
      -> 'a t
      -> 'bool

    val to_variant : bool t -> variant

    val of_variant : variant -> bool t

    (* TODO: Create an alias for this type *)
    val deriver :
         ( bool t
         , ( ( ( bool t
               , ( bool t
                 , ( bool t
                   , ( ( bool t
                       , ( bool t
                         , ( bool t
                           , ( (< contramap : (bool t -> bool t) Core_kernel.ref
                                ; graphql_arg :
                                    (   unit
                                     -> bool t
                                        Fields_derivers_graphql.Schema.Arg
                                        .arg_typ )
                                    Core_kernel.ref
                                ; graphql_arg_accumulator :
                                    bool t
                                    Fields_derivers_zkapps.Derivers.Graphql.Args
                                    .Acc
                                    .T
                                    .t
                                    Core_kernel.ref
                                ; graphql_creator :
                                    (   ( ( 'a
                                          , bool t
                                          , bool t
                                          , 'b )
                                          Fields_derivers_zkapps.Derivers
                                          .Graphql
                                          .Args
                                          .Output
                                          .t
                                        , bool t
                                        , bool t
                                        , 'b )
                                        Fields_derivers_zkapps.Derivers.Graphql
                                        .Args
                                        .Input
                                        .t
                                     -> bool t )
                                    Core_kernel.ref
                                ; graphql_fields :
                                    bool t
                                    Fields_derivers_zkapps.Derivers.Graphql
                                    .Fields
                                    .Input
                                    .T
                                    .t
                                    Core_kernel.ref
                                ; graphql_fields_accumulator :
                                    bool t
                                    Fields_derivers_zkapps.Derivers.Graphql
                                    .Fields
                                    .Accumulator
                                    .T
                                    .t
                                    list
                                    Core_kernel.ref
                                ; graphql_query : string option Core_kernel.ref
                                ; graphql_query_accumulator :
                                    (Core_kernel.String.t * string option)
                                    option
                                    list
                                    Core_kernel.ref
                                ; js_layout :
                                    [> `Assoc of (string * Yojson.Safe.t) list ]
                                    Core_kernel.ref
                                ; js_layout_accumulator :
                                    Fields_derivers_zkapps__.Fields_derivers_js
                                    .Js_layout
                                    .Accumulator
                                    .field
                                    option
                                    list
                                    Core_kernel.ref
                                ; map : (bool t -> bool t) Core_kernel.ref
                                ; nullable_graphql_arg :
                                    (   unit
                                     -> 'b
                                        Fields_derivers_graphql.Schema.Arg
                                        .arg_typ )
                                    Core_kernel.ref
                                ; nullable_graphql_fields :
                                    bool t option
                                    Fields_derivers_zkapps.Derivers.Graphql
                                    .Fields
                                    .Input
                                    .T
                                    .t
                                    Core_kernel.ref
                                ; of_json :
                                    (Yojson.Safe.t -> bool t) Core_kernel.ref
                                ; of_json_creator :
                                    Yojson.Safe.t Core_kernel.String.Map.t
                                    Core_kernel.ref
                                ; skip : bool Core_kernel.ref
                                ; to_json :
                                    (bool t -> Yojson.Safe.t) Core_kernel.ref
                                ; to_json_accumulator :
                                    ( Core_kernel.String.t
                                    * (bool t -> Yojson.Safe.t) )
                                    option
                                    list
                                    Core_kernel.ref
                                ; .. >
                                as
                                'a )
                               Fields_derivers_zkapps__.Fields_derivers_js
                               .Js_layout
                               .Input
                               .t
                               Fields_derivers_graphql.Graphql_query.Input.t
                             , bool t
                             , bool t
                             , 'b )
                             Fields_derivers_zkapps.Derivers.Graphql.Args.Input
                             .t
                           , bool t
                           , bool t option )
                           Fields_derivers_zkapps.Derivers.Graphql.Fields.Input
                           .t
                         , bool t )
                         Fields_derivers_json.Of_yojson.Input.t
                       , bool t )
                       Fields_derivers_json.To_yojson.Input.t
                       Fields_derivers_zkapps.Unified_input.t
                       Fields_derivers_zkapps__.Fields_derivers_js.Js_layout
                       .Input
                       .t
                       Fields_derivers_graphql.Graphql_query.Input.t
                     , bool t
                     , bool t
                     , 'b )
                     Fields_derivers_zkapps.Derivers.Graphql.Args.Input.t
                   , bool t
                   , bool t option )
                   Fields_derivers_zkapps.Derivers.Graphql.Fields.Input.t
                 , bool t )
                 Fields_derivers_json.Of_yojson.Input.t
               , bool t )
               Fields_derivers_json.To_yojson.Input.t
               Fields_derivers_zkapps.Unified_input.t
             , bool t
             , bool t
             , 'b )
             Fields_derivers_zkapps.Derivers.Graphql.Args.Input.t
           , bool t
           , bool t
           , 'b )
           Fields_derivers_zkapps.Derivers.Graphql.Args.Acc.t
         , bool t
         , bool t option )
         Fields_derivers_zkapps.Derivers.Graphql.Fields.Accumulator.t
      -> ( bool t
         , ( bool t
           , ( bool t
             , ( 'a Fields_derivers_zkapps__.Fields_derivers_js.Js_layout.Input.t
                 Fields_derivers_graphql.Graphql_query.Input.t
               , bool t
               , bool t
               , 'b )
               Fields_derivers_zkapps.Derivers.Graphql.Args.Input.t
             , bool t
             , bool t option )
             Fields_derivers_zkapps.Derivers.Graphql.Fields.Input.t
           , bool t )
           Fields_derivers_json.Of_yojson.Input.t
         , bool t )
         Fields_derivers_json.To_yojson.Input.t
         Fields_derivers_zkapps.Unified_input.t
  end = struct
    type variant = t

    type 'bool t =
      { (* NB: call is implicit. *)
        parents_own_token : 'bool
      ; inherit_from_parent : 'bool
      }
    [@@deriving annot, hlist, fields]

    let map ~f { parents_own_token; inherit_from_parent } =
      { parents_own_token = f parents_own_token
      ; inherit_from_parent = f inherit_from_parent
      }

    let typ : _ Typ.t =
      let open Snark_params.Tick in
      let (Typ typ) =
        Typ.of_hlistable
          [ Boolean.typ; Boolean.typ ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist
      in
      Typ
        { typ with
          check =
            (fun ({ parents_own_token; inherit_from_parent } as x) ->
              let open Checked in
              let%bind () = typ.check x in
              let sum =
                Field.Var.(
                  add (parents_own_token :> t) (inherit_from_parent :> t))
              in
              (* Assert boolean; we should really have a helper for this
                 somewhere.
              *)
              let%bind sum_squared = Field.Checked.mul sum sum in
              Field.Checked.Assert.equal sum sum_squared )
        }

    let to_input ~field_of_bool { parents_own_token; inherit_from_parent } =
      Array.reduce_exn ~f:Random_oracle_input.Chunked.append
        [| Random_oracle_input.Chunked.packed
             (field_of_bool parents_own_token, 1)
         ; Random_oracle_input.Chunked.packed
             (field_of_bool inherit_from_parent, 1)
        |]

    let equal ~and_ ~equal
        { parents_own_token = parents_own_token1
        ; inherit_from_parent = inherit_from_parent1
        }
        { parents_own_token = parents_own_token2
        ; inherit_from_parent = inherit_from_parent2
        } =
      and_
        (equal parents_own_token1 parents_own_token2)
        (equal inherit_from_parent1 inherit_from_parent2)

    let to_variant = function
      | { parents_own_token = false; inherit_from_parent = false } ->
          No
      | { parents_own_token = true; inherit_from_parent = false } ->
          Parents_own_token
      | { parents_own_token = false; inherit_from_parent = true } ->
          Inherit_from_parent
      | _ ->
          failwith "May_use_token.to_variant: More than one boolean flag is set"

    let of_variant = function
      | No ->
          { parents_own_token = false; inherit_from_parent = false }
      | Parents_own_token ->
          { parents_own_token = true; inherit_from_parent = false }
      | Inherit_from_parent ->
          { parents_own_token = false; inherit_from_parent = true }

    let deriver obj : _ Fields_derivers_zkapps.Unified_input.t =
      let open Fields_derivers_zkapps.Derivers in
      let ( !. ) = ( !. ) ~t_fields_annots in
      Fields.make_creator obj ~parents_own_token:!.bool
        ~inherit_from_parent:!.bool
      |> finish "MayUseToken" ~t_toplevel_annots
  end

  let quickcheck_generator = gen

  let deriver obj =
    let open Fields_derivers_zkapps in
    let may_use_token =
      iso_record ~of_record:As_record.to_variant ~to_record:As_record.of_variant
        As_record.deriver
    in
    needs_custom_js
      ~js_type:
        (js_record
           [ ("parentsOwnToken", js_layout bool)
           ; ("inheritFromParent", js_layout bool)
           ] )
      ~name:"MayUseToken" may_use_token obj

  module Checked = struct
    type t = Boolean.var As_record.t

    let parents_own_token = As_record.parents_own_token

    let inherit_from_parent = As_record.inherit_from_parent

    let constant x =
      As_record.map ~f:Boolean.var_of_value @@ As_record.of_variant x

    let to_input (x : t) =
      As_record.to_input
        ~field_of_bool:(fun (x : Boolean.var) -> (x :> Field.Var.t))
        x

    let equal x y =
      As_record.equal ~equal:Run.Boolean.equal ~and_:Run.Boolean.( &&& ) x y

    let assert_equal x y =
      As_record.equal ~equal:Run.Boolean.Assert.( = ) ~and_:(fun _ _ -> ()) x y
  end

  let to_input x = As_record.to_input ~field_of_bool (As_record.of_variant x)

  let typ : (Checked.t, t) Typ.t =
    As_record.typ
    |> Typ.transport ~there:As_record.of_variant ~back:As_record.to_variant
end

module Update = struct
  module Timing_info = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
              Mina_wire_types.Mina_base.Account_update.Update.Timing_info.V1.t =
          { initial_minimum_balance : Balance.Stable.V1.t
          ; cliff_time : Global_slot_since_genesis.Stable.V1.t
          ; cliff_amount : Amount.Stable.V1.t
          ; vesting_period : Global_slot_span.Stable.V1.t
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
      let%bind cliff_time = Global_slot_since_genesis.gen in
      let%bind cliff_amount =
        Amount.gen_incl Amount.zero (Balance.to_amount initial_minimum_balance)
      in
      let%bind vesting_period =
        Global_slot_span.gen_incl
          Global_slot_span.(succ zero)
          (Global_slot_span.of_int 10)
      in
      let%map vesting_increment =
        Amount.gen_incl Amount.one (Amount.of_nanomina_int_exn 100)
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
        ; Global_slot_since_genesis.to_input t.cliff_time
        ; Amount.to_input t.cliff_amount
        ; Global_slot_span.to_input t.vesting_period
        ; Amount.to_input t.vesting_increment
        ]

    let dummy =
      let slot_unused = Global_slot_since_genesis.zero in
      let slot_span_unused = Global_slot_span.zero in
      let balance_unused = Balance.zero in
      let amount_unused = Amount.zero in
      { initial_minimum_balance = balance_unused
      ; cliff_time = slot_unused
      ; cliff_amount = amount_unused
      ; vesting_period = slot_span_unused
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
        ; cliff_time : Global_slot_since_genesis.Checked.t
        ; cliff_amount : Amount.Checked.t
        ; vesting_period : Global_slot_span.Checked.t
        ; vesting_increment : Amount.Checked.t
        }
      [@@deriving hlist]

      let constant (t : value) : t =
        { initial_minimum_balance = Balance.var_of_t t.initial_minimum_balance
        ; cliff_time = Global_slot_since_genesis.Checked.constant t.cliff_time
        ; cliff_amount = Amount.var_of_t t.cliff_amount
        ; vesting_period = Global_slot_span.Checked.constant t.vesting_period
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
          ; Global_slot_since_genesis.Checked.to_input cliff_time
          ; Amount.var_to_input cliff_amount
          ; Global_slot_span.Checked.to_input vesting_period
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
        ; Global_slot_since_genesis.typ
        ; Amount.typ
        ; Global_slot_span.typ
        ; Amount.typ
        ]
        ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

    let deriver obj =
      let open Fields_derivers_zkapps.Derivers in
      let ( !. ) = ( !. ) ~t_fields_annots in
      Fields.make_creator obj ~initial_minimum_balance:!.balance
        ~cliff_time:!.global_slot_since_genesis
        ~cliff_amount:!.amount ~vesting_period:!.global_slot_span
        ~vesting_increment:!.amount
      |> finish "Timing" ~t_toplevel_annots
  end

  open Zkapp_basic

  [%%versioned
  module Stable = struct
    module V1 = struct
      (* TODO: Have to check that the public key is not = Public_key.Compressed.empty here.  *)
      type t = Mina_wire_types.Mina_base.Account_update.Update.V1.t =
        { app_state :
            F.Stable.V1.t Set_or_keep.Stable.V1.t Zkapp_state.V.Stable.V1.t
        ; delegate : Public_key.Compressed.Stable.V1.t Set_or_keep.Stable.V1.t
        ; verification_key :
            Verification_key_wire.Stable.V1.t Set_or_keep.Stable.V1.t
        ; permissions : Permissions.Stable.V2.t Set_or_keep.Stable.V1.t
        ; zkapp_uri : Zkapp_uri.Stable.V1.t Set_or_keep.Stable.V1.t
        ; token_symbol :
            Account.Token_symbol.Stable.V1.t Set_or_keep.Stable.V1.t
        ; timing : Timing_info.Stable.V1.t Set_or_keep.Stable.V1.t
        ; voting_for : State_hash.Stable.V1.t Set_or_keep.Stable.V1.t
        }
      [@@deriving annot, compare, equal, sexp, hash, yojson, fields, hlist]

      let to_latest = Fn.id
    end
  end]

  let gen ?(token_account = false) ?(zkapp_account = false) ?vk
      ?permissions_auth () : t Quickcheck.Generator.t =
    let open Quickcheck.Let_syntax in
    let%bind app_state =
      let%bind fields =
        let field_gen = Snark_params.Tick.Field.gen in
        Quickcheck.Generator.list_with_length 8 (Set_or_keep.gen field_gen)
      in
      (* won't raise because length is correct *)
      Quickcheck.Generator.return (Zkapp_state.V.of_list_exn fields)
    in
    let%bind delegate =
      if not token_account then Set_or_keep.gen Public_key.Compressed.gen
      else return Set_or_keep.Keep
    in
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
    (* a new account for the Account_update.t is in the ledger when we use
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
      ; Set_or_keep.to_input permissions ~dummy:Permissions.empty
          ~f:Permissions.to_input
      ; Set_or_keep.to_input
          (Set_or_keep.map ~f:Zkapp_account.hash_zkapp_uri zkapp_uri)
          ~dummy:(Zkapp_account.hash_zkapp_uri_opt None)
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
      ; Set_or_keep.typ ~dummy:Permissions.empty Permissions.typ
      ; Set_or_keep.optional_typ
          (Data_as_hash.lazy_optional_typ ~hash:Zkapp_account.hash_zkapp_uri
             ~non_preimage:(lazy (Zkapp_account.hash_zkapp_uri_opt None))
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
    let zkapp_uri =
      needs_custom_js
        ~js_type:(Data_as_hash.deriver string)
        ~name:"ZkappUri" string
    in
    let token_symbol =
      needs_custom_js
        ~js_type:
          (js_record
             [ ("symbol", js_layout string); ("field", js_layout field) ] )
        ~name:"TokenSymbol" string
    in
    finish "AccountUpdateModification" ~t_toplevel_annots
    @@ Fields.make_creator
         ~app_state:!.(Zkapp_state.deriver @@ Set_or_keep.deriver field)
         ~delegate:!.(Set_or_keep.deriver public_key)
         ~verification_key:!.(Set_or_keep.deriver verification_key_with_hash)
         ~permissions:!.(Set_or_keep.deriver Permissions.deriver)
         ~zkapp_uri:!.(Set_or_keep.deriver zkapp_uri)
         ~token_symbol:!.(Set_or_keep.deriver token_symbol)
         ~timing:!.(Set_or_keep.deriver Timing_info.deriver)
         ~voting_for:!.(Set_or_keep.deriver State_hash.deriver)
         obj
end

module Account_precondition = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Zkapp_precondition.Account.Stable.V2.t
      [@@deriving sexp, yojson, hash]

      let (_ :
            ( t
            , Mina_wire_types.Mina_base.Account_update.Account_precondition.V1.t
            )
            Type_equal.t ) =
        Type_equal.T

      let to_latest = Fn.id

      [%%define_locally Zkapp_precondition.Account.(equal, compare)]
    end
  end]

  [%%define_locally Stable.Latest.(equal, compare)]

  let gen : t Quickcheck.Generator.t =
    (* we used to have 3 constructors, Full, Nonce, and Accept for the type t
       nowadays, the generator creates these 3 different kinds of values, but all mapped to t
    *)
    Quickcheck.Generator.variant3 Zkapp_precondition.Account.gen
      Account.Nonce.gen Unit.quickcheck_generator
    |> Quickcheck.Generator.map ~f:(function
         | `A precondition ->
             precondition
         | `B n ->
             Zkapp_precondition.Account.nonce n
         | `C () ->
             Zkapp_precondition.Account.accept )

  module Tag = struct
    type t = Full | Nonce | Accept [@@deriving equal, compare, sexp, yojson]
  end

  let deriver obj = Zkapp_precondition.Account.deriver obj

  let digest (t : t) =
    let digest x =
      Random_oracle.(
        hash ~init:Hash_prefix_states.account_update_account_precondition
          (pack_input x))
    in
    t |> Zkapp_precondition.Account.to_input |> digest

  module Checked = struct
    type t = Zkapp_precondition.Account.Checked.t

    let digest (t : t) =
      let digest x =
        Random_oracle.Checked.(
          hash ~init:Hash_prefix_states.account_update_account_precondition
            (pack_input x))
      in
      Zkapp_precondition.Account.Checked.to_input t |> digest

    let nonce (t : t) = t.nonce
  end

  let typ () : (Zkapp_precondition.Account.Checked.t, t) Typ.t =
    Zkapp_precondition.Account.typ ()

  let nonce ({ nonce; _ } : t) = nonce
end

module Preconditions = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Mina_wire_types.Mina_base.Account_update.Preconditions.V1.t =
        { network : Zkapp_precondition.Protocol_state.Stable.V1.t
        ; account : Account_precondition.Stable.V1.t
        ; valid_while :
            Mina_numbers.Global_slot_since_genesis.Stable.V1.t
            Zkapp_precondition.Numeric.Stable.V1.t
        }
      [@@deriving annot, sexp, equal, yojson, hash, hlist, compare, fields]

      let to_latest = Fn.id
    end
  end]

  let deriver obj =
    let open Fields_derivers_zkapps.Derivers in
    let ( !. ) = ( !. ) ~t_fields_annots in
    Fields.make_creator obj
      ~network:!.Zkapp_precondition.Protocol_state.deriver
      ~account:!.Account_precondition.deriver
      ~valid_while:!.Zkapp_precondition.Valid_while.deriver
    |> finish "Preconditions" ~t_toplevel_annots

  let to_input ({ network; account; valid_while } : t) =
    List.reduce_exn ~f:Random_oracle_input.Chunked.append
      [ Zkapp_precondition.Protocol_state.to_input network
      ; Zkapp_precondition.Account.to_input account
      ; Zkapp_precondition.Valid_while.to_input valid_while
      ]

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map network = Zkapp_precondition.Protocol_state.gen
    and account = Account_precondition.gen
    and valid_while = Zkapp_precondition.Valid_while.gen in
    { network; account; valid_while }

  module Checked = struct
    module Type_of_var (V : sig
      type var
    end) =
    struct
      type t = V.var
    end

    type t =
      { network : Zkapp_precondition.Protocol_state.Checked.t
      ; account : Account_precondition.Checked.t
      ; valid_while : Zkapp_precondition.Valid_while.Checked.t
      }
    [@@deriving annot, hlist, fields]

    let to_input ({ network; account; valid_while } : t) =
      List.reduce_exn ~f:Random_oracle_input.Chunked.append
        [ Zkapp_precondition.Protocol_state.Checked.to_input network
        ; Zkapp_precondition.Account.Checked.to_input account
        ; Zkapp_precondition.Valid_while.Checked.to_input valid_while
        ]
  end

  let typ () : (Checked.t, t) Typ.t =
    Typ.of_hlistable
      [ Zkapp_precondition.Protocol_state.typ
      ; Account_precondition.typ ()
      ; Zkapp_precondition.Valid_while.typ
      ]
      ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let accept =
    { network = Zkapp_precondition.Protocol_state.accept
    ; account = Zkapp_precondition.Account.accept
    ; valid_while = Ignore
    }
end

module Body = struct
  (* Why isn't this derived automatically? *)
  let hash_fold_array f init x = Array.fold ~init ~f x

  module Events' = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          Pickles.Backend.Tick.Field.Stable.V1.t
          Bounded_types.ArrayN16.Stable.V1.t
          list
        [@@deriving sexp, equal, hash, compare, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Graphql_repr = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { public_key : Public_key.Compressed.Stable.V1.t
          ; token_id : Token_id.Stable.V2.t
          ; update : Update.Stable.V1.t
          ; balance_change :
              (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
          ; increment_nonce : bool
          ; events : Events'.Stable.V1.t
          ; actions : Events'.Stable.V1.t
          ; call_data : Pickles.Backend.Tick.Field.Stable.V1.t
          ; call_depth : int
          ; preconditions : Preconditions.Stable.V1.t
          ; use_full_commitment : bool
          ; implicit_account_creation_fee : bool
          ; may_use_token : May_use_token.Stable.V1.t
          ; authorization_kind : Authorization_kind.Stable.V1.t
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
        ~actions:!.Actions.deriver ~call_data:!.field
        ~preconditions:!.Preconditions.deriver ~use_full_commitment:!.bool
        ~implicit_account_creation_fee:!.bool
        ~may_use_token:!.May_use_token.deriver ~call_depth:!.int
        ~authorization_kind:!.Authorization_kind.deriver
      |> finish "AccountUpdateBody" ~t_toplevel_annots

    let dummy : t =
      { public_key = Public_key.Compressed.empty
      ; update = Update.dummy
      ; token_id = Token_id.default
      ; balance_change = Amount.Signed.zero
      ; increment_nonce = false
      ; events = []
      ; actions = []
      ; call_data = Field.zero
      ; call_depth = 0
      ; preconditions = Preconditions.accept
      ; use_full_commitment = false
      ; implicit_account_creation_fee = false
      ; may_use_token = No
      ; authorization_kind = None_given
      }
  end

  module Simple = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { public_key : Public_key.Compressed.Stable.V1.t
          ; token_id : Token_id.Stable.V2.t
          ; update : Update.Stable.V1.t
          ; balance_change :
              (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
          ; increment_nonce : bool
          ; events : Events'.Stable.V1.t
          ; actions : Events'.Stable.V1.t
          ; call_data : Pickles.Backend.Tick.Field.Stable.V1.t
          ; call_depth : int
          ; preconditions : Preconditions.Stable.V1.t
          ; use_full_commitment : bool
          ; implicit_account_creation_fee : bool
          ; may_use_token : May_use_token.Stable.V1.t
          ; authorization_kind : Authorization_kind.Stable.V1.t
          }
        [@@deriving annot, sexp, equal, yojson, hash, compare, fields]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Mina_wire_types.Mina_base.Account_update.Body.V1.t =
        { public_key : Public_key.Compressed.Stable.V1.t
        ; token_id : Token_id.Stable.V2.t
        ; update : Update.Stable.V1.t
        ; balance_change :
            (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
        ; increment_nonce : bool
        ; events : Events'.Stable.V1.t
        ; actions : Events'.Stable.V1.t
        ; call_data : Pickles.Backend.Tick.Field.Stable.V1.t
        ; preconditions : Preconditions.Stable.V1.t
        ; use_full_commitment : bool
        ; implicit_account_creation_fee : bool
        ; may_use_token : May_use_token.Stable.V1.t
        ; authorization_kind : Authorization_kind.Stable.V1.t
        }
      [@@deriving annot, sexp, equal, yojson, hash, hlist, compare, fields]

      let to_latest = Fn.id
    end
  end]

  let of_simple (p : Simple.t) : t =
    { public_key = p.public_key
    ; token_id = p.token_id
    ; update = p.update
    ; balance_change = p.balance_change
    ; increment_nonce = p.increment_nonce
    ; events = p.events
    ; actions = p.actions
    ; call_data = p.call_data
    ; preconditions = p.preconditions
    ; use_full_commitment = p.use_full_commitment
    ; implicit_account_creation_fee = p.implicit_account_creation_fee
    ; may_use_token = p.may_use_token
    ; authorization_kind = p.authorization_kind
    }

  let of_graphql_repr
      ({ public_key
       ; token_id
       ; update
       ; balance_change
       ; increment_nonce
       ; events
       ; actions
       ; call_data
       ; preconditions
       ; use_full_commitment
       ; implicit_account_creation_fee
       ; may_use_token
       ; call_depth = _
       ; authorization_kind
       } :
        Graphql_repr.t ) : t =
    { public_key
    ; token_id
    ; update
    ; balance_change
    ; increment_nonce
    ; events
    ; actions
    ; call_data
    ; preconditions
    ; use_full_commitment
    ; implicit_account_creation_fee
    ; may_use_token
    ; authorization_kind
    }

  let to_graphql_repr
      ({ public_key
       ; token_id
       ; update
       ; balance_change
       ; increment_nonce
       ; events
       ; actions
       ; call_data
       ; preconditions
       ; use_full_commitment
       ; implicit_account_creation_fee
       ; may_use_token
       ; authorization_kind
       } :
        t ) ~call_depth : Graphql_repr.t =
    { Graphql_repr.public_key
    ; token_id
    ; update
    ; balance_change
    ; increment_nonce
    ; events
    ; actions
    ; call_data
    ; preconditions
    ; use_full_commitment
    ; implicit_account_creation_fee
    ; may_use_token
    ; call_depth
    ; authorization_kind
    }

  module Fee_payer = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Mina_wire_types.Mina_base.Account_update.Body.Fee_payer.V1.t =
          { public_key : Public_key.Compressed.Stable.V1.t
          ; fee : Fee.Stable.V1.t
          ; valid_until : Global_slot_since_genesis.Stable.V1.t option
                [@name "validUntil"]
          ; nonce : Account_nonce.Stable.V1.t
          }
        [@@deriving annot, sexp, equal, yojson, hash, compare, hlist, fields]

        let to_latest = Fn.id
      end
    end]

    let gen : t Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%map public_key = Public_key.Compressed.gen
      and fee = Currency.Fee.gen
      and valid_until =
        Option.quickcheck_generator Global_slot_since_genesis.gen
      and nonce = Account.Nonce.gen in
      { public_key; fee; valid_until; nonce }

    let dummy : t =
      { public_key = Public_key.Compressed.empty
      ; fee = Fee.zero
      ; valid_until = None
      ; nonce = Account_nonce.zero
      }

    let deriver obj =
      let open Fields_derivers_zkapps in
      let fee obj =
        iso_string obj ~name:"Fee" ~js_type:UInt64 ~to_string:Fee.to_string
          ~of_string:Fee.of_string
      in
      let ( !. ) ?skip_data = ( !. ) ?skip_data ~t_fields_annots in
      Fields.make_creator obj ~public_key:!.public_key ~fee:!.fee
        ~valid_until:
          !.Fields_derivers_zkapps.Derivers.(
              option ~js_type:Or_undefined @@ global_slot_since_genesis @@ o ())
        ~nonce:!.uint32
      |> finish "FeePayerBody" ~t_toplevel_annots
  end

  let of_fee_payer (t : Fee_payer.t) : t =
    { public_key = t.public_key
    ; token_id = Token_id.default
    ; update = Update.noop
    ; balance_change =
        { Signed_poly.sgn = Sgn.Neg; magnitude = Amount.of_fee t.fee }
    ; increment_nonce = true
    ; events = []
    ; actions = []
    ; call_data = Field.zero
    ; preconditions =
        { Preconditions.network =
            (let valid_until =
               Option.value ~default:Global_slot_since_genesis.max_value
                 t.valid_until
             in
             { Zkapp_precondition.Protocol_state.accept with
               global_slot_since_genesis =
                 Check
                   { lower = Global_slot_since_genesis.zero
                   ; upper = valid_until
                   }
             } )
        ; account = Zkapp_precondition.Account.nonce t.nonce
        ; valid_while = Ignore
        }
    ; use_full_commitment = true
    ; implicit_account_creation_fee = true
    ; may_use_token = No
    ; authorization_kind = Signature
    }

  let to_simple_fee_payer (t : Fee_payer.t) : Simple.t =
    { public_key = t.public_key
    ; token_id = Token_id.default
    ; update = Update.noop
    ; balance_change =
        { Signed_poly.sgn = Sgn.Neg; magnitude = Amount.of_fee t.fee }
    ; increment_nonce = true
    ; events = []
    ; actions = []
    ; call_data = Field.zero
    ; preconditions =
        { Preconditions.network =
            (let valid_until =
               Option.value ~default:Global_slot_since_genesis.max_value
                 t.valid_until
             in
             { Zkapp_precondition.Protocol_state.accept with
               global_slot_since_genesis =
                 Check
                   { lower = Global_slot_since_genesis.zero
                   ; upper = valid_until
                   }
             } )
        ; account = Zkapp_precondition.Account.nonce t.nonce
        ; valid_while = Ignore
        }
    ; use_full_commitment = true
    ; implicit_account_creation_fee = true
    ; may_use_token = No
    ; call_depth = 0
    ; authorization_kind = Signature
    }

  let to_fee_payer_exn (t : t) : Fee_payer.t =
    let { public_key; preconditions; balance_change; _ } = t in
    let fee =
      Currency.Fee.of_uint64
        (balance_change.magnitude |> Currency.Amount.to_uint64)
    in
    let nonce =
      if Zkapp_precondition.Account.is_nonce preconditions.account then
        match preconditions.account.nonce with
        | Check { lower; upper = _ } ->
            lower
        | Ignore ->
            failwith "Unexpected Ignore for fee payer precondition nonce"
      else failwith "Expected a nonce for fee payer account precondition"
    in
    let valid_until =
      match preconditions.network.global_slot_since_genesis with
      | Ignore ->
          None
      | Check { upper; _ } ->
          Some upper
    in
    { public_key; fee; valid_until; nonce }

  module Checked = struct
    module Type_of_var (V : sig
      type var
    end) =
    struct
      type t = V.var
    end

    type t =
      { public_key : Public_key.Compressed.var
      ; token_id : Token_id.Checked.t
      ; update : Update.Checked.t
      ; balance_change : Amount.Signed.var
      ; increment_nonce : Boolean.var
      ; events : Events.var
      ; actions : Actions.var
      ; call_data : Field.Var.t
      ; preconditions : Preconditions.Checked.t
      ; use_full_commitment : Boolean.var
      ; implicit_account_creation_fee : Boolean.var
      ; may_use_token : May_use_token.Checked.t
      ; authorization_kind : Authorization_kind.Checked.t
      }
    [@@deriving annot, hlist, fields]

    let to_input
        ({ public_key
         ; token_id
         ; update
         ; balance_change
         ; increment_nonce
         ; events
         ; actions
         ; call_data
         ; preconditions
         ; use_full_commitment
         ; implicit_account_creation_fee
         ; may_use_token
         ; authorization_kind
         } :
          t ) =
      List.reduce_exn ~f:Random_oracle_input.Chunked.append
        [ Public_key.Compressed.Checked.to_input public_key
        ; Token_id.Checked.to_input token_id
        ; Update.Checked.to_input update
        ; Snark_params.Tick.Run.run_checked
            (Amount.Signed.Checked.to_input balance_change)
        ; Random_oracle_input.Chunked.packed
            ((increment_nonce :> Field.Var.t), 1)
        ; Events.var_to_input events
        ; Actions.var_to_input actions
        ; Random_oracle_input.Chunked.field call_data
        ; Preconditions.Checked.to_input preconditions
        ; Random_oracle_input.Chunked.packed
            ((use_full_commitment :> Field.Var.t), 1)
        ; Random_oracle_input.Chunked.packed
            ((implicit_account_creation_fee :> Field.Var.t), 1)
        ; May_use_token.Checked.to_input may_use_token
        ; Authorization_kind.Checked.to_input authorization_kind
        ]

    let digest ~signature_kind (t : t) =
      Random_oracle.Checked.(
        hash
          ~init:(Hash_prefix.zkapp_body ~signature_kind)
          (pack_input (to_input t)))
  end

  let typ () : (Checked.t, t) Typ.t =
    Typ.of_hlistable
      [ Public_key.Compressed.typ
      ; Token_id.typ
      ; Update.typ ()
      ; Amount.Signed.typ
      ; Boolean.typ
      ; Events.typ
      ; Actions.typ
      ; Field.typ
      ; Preconditions.typ ()
      ; Impl.Boolean.typ
      ; Impl.Boolean.typ
      ; May_use_token.typ
      ; Authorization_kind.typ
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
    ; actions = []
    ; call_data = Field.zero
    ; preconditions = Preconditions.accept
    ; use_full_commitment = false
    ; implicit_account_creation_fee = true
    ; may_use_token = No
    ; authorization_kind = None_given
    }

  let to_input
      ({ public_key
       ; update
       ; token_id
       ; balance_change
       ; increment_nonce
       ; events
       ; actions
       ; call_data
       ; preconditions
       ; use_full_commitment
       ; implicit_account_creation_fee
       ; may_use_token
       ; authorization_kind
       } :
        t ) =
    List.reduce_exn ~f:Random_oracle_input.Chunked.append
      [ Public_key.Compressed.to_input public_key
      ; Token_id.to_input token_id
      ; Update.to_input update
      ; Amount.Signed.to_input balance_change
      ; Random_oracle_input.Chunked.packed (field_of_bool increment_nonce, 1)
      ; Events.to_input events
      ; Actions.to_input actions
      ; Random_oracle_input.Chunked.field call_data
      ; Preconditions.to_input preconditions
      ; Random_oracle_input.Chunked.packed (field_of_bool use_full_commitment, 1)
      ; Random_oracle_input.Chunked.packed
          (field_of_bool implicit_account_creation_fee, 1)
      ; May_use_token.to_input may_use_token
      ; Authorization_kind.to_input authorization_kind
      ]

  let digest ~signature_kind (t : t) =
    Random_oracle.(
      hash
        ~init:(Hash_prefix.zkapp_body ~signature_kind)
        (pack_input (to_input t)))

  module Digested = struct
    type t = Random_oracle.Digest.t

    module Checked = struct
      type t = Random_oracle.Checked.Digest.t
    end
  end

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map public_key = Public_key.Compressed.gen
    and token_id = Token_id.gen
    and update = Update.gen ()
    and balance_change = Currency.Amount.Signed.gen
    and increment_nonce = Quickcheck.Generator.bool
    and events = return []
    and actions = return []
    and call_data = Field.gen
    and preconditions = Preconditions.gen
    and use_full_commitment = Quickcheck.Generator.bool
    and implicit_account_creation_fee = Quickcheck.Generator.bool
    and may_use_token = May_use_token.gen
    and authorization_kind = Authorization_kind.gen in
    { public_key
    ; token_id
    ; update
    ; balance_change
    ; increment_nonce
    ; events
    ; actions
    ; call_data
    ; preconditions
    ; use_full_commitment
    ; implicit_account_creation_fee
    ; may_use_token
    ; authorization_kind
    }

  let gen_with_events_and_actions =
    let open Quickcheck.Generator.Let_syntax in
    let%map public_key = Public_key.Compressed.gen
    and token_id = Token_id.gen
    and update = Update.gen ()
    and balance_change = Currency.Amount.Signed.gen
    and increment_nonce = Quickcheck.Generator.bool
    and events = return [ [| Field.zero |]; [| Field.zero |] ]
    and actions = return [ [| Field.zero |]; [| Field.zero |] ]
    and call_data = Field.gen
    and preconditions = Preconditions.gen
    and use_full_commitment = Quickcheck.Generator.bool
    and implicit_account_creation_fee = Quickcheck.Generator.bool
    and may_use_token = May_use_token.gen
    and authorization_kind = Authorization_kind.gen in
    { public_key
    ; token_id
    ; update
    ; balance_change
    ; increment_nonce
    ; events
    ; actions
    ; call_data
    ; preconditions
    ; use_full_commitment
    ; implicit_account_creation_fee
    ; may_use_token
    ; authorization_kind
    }
end

module Poly = struct
  (** This is a helper module to make writing the sexp/yojson/binable instances
      of types in this module easier. By going through this, the aux field of
      the Account_update types is properly ignored when serializing and
      deserializing.

      The to_yojson and sexp_of_t functions created with this module will ignore
      the aux field entirely when writing their respective formats. The
      of_yojson and t_of_sexp functions will expect the aux field to be absent
      when parsing. *)
  module Wire = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('body, 'authorization) t =
              ( 'body
              , 'authorization )
              Mina_wire_types.Mina_base.Account_update.Poly.V1.t =
          { body : 'body; authorization : 'authorization }
        [@@deriving yojson, sexp]
      end
    end]
  end

  (** An account update in a zkApp transaction *)
  type ('body, 'authorization, 'aux) t =
    { body : 'body; authorization : 'authorization; aux : 'aux }
  [@@deriving annot, equal, hash, compare, fields]

  let of_wire (w : _ Wire.Stable.V1.t) : _ t =
    { body = w.body; authorization = w.authorization; aux = () }

  let to_wire (t : _ t) : _ Wire.Stable.V1.t =
    { body = t.body; authorization = t.authorization }

  let to_yojson body authorization =
    Fn.compose (Wire.Stable.V1.to_yojson body authorization) to_wire

  let of_yojson body authorization =
    let of_wire' = Result.map ~f:of_wire in
    Fn.compose of_wire' (Wire.Stable.V1.of_yojson body authorization)

  let sexp_of_t body authorization =
    Fn.compose (Wire.Stable.V1.sexp_of_t body authorization) to_wire

  let t_of_sexp body authorization =
    Fn.compose of_wire (Wire.Stable.V1.t_of_sexp body authorization)
end

module T = struct
  module Without_aux = struct
    [%%versioned_binable
    module Stable = struct
      module V1 = struct
        type ('body, 'authorization) t = ('body, 'authorization, unit) Poly.t
        [@@deriving equal, hash, compare]

        [%%define_locally Poly.(to_yojson, of_yojson, sexp_of_t, t_of_sexp)]

        include
          Binable.Of_binable2_without_uuid
            (Poly.Wire.Stable.V1)
            (struct
              type nonrec ('x, 'y) t = ('x, 'y) t

              let of_binable t = Poly.of_wire t

              let to_binable = Poly.to_wire
            end)
      end
    end]
  end

  module Graphql_repr = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Body.Graphql_repr.Stable.V1.t
          , Control.Stable.V2.t )
          Without_aux.Stable.V1.t
        [@@deriving sexp, equal, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    let deriver obj =
      let open Poly in
      let open Fields_derivers_zkapps.Derivers in
      let ( !. ) ?skip_data = ( !. ) ?skip_data ~t_fields_annots in
      Fields.make_creator obj
        ~body:!.Body.Graphql_repr.deriver
        ~authorization:!.Control.deriver
        ~aux:(( !. ) ~skip_data:() skip)
      |> finish "ZkappAccountUpdate" ~t_toplevel_annots
  end

  module Simple = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          (Body.Simple.Stable.V1.t, Control.Stable.V2.t) Without_aux.Stable.V1.t
        [@@deriving sexp, equal, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      (** A account_update to a zkApp transaction *)
      type t = (Body.Stable.V1.t, Control.Stable.V2.t) Without_aux.Stable.V1.t
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  (** Auxiliary data in an [Account_update.t], not intended for serialization.
      The [to_yojson] and [sexp_of_t] instances here are written to be
      compatible with [Account_update.Poly.Without_aux.t], so that types of the
      form [(_, _, Aux_data.t) Account_update.Poly.t] can still have [@@deriving
      sexp_of, to_yojson] applied to them. *)
  module Aux_data = struct
    type t =
      { actions_hash : Field.t
            (** The cached hash of the actions in an account update body *)
      }

    let of_body ~body : t =
      let actions = Zkapp_account.Actions.of_event_list body.Body.actions in
      { actions_hash = actions.hash }
  end

  module With_aux = struct
    type ('body, 'authorization) t = ('body, 'authorization, Aux_data.t) Poly.t

    [%%define_locally Poly.(to_yojson, sexp_of_t)]
  end

  type t = (Body.t, Control.t) With_aux.t [@@deriving sexp_of, to_yojson]

  let of_graphql_repr ({ Poly.body; authorization; aux = () } : Graphql_repr.t)
      : Stable.Latest.t =
    { authorization; body = Body.of_graphql_repr body; aux = () }

  let to_graphql_repr ({ body; authorization; aux = () } : Stable.Latest.t)
      ~call_depth : Graphql_repr.t =
    { authorization; body = Body.to_graphql_repr ~call_depth body; aux = () }

  let with_no_aux ~body ~authorization : _ Poly.t =
    { body; authorization; aux = () }

  let with_aux ~body ~authorization : _ Poly.t =
    { body; authorization; aux = Aux_data.of_body ~body }

  let gen : Stable.Latest.t Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%map body = Body.gen and authorization = Control.gen_with_dummies in
    { Poly.body; authorization; aux = () }

  let gen_with_events_and_actions : Stable.Latest.t Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%map body = Body.gen_with_events_and_actions
    and authorization = Control.gen_with_dummies in
    { Poly.body; authorization; aux = () }

  let quickcheck_generator : Stable.Latest.t Quickcheck.Generator.t = gen

  let quickcheck_observer : Stable.Latest.t Quickcheck.Observer.t =
    Quickcheck.Observer.of_hash (module Stable.Latest)

  let quickcheck_shrinker : t Quickcheck.Shrinker.t =
    Quickcheck.Shrinker.empty ()

  let of_simple (p : Simple.t) : Stable.Latest.t =
    { body = Body.of_simple p.body; authorization = p.authorization; aux = () }

  let digest ~signature_kind t = Body.digest ~signature_kind t.Poly.body

  module Checked = struct
    type t = Body.Checked.t

    let digest ~signature_kind (t : t) = Body.Checked.digest ~signature_kind t
  end
end

let map_proofs ~f p =
  let map_auth = function
    | Control.Poly.Proof p ->
        Control.Poly.Proof (f p)
    | Signature s ->
        Signature s
    | None_given ->
        None_given
  in
  { Poly.authorization = map_auth p.Poly.authorization
  ; body = p.Poly.body
  ; aux = p.Poly.aux
  }

let forget_proofs p = map_proofs ~f:(const ()) p

let reset_aux (p : _ Poly.t) =
  T.with_aux ~body:p.body ~authorization:p.authorization

let forget_aux (p : _ Poly.t) = { p with aux = () }

let forget_proofs_and_aux p = forget_proofs @@ forget_aux p

module Fee_payer = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Mina_wire_types.Mina_base.Account_update.Fee_payer.V1.t =
        { body : Body.Fee_payer.Stable.V1.t
        ; authorization : Signature.Stable.V1.t
        }
      [@@deriving sexp, annot, equal, hash, compare, fields, yojson]

      let to_latest = Fn.id
    end
  end]

  let make ~body ~authorization : t = { body; authorization }

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Let_syntax in
    let%map body = Body.Fee_payer.gen in
    let authorization = Signature.dummy in
    make ~body ~authorization

  let quickcheck_generator : t Quickcheck.Generator.t = gen

  let quickcheck_observer : t Quickcheck.Observer.t =
    Quickcheck.Observer.of_hash (module Stable.Latest)

  let quickcheck_shrinker : t Quickcheck.Shrinker.t =
    Quickcheck.Shrinker.empty ()

  let account_id (t : t) : Account_id.t =
    Account_id.create t.body.public_key Token_id.default

  let to_account_update (t : t) : T.t =
    T.with_aux ~body:(Body.of_fee_payer t.body)
      ~authorization:(Control.Poly.Signature t.authorization)

  let deriver obj =
    let open Fields_derivers_zkapps.Derivers in
    let ( !. ) = ( !. ) ~t_fields_annots in
    Fields.make_creator obj ~body:!.Body.Fee_payer.deriver
      ~authorization:!.Control.signature_deriver
    |> finish "ZkappFeePayer" ~t_toplevel_annots
end

include T

let read_all_proofs_from_disk (p : t) : Stable.Latest.t =
  forget_aux @@ map_proofs ~f:Proof_cache_tag.read_proof_from_disk p

let write_all_proofs_to_disk ~proof_cache_db (p : Stable.Latest.t) : t =
  reset_aux
  @@ map_proofs ~f:(Proof_cache_tag.write_proof_to_disk proof_cache_db) p

let account_id (t : (Body.t, _, _) Poly.t) : Account_id.t =
  Account_id.create t.body.public_key t.body.token_id

let verification_key_update_to_option (t : (Body.t, _, _) Poly.t) :
    Verification_key_wire.t option Zkapp_basic.Set_or_keep.t =
  Zkapp_basic.Set_or_keep.map ~f:Option.some t.body.update.verification_key

let check_authorization (type proof aux)
    (p : (Body.t, (proof, Signature.t) Control.Poly.t, aux) Poly.t) :
    unit Or_error.t =
  match (p.authorization, p.body.authorization_kind) with
  | None_given, None_given | Proof _, Proof _ | Signature _, Signature ->
      Ok ()
  | _ ->
      let err =
        let expected =
          Authorization_kind.to_control_tag p.body.authorization_kind
        in
        let got = Control.tag p.authorization in
        Error.create "Authorization kind does not match the authorization"
          [ ("expected", expected); ("got", got) ]
          [%sexp_of: (string * Control.Tag.t) list]
      in
      Error err

let of_fee_payer_no_aux ({ body; authorization } : Fee_payer.t) :
    (Body.t, (_, Signature.t) Control.Poly.t, _) Poly.t =
  with_no_aux ~body:(Body.of_fee_payer body)
    ~authorization:(Control.Poly.Signature authorization)

let of_fee_payer t = reset_aux @@ of_fee_payer_no_aux t

(** The change in balance to apply to the target account of this account_update.
      When this is negative, the amount will be withdrawn from the account and
      made available to later zkapp_command in the same transaction.
      When this is positive, the amount will be deposited into the account from
      the funds made available by previous zkapp_command in the same transaction.
*)
let balance_change (t : t) : Amount.Signed.t = t.body.balance_change

let protocol_state_precondition (t : t) : Zkapp_precondition.Protocol_state.t =
  t.body.preconditions.network

let valid_while_precondition (t : t) :
    Mina_numbers.Global_slot_since_genesis.t Zkapp_precondition.Numeric.t =
  t.body.preconditions.valid_while

let public_key (t : t) : Public_key.Compressed.t = t.body.public_key

let token_id (t : t) : Token_id.t = t.body.token_id

let use_full_commitment t : bool = t.Poly.body.Body.use_full_commitment

let implicit_account_creation_fee (t : t) : bool =
  t.body.implicit_account_creation_fee

let increment_nonce (t : t) : bool = t.body.increment_nonce
