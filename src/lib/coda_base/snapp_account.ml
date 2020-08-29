[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
module Coda_numbers = Coda_numbers
module F = Pickles.Backend.Tick.Field

[%%else]

module Coda_numbers = Coda_numbers_nonconsensus.Coda_numbers
module Currency = Currency_nonconsensus.Currency
module Random_oracle = Random_oracle_nonconsensus.Random_oracle
open Snark_params_nonconsensus
module F = Field

[%%endif]

module Frozen_ledger_hash = Frozen_ledger_hash0
module Ledger_hash = Ledger_hash0
open Snapp_basic

module Permissions = struct
  module Controller = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          | Either
          | Verification_key
          | Private_key
          | Both (* Both and either can both be subsumed in verification key.
            It is good to have "Either" as a separate thing to spare the owner from
            having to make a proof instead of a signature. Both, I'm not sure if there's
            a good justification for. *)
        [@@deriving sexp, eq, compare, hash, yojson]

        let to_latest = Fn.id
      end
    end]

    let to_bits : t -> (unit, _) H_list.t = function
      | Either ->
          [false; false]
      | Verification_key ->
          [false; true]
      | Private_key ->
          [true; false]
      | Both ->
          [true; true]

    let to_input t =
      let [x; y] = to_bits t in
      Random_oracle.Input.bitstring [x; y]

    [%%ifdef
    consensus_mechanism]

    module Checked = struct
      type t = {verification_key: Boolean.var; private_key: Boolean.var}
      [@@deriving hlist]

      let to_input t =
        let [x; y] = to_hlist t in
        Random_oracle.Input.bitstring [x; y]
    end

    let typ =
      let t =
        Typ.of_hlistable [Boolean.typ; Boolean.typ]
          ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist
          ~value_to_hlist:Fn.id ~value_of_hlist:Fn.id
      in
      Typ.transport t ~there:to_bits ~back:(function
        | [false; false] ->
            Either
        | [false; true] ->
            Verification_key
        | [true; false] ->
            Private_key
        | [true; true] ->
            Both )

    [%%endif]
  end

  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('bool, 'controller) t =
          { stake: 'bool
          ; edit_state: 'controller
          ; send: 'controller
          ; set_delegate: 'controller }
        [@@deriving sexp, eq, compare, hash, yojson, hlist, fields]
      end
    end]

    let to_input controller t =
      let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
      Stable.Latest.Fields.fold ~init:[]
        ~stake:(f (fun x -> Random_oracle.Input.bitstring [x]))
        ~edit_state:(f controller) ~send:(f controller)
        ~set_delegate:(f controller)
      |> List.reduce_exn ~f:Random_oracle.Input.append
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = (bool, Controller.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving sexp, eq, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let to_input = Poly.to_input Controller.to_input

  [%%ifdef
  consensus_mechanism]

  module Checked = struct
    type t = (Boolean.var, Controller.Checked.t) Poly.Stable.Latest.t

    let to_input = Poly.to_input Controller.Checked.to_input
  end

  let typ =
    let open Poly.Stable.Latest in
    Typ.of_hlistable
      [Boolean.typ; Controller.typ; Controller.typ; Controller.typ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  [%%endif]
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('app_state, 'perms, 'vk) t =
        {app_state: 'app_state; permissions: 'perms; verification_key: 'vk}
      [@@deriving sexp, eq, compare, hash, yojson, hlist, fields]
    end
  end]
end

type ('app_state, 'perms, 'vk) t_ = ('app_state, 'perms, 'vk) Poly.t =
  {app_state: 'app_state; permissions: 'perms; verification_key: 'vk}

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( F.Stable.V1.t Snapp_state.Stable.V1.t
      , Permissions.Stable.V1.t
      , ( Side_loaded_verification_key.Stable.V1.t
        , F.Stable.V1.t )
        With_hash.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving sexp, eq, compare, hash, yojson]

    let to_latest = Fn.id
  end
end]

open Pickles_types

[%%ifdef
consensus_mechanism]

module Checked = struct
  type t =
    ( Pickles.Impls.Step.Field.t Snapp_state.t
    , Permissions.Checked.t
    , ( Pickles.Side_loaded.Verification_key.Checked.t
      , Pickles.Impls.Step.Field.t Set_once.t )
      With_hash.t )
    Poly.t

  let to_input (t : t) =
    let open Random_oracle.Input in
    let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
    let app_state v = Random_oracle.Input.field_elements (Vector.to_array v) in
    Poly.Fields.fold ~init:[]
      ~permissions:(f Permissions.Checked.to_input)
      ~app_state:(f app_state)
      ~verification_key:
        (f (fun x -> field (Option.value_exn (Set_once.get (With_hash.hash x)))))
    |> List.reduce_exn ~f:append
end

let typ : (Checked.t, t) Typ.t =
  let open Poly in
  Typ.of_hlistable
    [ Snapp_state.typ Field.typ
    ; Permissions.typ
    ; Typ.transport Pickles.Side_loaded.Verification_key.typ
        ~there:With_hash.data
        ~back:(With_hash.of_data ~hash_data:digest_vk)
      |> Typ.transport_var ~there:With_hash.data
           ~back:(With_hash.of_data ~hash_data:(fun _ -> Set_once.create ()))
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

[%%endif]

let digest_vk (t : Side_loaded_verification_key.t) =
  Random_oracle.(
    hash ~init:Hash_prefix.side_loaded_vk
      (pack_input (Pickles_base.Side_loaded_verification_key.to_input t)))

let to_input (t : t) =
  let open Random_oracle.Input in
  let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
  let app_state v = Random_oracle.Input.field_elements (Vector.to_array v) in
  Poly.Fields.fold ~init:[] ~permissions:(f Permissions.to_input)
    ~app_state:(f app_state)
    ~verification_key:(f (Fn.compose field With_hash.hash))
  |> List.reduce_exn ~f:append
