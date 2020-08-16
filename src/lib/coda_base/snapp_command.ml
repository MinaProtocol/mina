[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
open Signature_lib
module Coda_numbers = Coda_numbers

[%%else]

open Signature_lib_nonconsensus
module Coda_numbers = Coda_numbers_nonconsensus.Coda_numbers
module Currency = Currency_nonconsensus.Currency
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module Impl = Pickles.Impls.Step
open Coda_numbers
open Currency
open Snapp_basic
open Pickles_types
module Digest = Random_oracle.Digest
module Predicate = Snapp_predicate

(* TODO: One invariant that needs to be checked is

   If the fee payer is `Other { pk; _ }, this account should in fact
   be distinct from the other accounts.  *)

module Per_account = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('field, 'pk) t =
          {state: 'field Snapp_state.Stable.V1.t; delegate: 'pk}
        [@@deriving compare, eq, sexp, hash, yojson, hlist]
      end
    end]
  end

  type ('field, 'pk) t_ = {state: 'field Snapp_state.t; delegate: 'pk}

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( F.Stable.V1.t Set_or_keep.Stable.V1.t
        , Public_key.Compressed.Stable.V1.t Set_or_keep.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving compare, eq, sexp, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t

  let to_input ({state; delegate} : t) =
    let open Random_oracle_input in
    List.reduce_exn ~f:append
      ( List.map (Vector.to_list state)
          ~f:(Set_or_keep.to_input ~dummy:F.zero ~f:field)
      @ [ Set_or_keep.to_input
            ~dummy:(Lazy.force invalid_public_key)
            ~f:Public_key.Compressed.to_input delegate ] )

  module Checked = struct
    type t =
      ( Field.Var.t Set_or_keep.Checked.t
      , Public_key.Compressed.var Set_or_keep.Checked.t )
      Poly.Stable.Latest.t

    let to_input ({state; delegate} : t) =
      let open Random_oracle_input in
      List.reduce_exn ~f:append
        ( List.map (Vector.to_list state)
            ~f:(Set_or_keep.Checked.to_input ~f:field)
        @ [ Set_or_keep.Checked.to_input
              ~f:Public_key.Compressed.Checked.to_input delegate ] )
  end

  let typ () : (Checked.t, t) Typ.t =
    let open Poly.Stable.Latest in
    Typ.of_hlistable
      [ Snapp_state.typ (Set_or_keep.Checked.typ ~dummy:Field.zero Field.typ)
      ; Set_or_keep.typ
          ~dummy:(Lazy.force invalid_public_key)
          Public_key.Compressed.typ ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Union_payload = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        (* TODO: Don't assume they keep their balance in the same token. *)
        type ('signed_amount, 'update) t =
          { self_delta: 'signed_amount
          ; other_delta: 'signed_amount
          ; self_update: 'update
          ; other_update: 'update }
        [@@deriving hlist]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( (Amount.Stable.V1.t, Sgn.Stable.V1.t) Currency.Signed_poly.Stable.V1.t
        , Per_account.Stable.V1.t )
        Poly.Stable.V1.t

      let to_latest = Fn.id
    end
  end]

  module Checked = struct
    type t =
      (Currency.Amount.Signed.var, Per_account.Checked.t) Poly.Stable.Latest.t
  end

  let typ () : (Checked.t, Stable.Latest.t) Typ.t =
    let open Poly.Stable.Latest in
    Typ.of_hlistable
      [ Amount.Signed.typ
      ; Amount.Signed.typ
      ; Per_account.typ ()
      ; Per_account.typ () ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Control = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Proof of Pickles.Side_loaded.Proof.Stable.V1.t
        | Signature of Signature.Stable.V1.t
        | Both of
            { signature: Pickles.Side_loaded.Proof.Stable.V1.t
            ; proof: Signature.Stable.V1.t }
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]
end

module Fee_payment = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t =
        {fee: Fee.Stable.V1.t; token_id: Token_id.Stable.V1.t; payer: 'a}
      [@@deriving sexp, eq, yojson, hash, compare]
    end
  end]

  type 'a t = 'a Stable.Latest.t
end

module Snapp_body = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { pk: Public_key.Compressed.Stable.V1.t
        ; control: Control.Stable.V1.t
        ; update: Per_account.Stable.V1.t
        ; predicate: Predicate.Stable.V1.t }
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t
end

module Other_fee_payer = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { pk: Public_key.Compressed.Stable.V1.t
        ; nonce: Coda_numbers.Account_nonce.Stable.V1.t
        ; signature: Signature.Stable.V1.t }
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]
end

module Snapp_creation_data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* TODO: Should have option of including timing here. *)
      type t =
        { snapp: Snapp_account.Stable.V1.t
        ; pk: Public_key.Compressed.Stable.V1.t }
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  module V1 = struct
    (* TODO: The snapp and user token IDs should be able to be different from the user's. Otherwise
      it is very hard to use snapp accounts with other token IDs! *)
    type t =
      | Snapp_snapp of
          { snapp1: Snapp_body.Stable.V1.t
          ; snapp2: Snapp_body.Stable.V1.t
          ; sender: [`Snapp1 | `Snapp2]
          ; snapp1_base_delta: Amount.Stable.V1.t
          ; fee_payment:
              [`Snapp | `Other of Other_fee_payer.Stable.V1.t]
              Fee_payment.Stable.V1.t }
      | Snapp of
          { snapp: Snapp_body.Stable.V1.t
          ; fee_payment:
              [`Snapp | `Other of Other_fee_payer.Stable.V1.t]
              Fee_payment.Stable.V1.t }
      | User_to_snapp of
          { user_pk: Public_key.Compressed.Stable.V1.t
          ; user_signature: Signature.Stable.V1.t
          ; user_nonce: Coda_numbers.Account_nonce.Stable.V1.t
          ; amount: Currency.Amount.Stable.V1.t
          ; fee_payment:
              [`User | `Other of Other_fee_payer.Stable.V1.t]
              Fee_payment.Stable.V1.t
          ; snapp:
              [ `Update of Snapp_body.Stable.V1.t
              | `Create of Snapp_creation_data.Stable.V1.t ] }
      | Snapp_to_user of
          { user_pk: Public_key.Compressed.Stable.V1.t
          ; snapp: Snapp_body.Stable.V1.t
          ; amount: Currency.Amount.Stable.V1.t
          ; fee_payment:
              [`Snapp | `Other of Other_fee_payer.Stable.V1.t]
              Fee_payment.Stable.V1.t }
    [@@deriving sexp, eq, yojson, hash, compare]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t [@@deriving sexp, eq, yojson, hash, compare]

(* This type is used for hashing the snapp commands when they go into the receipt chain hash,
   and for signing snapp commands.
*)
module Payload = struct
  module Snapp_init = struct
    module Poly = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type ('vk, 'perms) t = {vk_digest: 'vk; permissions: 'perms}
          [@@deriving sexp, eq, yojson, hash, compare]

          let to_latest = Fn.id
        end
      end]
    end

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( F.Stable.V1.t
          , Snapp_account.Permissions.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving sexp, eq, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t

    let to_input ({vk_digest; permissions} : t) =
      Random_oracle_input.(append (field vk_digest))
        (Snapp_account.Permissions.to_input permissions)

    let dummy : t =
      { vk_digest= Field.zero
      ; permissions=
          {stake= false; edit_state= Both; send= Both; set_delegate= Both} }

    module Checked = struct
      type t =
        ( Impl.Field.t
        , Snapp_account.Permissions.Checked.t )
        Poly.Stable.Latest.t

      let to_input ({vk_digest; permissions} : t) =
        Random_oracle_input.(append (field vk_digest))
          (Snapp_account.Permissions.Checked.to_input permissions)
    end
  end

  module Per_snapp = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('predicate_digests, 'pubkey, 'account_update, 'amount) t =
          { predicate: 'predicate_digests
          ; update: 'account_update
          ; pk: 'pubkey
          ; delta: 'amount }
        [@@deriving hlist, sexp, eq, yojson, hash, compare]
      end
    end]

    let to_input ~delta:delta_to_input
        {Stable.Latest.predicate; update; pk; delta} =
      let open Random_oracle.Input in
      List.reduce_exn ~f:append
        [ Predicate.Digested.to_input predicate
        ; Per_account.to_input update
        ; Public_key.Compressed.to_input pk
        ; delta_to_input delta ]

    module Checked = struct
      let to_input ~delta:delta_to_input
          {Stable.Latest.predicate; update; pk; delta} =
        let open Random_oracle.Input in
        List.reduce_exn ~f:append
          [ Predicate.Digested.Checked.to_input predicate
          ; Per_account.Checked.to_input update
          ; Public_key.Compressed.Checked.to_input pk
          ; delta_to_input delta ]
    end
  end

  module From_user = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('pubkey, 'nonce) t = {pk: 'pubkey; nonce: 'nonce}
        [@@deriving hlist, sexp, eq, yojson, hash, compare]
      end
    end]

    type ('pubkey, 'nonce) t = ('pubkey, 'nonce) Stable.Latest.t =
      {pk: 'pubkey; nonce: 'nonce}

    let to_input ({pk; nonce} : _ Stable.Latest.t) =
      List.reduce_exn ~f:Random_oracle_input.append
        [Public_key.Compressed.to_input pk; Account_nonce.to_input nonce]

    module Checked = struct
      type t =
        ( Public_key.Compressed.var
        , Coda_numbers.Account_nonce.Checked.t )
        Stable.Latest.t

      let to_input ({pk; nonce} : t) =
        List.reduce_exn ~f:Random_oracle_input.append
          [ Public_key.Compressed.Checked.to_input pk
          ; Impl.run_checked (Account_nonce.Checked.to_input nonce) ]
    end
  end

  module Tag = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          | Snapp_snapp
          | Snapp
          | User_to_snapp
          | Create_snapp
          | Snapp_to_user
        [@@deriving enum, sexp, eq, compare]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t =
      | Snapp_snapp
      | Snapp
      | User_to_snapp
      | Create_snapp
      | Snapp_to_user

    let gen =
      Quickcheck.Generator.(
        map (Int.gen_incl Stable.V1.min Stable.V1.max) ~f:(fun x ->
            Option.value_exn (Stable.V1.of_enum x) ))

    let length = Int.ceil_log2 (1 + Stable.V1.max)

    let int_to_bits x = List.init length ~f:(fun i -> (x lsr i) land 1 = 1)

    let int_of_bits =
      List.foldi ~init:0 ~f:(fun i acc b ->
          if b then acc lor (1 lsl i) else acc )

    let to_bits = Fn.compose int_to_bits Stable.Latest.to_enum

    let of_bits = Fn.compose Stable.Latest.of_enum int_of_bits

    let%test_unit "tag bits" =
      Quickcheck.test gen ~f:(fun x ->
          [%test_eq: Stable.Latest.t option] (Some x) (of_bits (to_bits x)) )

    let to_input = Fn.compose Random_oracle_input.bitstring to_bits

    module Checked = struct
      open Pickles.Impls.Step

      type t = Boolean.var list

      let typ : (t, Stable.Latest.t) Typ.t =
        Typ.transport (Typ.list ~length Boolean.typ) ~there:to_bits
          ~back:(fun x -> Option.value_exn (of_bits x))

      let to_input : t -> _ = Random_oracle_input.bitstring
    end
  end

  module One_snapp = struct
    module Poly = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type ( 'tag
               , 'fee
               , 'token_id
               , 'snapp
               , 'user_opt
               , 'snapp_init_opt
               , 'nonce_opt )
               t =
            { tag: 'tag
            ; fee: 'fee
            ; token_id: 'token_id
            ; fee_payer_nonce_opt: 'nonce_opt
            ; snapp: 'snapp
            ; user_opt: 'user_opt
            ; snapp_init_opt: 'snapp_init_opt }
          [@@deriving hlist, sexp, eq, yojson, hash, compare]
        end
      end]
    end
  end

  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ( 'predicates
             , 'pubkey
             , 'account_update
             , 'amount
             , 'signed_amount
             , 'token_id
             , 'fee
             , 'nonce_opt
             , 'from_user
             , 'snapp_init
             , 'tag )
             t =
          | Two_snapp of
              { snapp1:
                  ( 'predicates
                  , 'pubkey
                  , 'account_update
                  , 'signed_amount )
                  Per_snapp.Stable.V1.t
              ; snapp2:
                  ( 'predicates
                  , 'pubkey
                  , 'account_update
                  , 'signed_amount )
                  Per_snapp.Stable.V1.t
              ; fee: 'fee
              ; token_id: 'token_id
              ; fee_payer_nonce_opt: 'nonce_opt }
          | One_snapp of
              ( 'tag
              , 'fee
              , 'token_id
              , ( 'predicates
                , 'pubkey
                , 'account_update
                , 'amount )
                Per_snapp.Stable.V1.t
              , 'from_user
              , 'snapp_init
              , 'nonce_opt )
              One_snapp.Poly.Stable.V1.t
        [@@deriving sexp, eq, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]
  end

  module T = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( ( Predicate.Stable.V1.t
            , Predicate.Digested.Stable.V1.t )
            With_hash.Stable.V1.t
          (* account predicate hash *)
          , Public_key.Compressed.Stable.V1.t
          , Per_account.Stable.V1.t
          , Amount.Stable.V1.t
          , ( Amount.Stable.V1.t
            , Sgn.Stable.V1.t )
            Currency.Signed_poly.Stable.V1.t
          , Token_id.Stable.V1.t
          , Fee.Stable.V1.t
          , Account_nonce.Stable.V1.t option
          , ( Public_key.Compressed.Stable.V1.t
            , Coda_numbers.Account_nonce.Stable.V1.t )
            From_user.Stable.V1.t
            option
          , Snapp_init.Stable.V1.t option
          , Tag.Stable.V1.t )
          Poly.Stable.V1.t

        let to_latest = Fn.id
      end
    end]
  end

  module Stable = struct
    module V1 = struct
      include T.Stable.V1

      (* While they are not implemented, we make snapp commands un-serializable. *)
      include Binable.Of_binable
                (T.Stable.V1)
                (struct
                  include T.Stable.V1

                  let to_binable _ =
                    failwith "Serialization of snapp commands disabled"

                  let of_binable _ =
                    failwith "Serialization of snapp commands disabled"
                end)
    end

    module Latest = V1
  end

  type t = Stable.Latest.t

  let to_input (t : t) =
    let open Random_oracle_input in
    let f = List.reduce_exn ~f:append in
    let s (p : _ Per_snapp.Stable.Latest.t) =
      {p with predicate= With_hash.hash p.predicate}
    in
    match t with
    | Two_snapp {snapp1; snapp2; fee; token_id; fee_payer_nonce_opt} ->
        f
          [ Per_snapp.to_input ~delta:Amount.Signed.to_input (s snapp1)
          ; Per_snapp.to_input ~delta:Amount.Signed.to_input (s snapp2)
          ; Fee.to_input fee
          ; Token_id.to_input token_id
          ; Account_nonce.to_input
              (Option.value fee_payer_nonce_opt ~default:Account_nonce.zero) ]
    | One_snapp
        { tag
        ; fee
        ; fee_payer_nonce_opt
        ; token_id
        ; snapp
        ; user_opt
        ; snapp_init_opt } ->
        f
          [ Tag.to_input tag
          ; Fee.to_input fee
          ; Token_id.to_input token_id
          ; Per_snapp.to_input ~delta:Amount.to_input (s snapp)
          ; From_user.to_input
              (Option.value user_opt
                 ~default:
                   { pk= Lazy.force invalid_public_key
                   ; nonce= Account_nonce.zero })
          ; Snapp_init.to_input
              (Option.value snapp_init_opt ~default:Snapp_init.dummy)
          ; Account_nonce.to_input
              (Option.value fee_payer_nonce_opt ~default:Account_nonce.zero) ]

  let digest t =
    Random_oracle.(
      hash ~init:Hash_prefix.snapp_payload (pack_input (to_input t)))

  module Checked = struct
    open Pickles.Impls.Step

    type t =
      ( (Predicate.Checked.t, Predicate.Digested.Checked.t) With_hash.t
      , Public_key.Compressed.var
      , Per_account.Checked.t
      , Amount.var
      , Amount.Signed.var
      , Token_id.var
      , Fee.var
      , Account_nonce.Checked.t
      , From_user.Checked.t
      , Snapp_init.Checked.t
      , Tag.Checked.t )
      Poly.Stable.Latest.t

    let to_input (t : t) =
      let open Random_oracle_input in
      let s (p : _ Per_snapp.Stable.Latest.t) =
        {p with predicate= With_hash.hash p.predicate}
      in
      let f = List.reduce_exn ~f:append in
      match t with
      | Two_snapp {snapp1; snapp2; fee; token_id; fee_payer_nonce_opt} ->
          f
            [ Per_snapp.Checked.to_input ~delta:Amount.Signed.Checked.to_input
                (s snapp1)
            ; Per_snapp.Checked.to_input ~delta:Amount.Signed.Checked.to_input
                (s snapp2)
            ; Fee.var_to_input fee
            ; Impl.run_checked (Token_id.Checked.to_input token_id)
            ; Impl.run_checked
                (Account_nonce.Checked.to_input fee_payer_nonce_opt) ]
      | One_snapp
          { tag
          ; fee
          ; fee_payer_nonce_opt
          ; token_id
          ; snapp
          ; user_opt
          ; snapp_init_opt } ->
          f
            [ Tag.Checked.to_input tag
            ; Fee.var_to_input fee
            ; Impl.run_checked (Token_id.Checked.to_input token_id)
            ; Per_snapp.Checked.to_input ~delta:Amount.var_to_input (s snapp)
            ; From_user.Checked.to_input user_opt
            ; Snapp_init.Checked.to_input snapp_init_opt
            ; Impl.run_checked
                (Account_nonce.Checked.to_input fee_payer_nonce_opt) ]
  end
end

module Valid : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = (* private *) Stable.V1.t
      [@@deriving sexp, eq, yojson, hash, compare]
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, yojson, hash, compare, eq]
end = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Stable.V1.t [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Stable.V1.to_latest
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, yojson, hash, compare, eq]
end

let fee_payment (t : t) : Account_id.t Fee_payment.t =
  let mk (p : _ Fee_payment.t) pk =
    {p with payer= Account_id.create pk p.token_id}
  in
  match t with
  | Snapp_snapp {fee_payment; sender; snapp1; snapp2; _} ->
      mk fee_payment
        ( match fee_payment.payer with
        | `Snapp ->
            (match sender with `Snapp1 -> snapp1 | `Snapp2 -> snapp2).pk
        | `Other {pk; _} ->
            pk )
  | Snapp {fee_payment; snapp; _} ->
      mk fee_payment
        ( match fee_payment.payer with
        | `Other {pk; _} ->
            pk
        | `Snapp ->
            snapp.pk )
  | User_to_snapp {fee_payment; user_pk; _} ->
      mk fee_payment
        (match fee_payment.payer with `User -> user_pk | `Other {pk; _} -> pk)
  | Snapp_to_user {fee_payment; snapp; _} ->
      mk fee_payment
        ( match fee_payment.payer with
        | `Other {pk; _} ->
            pk
        | `Snapp ->
            snapp.pk )

let fee_token (t : t) : Token_id.t = (fee_payment t).token_id

let accounts_accessed t =
  let tok = fee_token t in
  let id k = Account_id.create k tok in
  (fee_payment t).payer
  ::
  ( match t with
  | Snapp_snapp {snapp1; snapp2; _} ->
      [id snapp1.pk; id snapp2.pk]
  | Snapp {snapp; _} ->
      [id snapp.pk]
  | User_to_snapp {user_pk; snapp; _} ->
      [ id user_pk
      ; id (match snapp with `Update s -> s.pk | `Create s -> s.pk) ]
  | Snapp_to_user {snapp; user_pk; _} ->
      [id user_pk; id snapp.pk] )

let fee (t : t) : Fee.t = (fee_payment t).fee

let fee_excess (t : t) : Fee_excess.t =
  Fee_excess.of_single (fee_token t, Currency.Fee.Signed.of_unsigned (fee t))

let next_available_token (_ : t) (next_available : Token_id.t) =
  (* TODO: Update when snapp account creation is implemented. *)
  next_available

let to_payload (t : t) : Payload.t option =
  let open Payload.Poly.Stable.Latest in
  let open Option.Let_syntax in
  let p = With_hash.of_data ~hash_data:Predicate.digest in
  let s ({pk; control= _; update; predicate} : Snapp_body.t) delta :
      _ Payload.Per_snapp.Stable.Latest.t =
    {predicate= p predicate; update; pk; delta}
  in
  match t with
  | Snapp_snapp {snapp1; snapp2; sender; snapp1_base_delta; fee_payment} ->
      let%map m1, fee_payer_nonce_opt =
        match fee_payment.payer with
        | `Other fp ->
            return (snapp1_base_delta, Some fp.nonce)
        | `Snapp ->
            let%map m = Amount.add_fee snapp1_base_delta fee_payment.fee in
            (m, None)
      in
      let delta1, delta2 =
        let cswap =
          match sender with `Snapp1 -> Fn.id | `Snapp2 -> Tuple2.swap
        in
        let a magnitude (sgn : Sgn.t) = Amount.Signed.create ~magnitude ~sgn in
        cswap (a m1 Neg, a snapp1_base_delta Pos)
      in
      Two_snapp
        { snapp1= s snapp1 delta1
        ; snapp2= s snapp2 delta2
        ; fee= fee_payment.fee
        ; token_id= fee_payment.token_id
        ; fee_payer_nonce_opt }
  | Snapp {snapp; fee_payment} ->
      let delta, fee_payer_nonce_opt =
        match fee_payment.payer with
        | `Other fp ->
            (Amount.zero, Some fp.nonce)
        | `Snapp ->
            (Amount.of_fee fee_payment.fee, None)
      in
      return
        (One_snapp
           { tag= Payload.Tag.Snapp
           ; fee= fee_payment.fee
           ; fee_payer_nonce_opt
           ; token_id= fee_payment.token_id
           ; snapp= s snapp delta
           ; user_opt= None
           ; snapp_init_opt= None })
  | User_to_snapp
      {user_pk; user_signature= _; user_nonce; snapp; fee_payment; amount} ->
      let tag, snapp, snapp_init_opt =
        match snapp with
        | `Update snapp ->
            (Payload.Tag.User_to_snapp, snapp, None)
        | `Create {pk; snapp= {app_state; permissions; verification_key}} ->
            (* TODO: VK and permissions *)
            ( Payload.Tag.Create_snapp
            , { pk
              ; control= Signature Signature.dummy (* Not used. *)
              ; predicate= Predicate.accept
              ; update=
                  { state= Vector.map app_state ~f:(fun x -> Set_or_keep.Set x)
                  ; delegate= Set pk } }
            , Some
                ( {permissions; vk_digest= verification_key.hash}
                  : Payload.Snapp_init.t ) )
      in
      let fee_payer_nonce_opt =
        match fee_payment.payer with
        | `User ->
            None
        | `Other {nonce; _} ->
            Some nonce
      in
      return
        (One_snapp
           { tag
           ; fee= fee_payment.fee
           ; token_id= fee_payment.token_id
           ; snapp= s snapp amount
           ; snapp_init_opt
           ; fee_payer_nonce_opt
           ; user_opt= Some {Payload.From_user.pk= user_pk; nonce= user_nonce}
           })
  | Snapp_to_user {user_pk; snapp; amount; fee_payment} ->
      let%map delta, fee_payer_nonce_opt =
        match fee_payment.payer with
        | `Other {pk= _; signature= _; nonce} ->
            return (amount, Some nonce)
        | `Snapp ->
            let%map x = Amount.add_fee amount fee_payment.fee in
            (x, None)
      in
      One_snapp
        { tag= Payload.Tag.Snapp_to_user
        ; fee_payer_nonce_opt
        ; fee= fee_payment.fee
        ; token_id= fee_payment.token_id
        ; snapp= s snapp delta
        ; snapp_init_opt= None
        ; user_opt=
            Some {Payload.From_user.pk= user_pk; nonce= Account_nonce.zero} }
