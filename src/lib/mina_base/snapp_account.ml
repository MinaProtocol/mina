[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Snark_params.Tick
module Mina_numbers = Mina_numbers
module Hash_prefix_states = Hash_prefix_states

[%%else]

module Mina_numbers = Mina_numbers_nonconsensus.Mina_numbers
module Currency = Currency_nonconsensus.Currency
module Random_oracle = Random_oracle_nonconsensus.Random_oracle
module Hash_prefix_states = Hash_prefix_states_nonconsensus.Hash_prefix_states
open Snark_params_nonconsensus

[%%endif]

open Snapp_basic

module Events = struct
  module Event = struct
    (* Arbitrary hash input, encoding determined by the snapp's developer. *)
    type t = Field.t array

    let hash (x : t) = Random_oracle.hash ~init:Hash_prefix_states.snapp_event x

    [%%ifdef consensus_mechanism]

    type var = Field.Var.t array

    let hash_var (x : Field.Var.t array) =
      Random_oracle.Checked.hash ~init:Hash_prefix_states.snapp_event x

    [%%endif]
  end

  type t = Event.t list

  let empty_hash = lazy Random_oracle.(salt "MinaSnappEventsEmpty" |> digest)

  let push_hash acc hash =
    Random_oracle.hash ~init:Hash_prefix_states.snapp_events [| acc; hash |]

  let push_event acc event = push_hash acc (Event.hash event)

  let hash (x : t) = List.fold ~init:(Lazy.force empty_hash) ~f:push_event x

  let to_input (x : t) = Random_oracle_input.field (hash x)

  [%%ifdef consensus_mechanism]

  type var = t Data_as_hash.t

  let var_to_input (x : var) = Data_as_hash.to_input x

  let typ = Data_as_hash.typ ~hash

  let is_empty_var (e : var) =
    Snark_params.Tick.Field.(
      Checked.equal (Data_as_hash.hash e) (Var.constant (Lazy.force empty_hash)))

  let pop_checked (events : var) : Event.t Data_as_hash.t * var =
    let open Run in
    let hd, tl =
      exists
        Typ.(Data_as_hash.typ ~hash:Event.hash * typ)
        ~compute:(fun () ->
          match As_prover.read typ events with
          | [] ->
              failwith "Attempted to pop an empty stack"
          | event :: events ->
              (event, events))
    in
    Field.Assert.equal
      (Random_oracle.Checked.hash ~init:Hash_prefix_states.snapp_events
         [| Data_as_hash.hash tl; Data_as_hash.hash hd |])
      (Data_as_hash.hash events) ;
    (hd, tl)

  let push_checked (events : var) (e : Event.var) : var =
    let open Run in
    let res =
      exists typ ~compute:(fun () ->
          let tl = As_prover.read typ events in
          let hd =
            As_prover.read (Typ.array ~length:(Array.length e) Field.typ) e
          in
          hd :: tl)
    in
    Field.Assert.equal
      (Random_oracle.Checked.hash ~init:Hash_prefix_states.snapp_events
         [| Data_as_hash.hash events; Event.hash_var e |])
      (Data_as_hash.hash res) ;
    res

  [%%endif]
end

module Rollup_events = struct
  let empty_hash = lazy Random_oracle.(salt "MinaSnappRollupEmpty" |> digest)

  let push_hash acc hash =
    Random_oracle.hash ~init:Hash_prefix_states.snapp_sequence_events
      [| acc; hash |]

  let push_events acc events = push_hash acc (Events.hash events)

  [%%ifdef consensus_mechanism]

  let push_events_checked x (e : Events.var) =
    Random_oracle.Checked.hash ~init:Hash_prefix_states.snapp_sequence_events
      [| x; Data_as_hash.hash e |]

  [%%endif]
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('app_state, 'vk, 'snapp_version, 'field, 'slot, 'bool) t =
        { app_state : 'app_state
        ; verification_key : 'vk
        ; snapp_version : 'snapp_version
        ; rollup_state : 'field Pickles_types.Vector.Vector_5.Stable.V1.t
        ; last_rollup_slot : 'slot
        ; proved_state : 'bool
        }
      [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
    end

    module V1 = struct
      type ('app_state, 'vk) t =
        { app_state : 'app_state; verification_key : 'vk }
      [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
    end
  end]
end

type ('app_state, 'vk, 'snapp_version, 'field, 'slot, 'bool) t_ =
      ('app_state, 'vk, 'snapp_version, 'field, 'slot, 'bool) Poly.t =
  { app_state : 'app_state
  ; verification_key : 'vk
  ; snapp_version : 'snapp_version
  ; rollup_state : 'field Pickles_types.Vector.Vector_5.t
  ; last_rollup_slot : 'slot
  ; proved_state : 'bool
  }

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      ( Snapp_state.Value.Stable.V1.t
      , ( Side_loaded_verification_key.Stable.V1.t
        , F.Stable.V1.t )
        With_hash.Stable.V1.t
        option
      , Mina_numbers.Snapp_version.Stable.V1.t
      , F.Stable.V1.t
      , Mina_numbers.Global_slot.Stable.V1.t
      , bool )
      Poly.Stable.V2.t
    [@@deriving sexp, equal, compare, hash, yojson]

    let to_latest = Fn.id
  end

  module V1 = struct
    type t =
      ( Snapp_state.Value.Stable.V1.t
      , ( Side_loaded_verification_key.Stable.V1.t
        , F.Stable.V1.t )
        With_hash.Stable.V1.t
        option )
      Poly.Stable.V1.t
    [@@deriving sexp, equal, compare, hash, yojson]

    let to_latest ({ app_state; verification_key } : t) : V2.t =
      { app_state
      ; verification_key
      ; snapp_version = Mina_numbers.Snapp_version.zero
      ; rollup_state =
          (let empty = Lazy.force Rollup_events.empty_hash in
           [ empty; empty; empty; empty; empty ])
      ; last_rollup_slot = Mina_numbers.Global_slot.zero
      ; proved_state = false
      }
  end
end]

open Pickles_types

let digest_vk (t : Side_loaded_verification_key.t) =
  Random_oracle.(
    hash ~init:Hash_prefix_states.side_loaded_vk
      (pack_input (Side_loaded_verification_key.to_input t)))

[%%ifdef consensus_mechanism]

module Checked = struct
  type t =
    ( Pickles.Impls.Step.Field.t Snapp_state.V.t
    , ( Pickles.Side_loaded.Verification_key.Checked.t Lazy.t
      , Pickles.Impls.Step.Field.t Lazy.t )
      With_hash.t
    , Mina_numbers.Snapp_version.Checked.t
    , Pickles.Impls.Step.Field.t
    , Mina_numbers.Global_slot.Checked.t
    , Boolean.var )
    Poly.t

  let to_input' (t : _ Poly.t) =
    let open Random_oracle.Input in
    let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
    let app_state v = Random_oracle.Input.field_elements (Vector.to_array v) in
    Poly.Fields.fold ~init:[] ~app_state:(f app_state)
      ~verification_key:(f (fun x -> field x))
      ~snapp_version:
        (f (fun x ->
             Run.run_checked (Mina_numbers.Snapp_version.Checked.to_input x)))
      ~rollup_state:(f app_state)
      ~last_rollup_slot:
        (f (fun x ->
             Run.run_checked (Mina_numbers.Global_slot.Checked.to_input x)))
      ~proved_state:(f (fun b -> bitstring [ b ]))
    |> List.reduce_exn ~f:append

  let to_input (t : t) =
    to_input' { t with verification_key = Lazy.force t.verification_key.hash }

  let digest_vk t =
    Random_oracle.Checked.(
      hash ~init:Hash_prefix_states.side_loaded_vk
        (pack_input (Pickles.Side_loaded.Verification_key.Checked.to_input t)))

  let digest t =
    Random_oracle.Checked.(
      hash ~init:Hash_prefix_states.snapp_account (pack_input (to_input t)))

  let digest' t =
    Random_oracle.Checked.(
      hash ~init:Hash_prefix_states.snapp_account (pack_input (to_input' t)))
end

let typ : (Checked.t, t) Typ.t =
  let open Poly in
  Typ.of_hlistable
    [ Snapp_state.typ Field.typ
    ; Typ.transport Pickles.Side_loaded.Verification_key.typ
        ~there:(function
          | None ->
              Pickles.Side_loaded.Verification_key.dummy
          | Some x ->
              With_hash.data x)
        ~back:(fun x -> Some (With_hash.of_data x ~hash_data:digest_vk))
      |> Typ.transport_var
           ~there:(fun wh -> Lazy.force (With_hash.data wh))
           ~back:(fun x ->
             With_hash.of_data
               (lazy x)
               ~hash_data:(fun _ -> lazy (Checked.digest_vk x)))
    ; Mina_numbers.Snapp_version.typ
    ; Pickles_types.Vector.typ Field.typ Pickles_types.Nat.N5.n
    ; Mina_numbers.Global_slot.typ
    ; Boolean.typ
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

[%%endif]

let dummy_vk_hash =
  Memo.unit (fun () -> digest_vk Side_loaded_verification_key.dummy)

let to_input (t : t) =
  let open Random_oracle.Input in
  let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
  let app_state v = Random_oracle.Input.field_elements (Vector.to_array v) in
  Poly.Fields.fold ~init:[] ~app_state:(f app_state)
    ~verification_key:
      (f
         (Fn.compose field
            (Option.value_map ~default:(dummy_vk_hash ()) ~f:With_hash.hash)))
    ~snapp_version:(f Mina_numbers.Snapp_version.to_input)
    ~rollup_state:(f app_state)
    ~last_rollup_slot:(f Mina_numbers.Global_slot.to_input)
    ~proved_state:(f (fun b -> bitstring [ b ]))
  |> List.reduce_exn ~f:append

let default : _ Poly.t =
  (* These are the permissions of a "user"/"non snapp" account. *)
  { app_state = Vector.init Snapp_state.Max_state_size.n ~f:(fun _ -> F.zero)
  ; verification_key = None
  ; snapp_version = Mina_numbers.Snapp_version.zero
  ; rollup_state =
      (let empty = Lazy.force Rollup_events.empty_hash in
       [ empty; empty; empty; empty; empty ])
  ; last_rollup_slot = Mina_numbers.Global_slot.zero
  ; proved_state = false
  }

let digest (t : t) =
  Random_oracle.(
    hash ~init:Hash_prefix_states.snapp_account (pack_input (to_input t)))

let default_digest = lazy (digest default)
