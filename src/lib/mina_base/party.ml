[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
open Signature_lib
module Mina_numbers = Mina_numbers

[%%else]

open Signature_lib_nonconsensus
module Mina_numbers = Mina_numbers_nonconsensus.Mina_numbers
module Currency = Currency_nonconsensus.Currency
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module Impl = Pickles.Impls.Step
open Mina_numbers
open Currency
open Pickles_types
module Digest = Random_oracle.Digest

module type Type = sig
  type t
end

module Update = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('state_element, 'pk, 'vk, 'perms) t =
          { app_state: 'state_element Snapp_state.V.Stable.V1.t
          ; delegate: 'pk
          ; verification_key: 'vk
          ; permissions: 'perms }
        [@@deriving compare, eq, sexp, hash, yojson, hlist]
      end
    end]
  end

  open Snapp_basic

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( F.Stable.V1.t Set_or_keep.Stable.V1.t
        , Public_key.Compressed.Stable.V1.t Set_or_keep.Stable.V1.t
        , ( Pickles.Side_loaded.Verification_key.Stable.V1.t
          , F.Stable.V1.t )
          With_hash.Stable.V1.t
          Set_or_keep.Stable.V1.t
        , Permissions.Stable.V1.t Set_or_keep.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving compare, eq, sexp, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  module Checked = struct
    open Pickles.Impls.Step

    type t =
      ( Field.t Set_or_keep.Checked.t
      , Public_key.Compressed.var Set_or_keep.Checked.t
      , Field.t Set_or_keep.Checked.t
      , Permissions.Checked.t Set_or_keep.Checked.t )
      Poly.t

    let to_input ({app_state; delegate; verification_key; permissions} : t) =
      let open Random_oracle_input in
      List.reduce_exn ~f:append
        [ Snapp_state.to_input app_state
            ~f:(Set_or_keep.Checked.to_input ~f:field)
        ; Set_or_keep.Checked.to_input delegate
            ~f:Public_key.Compressed.Checked.to_input
        ; Set_or_keep.Checked.to_input verification_key ~f:field
        ; Set_or_keep.Checked.to_input permissions
            ~f:Permissions.Checked.to_input ]
  end

  let dummy : t =
    { app_state=
        Vector.init Snapp_state.Max_state_size.n ~f:(fun _ -> Set_or_keep.Keep)
    ; delegate= Keep
    ; verification_key= Keep
    ; permissions= Keep }

  let to_input ({app_state; delegate; verification_key; permissions} : t) =
    let open Random_oracle_input in
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
          ~f:Permissions.to_input ]

  let typ () : (Checked.t, t) Typ.t =
    let open Poly in
    let open Pickles.Impls.Step in
    Typ.of_hlistable
      [ Snapp_state.typ (Set_or_keep.typ ~dummy:Field.Constant.zero Field.typ)
      ; Set_or_keep.typ ~dummy:Public_key.Compressed.empty
          Public_key.Compressed.typ
      ; Set_or_keep.typ ~dummy:Field.Constant.zero Field.typ
        |> Typ.transport
             ~there:(Set_or_keep.map ~f:With_hash.hash)
             ~back:(Set_or_keep.map ~f:(fun _ -> failwith "vk typ"))
      ; Set_or_keep.typ ~dummy:Permissions.user_default Permissions.typ ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
end

module Body = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('pk, 'update, 'token_id, 'signed_amount) t =
          {pk: 'pk; update: 'update; token_id: 'token_id; delta: 'signed_amount}
        [@@deriving hlist, sexp, eq, yojson, hash, compare]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Public_key.Compressed.Stable.V1.t
        , Update.Stable.V1.t
        , Token_id.Stable.V1.t
        , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  module Checked = struct
    type t =
      ( Public_key.Compressed.var
      , Update.Checked.t
      , Token_id.Checked.t
      , Amount.Signed.var )
      Poly.t

    let to_input ({pk; update; token_id; delta} : t) =
      List.reduce_exn ~f:Random_oracle_input.append
        [ Public_key.Compressed.Checked.to_input pk
        ; Update.Checked.to_input update
        ; Impl.run_checked (Token_id.Checked.to_input token_id)
        ; Amount.Signed.Checked.to_input delta ]

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
      ; Amount.Signed.typ ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let dummy : t =
    { pk= Public_key.Compressed.empty
    ; update= Update.dummy
    ; token_id= Token_id.default
    ; delta= Amount.Signed.zero }

  let to_input ({pk; update; token_id; delta} : t) =
    List.reduce_exn ~f:Random_oracle_input.append
      [ Public_key.Compressed.to_input pk
      ; Update.to_input update
      ; Token_id.to_input token_id
      ; Amount.Signed.to_input delta ]

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
        | Full of Snapp_predicate.Account.Stable.V1.t
        | Nonce of Account.Nonce.Stable.V1.t
        | Accept
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let typ () : (Snapp_predicate.Account.Checked.t, t) Typ.t =
    Typ.transport
      (Snapp_predicate.Account.typ ())
      ~there:(function
        | Full s ->
            s
        | Nonce n ->
            { Snapp_predicate.Account.accept with
              nonce= Check {lower= n; upper= n} }
        | Accept ->
            Snapp_predicate.Account.accept )
      ~back:(fun s -> Full s)
end

module Predicated = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('body, 'predicate) t = {body: 'body; predicate: 'predicate}
        [@@deriving hlist, sexp, eq, yojson, hash, compare]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = (Body.Stable.V1.t, Predicate.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let typ () : (_, t) Typ.t =
    let open Poly in
    Typ.of_hlistable
      [Body.typ (); Predicate.typ ()]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  module Proved = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          (Body.Stable.V1.t, Snapp_predicate.Stable.V1.t) Poly.Stable.V1.t
        [@@deriving sexp, eq, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    module Digested = struct
      type t = (Body.Digested.t, Snapp_predicate.Digested.t) Poly.t

      module Checked = struct
        type t = (Body.Digested.Checked.t, Field.Var.t) Poly.t
      end
    end
  end

  module Signed = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = (Body.Stable.V1.t, Account_nonce.Stable.V1.t) Poly.Stable.V1.t
        [@@deriving sexp, eq, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    let to_input ?protocol_state ({body; predicate= nonce} : t) =
      List.reduce_exn ~f:Random_oracle_input.append
        ( [Body.to_input body; Account.Nonce.to_input nonce]
        @ Option.(
            to_list
              (map protocol_state ~f:Snapp_predicate.Protocol_state.to_input))
        )

    module Digested = struct
      type t = (Body.Digested.t, Account_nonce.t) Poly.t

      module Checked = struct
        type t = (Body.Digested.Checked.t, Account_nonce.Checked.t) Poly.t
      end
    end

    module Checked = struct
      type t = (Body.Checked.t, Account_nonce.Checked.t) Poly.t
    end

    let dummy : t = {body= Body.dummy; predicate= Account_nonce.zero}
  end

  module Empty = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = (Body.Stable.V1.t, unit) Poly.Stable.V1.t
        [@@deriving sexp, eq, yojson, hash, compare]

        let to_latest = Fn.id
      end
    end]

    let dummy : t = {body= Body.dummy; predicate= ()}

    let create body : t = {body; predicate= ()}
  end
end

module Poly (Data : Type) (Auth : Type) = struct
  type t = {data: Data.t; authorization: Auth.t}
end

module Proved = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
            Poly(Predicated.Proved.Stable.V1)
              (Pickles.Side_loaded.Proof.Stable.V1)
            .t =
        { data: Predicated.Proved.Stable.V1.t
        ; authorization: Pickles.Side_loaded.Proof.Stable.V1.t }
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]
end

module Signed = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Poly(Predicated.Signed.Stable.V1)(Signature.Stable.V1).t =
        { data: Predicated.Signed.Stable.V1.t
        ; authorization: Signature.Stable.V1.t }
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let account_id (t : t) : Account_id.t =
    Account_id.create t.data.body.pk t.data.body.token_id

  let create ?protocol_state ~private_key (t : Predicated.Signed.t) : t =
    let s =
      Schnorr.sign private_key (Predicated.Signed.to_input ?protocol_state t)
    in
    {authorization= s; data= t}
end

module Empty = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Poly(Predicated.Empty.Stable.V1)(Unit.Stable.V1).t =
        {data: Predicated.Empty.Stable.V1.t; authorization: unit}
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Poly(Predicated.Stable.V1)(Control.Stable.V1).t =
      {data: Predicated.Stable.V1.t; authorization: Control.Stable.V1.t}
    [@@deriving sexp, eq, yojson, hash, compare]

    let to_latest = Fn.id
  end
end]

let account_id (t : t) : Account_id.t =
  Account_id.create t.data.body.pk t.data.body.token_id

let of_signed ({data; authorization} : Signed.t) : t =
  { authorization= Signature authorization
  ; data= {data with predicate= Nonce data.predicate} }

(*

let account_id (t : ((Body.t, _) Predicated.Poly.t, _) Poly.t) : Account_id.t =
  Account_id.create t.data.body.pk t.data.body.token_id
*)
