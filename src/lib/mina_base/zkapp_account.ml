[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick
open Zkapp_basic

module Events = struct
  module Event = struct
    (* Arbitrary hash input, encoding determined by the zkApp's developer. *)
    type t = Field.t array

    let hash (x : t) = Random_oracle.hash ~init:Hash_prefix_states.zkapp_event x

    [%%ifdef consensus_mechanism]

    type var = Field.Var.t array

    let hash_var (x : Field.Var.t array) =
      Random_oracle.Checked.hash ~init:Hash_prefix_states.zkapp_event x

    [%%endif]
  end

  type t = Event.t list

  let empty_hash = lazy Random_oracle.(salt "MinaSnappEventsEmpty" |> digest)

  let push_hash acc hash =
    Random_oracle.hash ~init:Hash_prefix_states.zkapp_events [| acc; hash |]

  let push_event acc event = push_hash acc (Event.hash event)

  let hash (x : t) = List.fold ~init:(Lazy.force empty_hash) ~f:push_event x

  let to_input (x : t) = Random_oracle_input.Chunked.field (hash x)

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
              (event, events) )
    in
    Field.Assert.equal
      (Random_oracle.Checked.hash ~init:Hash_prefix_states.zkapp_events
         [| Data_as_hash.hash tl; Data_as_hash.hash hd |] )
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
          hd :: tl )
    in
    Field.Assert.equal
      (Random_oracle.Checked.hash ~init:Hash_prefix_states.zkapp_events
         [| Data_as_hash.hash events; Event.hash_var e |] )
      (Data_as_hash.hash res) ;
    res

  let deriver obj =
    let open Fields_derivers_zkapps in
    let events = list @@ array field (o ()) in
    with_checked
      ~checked:(Data_as_hash.deriver events)
      ~name:"Events" events obj

  [%%endif]
end

module Sequence_events = struct
  let empty_hash = lazy Random_oracle.(salt "MinaSnappSequenceEmpty" |> digest)

  let push_hash acc hash =
    Random_oracle.hash ~init:Hash_prefix_states.zkapp_sequence_events
      [| acc; hash |]

  let push_events acc events = push_hash acc (Events.hash events)

  [%%ifdef consensus_mechanism]

  let push_events_checked x (e : Events.var) =
    Random_oracle.Checked.hash ~init:Hash_prefix_states.zkapp_sequence_events
      [| x; Data_as_hash.hash e |]

  [%%endif]
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('app_state, 'vk, 'zkapp_version, 'field, 'slot, 'bool) t =
        { app_state : 'app_state
        ; verification_key : 'vk
        ; zkapp_version : 'zkapp_version
        ; sequence_state : 'field Pickles_types.Vector.Vector_5.Stable.V1.t
        ; last_sequence_slot : 'slot
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

type ('app_state, 'vk, 'zkapp_version, 'field, 'slot, 'bool) t_ =
      ('app_state, 'vk, 'zkapp_version, 'field, 'slot, 'bool) Poly.t =
  { app_state : 'app_state
  ; verification_key : 'vk
  ; zkapp_version : 'zkapp_version
  ; sequence_state : 'field Pickles_types.Vector.Vector_5.t
  ; last_sequence_slot : 'slot
  ; proved_state : 'bool
  }

let digest_vk (t : Side_loaded_verification_key.t) =
  Random_oracle.(
    hash ~init:Hash_prefix_states.side_loaded_vk
      (pack_input (Side_loaded_verification_key.to_input t)))

let dummy_vk_hash =
  Memo.unit (fun () -> digest_vk Side_loaded_verification_key.dummy)

module Vk_wire = struct
  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = (Side_loaded_verification_key.t, F.t) With_hash.t
        [@@deriving sexp, yojson, equal, compare, hash]
      end

      include T

      let to_latest = Fn.id

      module M = struct
        type nonrec t = t

        (* don't send hash over the wire; restore hash on receipt *)

        let to_binable (t : t) = t.data

        let of_binable vk : t =
          let data = vk in
          let hash = digest_vk vk in
          { data; hash }
      end

      include
        Binable.Of_binable_without_uuid
          (Side_loaded_verification_key.Stable.V2)
          (M)
    end
  end]
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      ( Zkapp_state.Value.Stable.V1.t
      , Vk_wire.Stable.V1.t option
      , Mina_numbers.Zkapp_version.Stable.V1.t
      , F.Stable.V1.t
      , Mina_numbers.Global_slot.Stable.V1.t
      , bool )
      Poly.Stable.V2.t
    [@@deriving sexp, equal, compare, hash, yojson]

    let to_latest = Fn.id
  end
end]

type t =
  ( Zkapp_state.Value.t
  , Vk_wire.t option
  , Mina_numbers.Zkapp_version.t
  , F.t
  , Mina_numbers.Global_slot.t
  , bool )
  Poly.t
[@@deriving sexp, equal, compare, hash, yojson]

let () =
  let _f : unit -> (t, Stable.Latest.t) Type_equal.t = fun () -> Type_equal.T in
  ()

[%%ifdef consensus_mechanism]

module Checked = struct
  type t =
    ( Pickles.Impls.Step.Field.t Zkapp_state.V.t
    , ( Boolean.var
      , (Side_loaded_verification_key.t option, Field.t) With_hash.t
        Data_as_hash.t )
      Flagged_option.t
    , Mina_numbers.Zkapp_version.Checked.t
    , Pickles.Impls.Step.Field.t
    , Mina_numbers.Global_slot.Checked.t
    , Boolean.var )
    Poly.t

  open Pickles_types

  let to_input' (t : _ Poly.t) =
    let open Random_oracle.Input.Chunked in
    let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
    let app_state v =
      Random_oracle.Input.Chunked.field_elements (Vector.to_array v)
    in
    Poly.Fields.fold ~init:[] ~app_state:(f app_state)
      ~verification_key:(f (fun x -> field x))
      ~zkapp_version:(f (fun x -> Mina_numbers.Zkapp_version.Checked.to_input x))
      ~sequence_state:(f app_state)
      ~last_sequence_slot:
        (f (fun x -> Mina_numbers.Global_slot.Checked.to_input x))
      ~proved_state:
        (f (fun (b : Boolean.var) ->
             Random_oracle.Input.Chunked.packed ((b :> Field.Var.t), 1) ) )
    |> List.reduce_exn ~f:append

  let to_input (t : t) =
    to_input'
      { t with verification_key = Data_as_hash.hash t.verification_key.data }

  let digest_vk t =
    Random_oracle.Checked.(
      hash ~init:Hash_prefix_states.side_loaded_vk
        (pack_input (Pickles.Side_loaded.Verification_key.Checked.to_input t)))

  let digest t =
    Random_oracle.Checked.(
      hash ~init:Hash_prefix_states.zkapp_account (pack_input (to_input t)))

  let digest' t =
    Random_oracle.Checked.(
      hash ~init:Hash_prefix_states.zkapp_account (pack_input (to_input' t)))
end

let typ : (Checked.t, t) Typ.t =
  let open Poly in
  Typ.of_hlistable
    [ Zkapp_state.typ Field.typ
    ; Flagged_option.option_typ
        ~default:{ With_hash.data = None; hash = dummy_vk_hash () }
        (Data_as_hash.typ ~hash:With_hash.hash)
      |> Typ.transport
           ~there:(Option.map ~f:(With_hash.map ~f:Option.some))
           ~back:
             (Option.map ~f:(With_hash.map ~f:(fun x -> Option.value_exn x)))
    ; Mina_numbers.Zkapp_version.typ
    ; Pickles_types.Vector.typ Field.typ Pickles_types.Nat.N5.n
    ; Mina_numbers.Global_slot.typ
    ; Boolean.typ
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

[%%endif]

let to_input (t : t) =
  let open Random_oracle.Input.Chunked in
  let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
  let app_state v =
    Random_oracle.Input.Chunked.field_elements (Pickles_types.Vector.to_array v)
  in
  Poly.Fields.fold ~init:[] ~app_state:(f app_state)
    ~verification_key:
      (f
         (Fn.compose field
            (Option.value_map ~default:(dummy_vk_hash ()) ~f:With_hash.hash) ) )
    ~zkapp_version:(f Mina_numbers.Zkapp_version.to_input)
    ~sequence_state:(f app_state)
    ~last_sequence_slot:(f Mina_numbers.Global_slot.to_input)
    ~proved_state:
      (f (fun b -> Random_oracle.Input.Chunked.packed (field_of_bool b, 1)))
  |> List.reduce_exn ~f:append

let default : _ Poly.t =
  (* These are the permissions of a "user"/"non zkapp" account. *)
  { app_state =
      Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun _ ->
          F.zero )
  ; verification_key = None
  ; zkapp_version = Mina_numbers.Zkapp_version.zero
  ; sequence_state =
      (let empty = Lazy.force Sequence_events.empty_hash in
       [ empty; empty; empty; empty; empty ] )
  ; last_sequence_slot = Mina_numbers.Global_slot.zero
  ; proved_state = false
  }

let digest (t : t) =
  Random_oracle.(
    hash ~init:Hash_prefix_states.zkapp_account (pack_input (to_input t)))

let default_digest = lazy (digest default)
