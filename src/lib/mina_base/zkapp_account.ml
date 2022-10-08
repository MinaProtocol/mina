[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick
open Zkapp_basic

module Event = struct
  (* Arbitrary hash input, encoding determined by the zkApp's developer. *)
  type t = Field.t array [@@deriving equal]

  let hash (x : t) = Random_oracle.hash ~init:Hash_prefix_states.zkapp_event x

  [%%ifdef consensus_mechanism]

  type var = Field.Var.t array

  let hash_var (x : Field.Var.t array) =
    Random_oracle.Checked.hash ~init:Hash_prefix_states.zkapp_event x

  [%%endif]
end

module Make_events (Inputs : sig
  val salt_phrase : string

  val hash_prefix : field Random_oracle.State.t

  val deriver_name : string
end) =
struct
  type t = Event.t list [@@deriving equal]

  let empty_hash = Random_oracle.(salt Inputs.salt_phrase |> digest)

  let push_hash acc hash =
    Random_oracle.hash ~init:Inputs.hash_prefix [| acc; hash |]

  let push_event acc event = push_hash acc (Event.hash event)

  let hash (x : t) =
    (* fold_right so the empty hash is used at the end of the events *)
    List.fold_right ~init:empty_hash ~f:(Fn.flip push_event) x

  [%%ifdef consensus_mechanism]

  type var = t Data_as_hash.t

  let typ = Data_as_hash.typ ~hash

  let var_to_input (x : var) = Data_as_hash.to_input x

  let to_input (x : t) = Random_oracle_input.Chunked.field (hash x)

  let push_to_data_as_hash (events : var) (e : Event.var) : var =
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
      (Random_oracle.Checked.hash ~init:Inputs.hash_prefix
         [| Data_as_hash.hash events; Event.hash_var e |] )
      (Data_as_hash.hash res) ;
    res

  let empty_stack_msg = "Attempted to pop an empty stack"

  let pop_from_data_as_hash (events : var) : Event.t Data_as_hash.t * var =
    let open Run in
    let hd, tl =
      exists
        Typ.(Data_as_hash.typ ~hash:Event.hash * typ)
        ~compute:(fun () ->
          match As_prover.read typ events with
          | [] ->
              failwith empty_stack_msg
          | event :: events ->
              (event, events) )
    in
    Field.Assert.equal
      (Random_oracle.Checked.hash ~init:Hash_prefix_states.zkapp_events
         [| Data_as_hash.hash tl; Data_as_hash.hash hd |] )
      (Data_as_hash.hash events) ;
    (hd, tl)

  [%%endif]

  let deriver obj =
    let open Fields_derivers_zkapps in
    let events = list @@ array field (o ()) in
    with_checked
      ~checked:(Data_as_hash.deriver events)
      ~name:Inputs.deriver_name events obj
end

module Events = struct
  include Make_events (struct
    let salt_phrase = "MinaZkappEventsEmpty"

    let hash_prefix = Hash_prefix_states.zkapp_events

    let deriver_name = "Events"
  end)

  let%test_unit "checked push/pop inverse" =
    let open Quickcheck in
    let num_events = 11 in
    let event_len = 7 in
    let events =
      random_value
        (Generator.list_with_length num_events
           (Generator.list_with_length event_len Field.gen) )
      |> List.map ~f:Array.of_list
    in
    let events_vars = List.map events ~f:(Array.map ~f:Field.Var.constant) in
    let f () () =
      Run.as_prover (fun () ->
          let empty_var = Run.exists typ ~compute:(fun _ -> []) in
          let pushed =
            List.fold_right events_vars ~init:empty_var
              ~f:(Fn.flip push_to_data_as_hash)
          in
          let popped =
            let rec go acc var =
              try
                let event_with_hash, tl_var = pop_from_data_as_hash var in
                let event =
                  Run.As_prover.read
                    (Data_as_hash.typ ~hash:Event.hash)
                    event_with_hash
                in
                go (event :: acc) tl_var
              with
              | Snarky_backendless.Snark0.Runtime_error
                  (_, Failure s, _)
              when String.equal s empty_stack_msg
              ->
                List.rev acc
            in
            go [] pushed
          in
          assert (equal events popped) )
    in
    match Snark_params.Tick.Run.run_and_check f with
    | Ok () ->
        ()
    | Error err ->
        failwithf "Error from run_and_check: %s" (Error.to_string_hum err) ()
end

module Sequence_events = struct
  include Make_events (struct
    let salt_phrase = "MinaZkappSequenceEmpty"

    let hash_prefix = Hash_prefix_states.zkapp_sequence_events

    let deriver_name = "SequenceEvents"
  end)

  let is_empty_var (e : var) =
    Snark_params.Tick.Field.(
      Checked.equal (Data_as_hash.hash e) (Var.constant empty_hash))

  let empty_state_element =
    let salt_phrase = "MinaZkappSequenceStateEmptyElt" in
    Random_oracle.(salt salt_phrase |> digest)

  let push_events (acc : Field.t) (events : t) : Field.t =
    push_hash acc (hash events)

  [%%ifdef consensus_mechanism]

  let push_events_checked (x : Field.Var.t) (e : var) : Field.Var.t =
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

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      ( Zkapp_state.Value.Stable.V1.t
      , Verification_key_wire.Stable.V1.t option
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
  , Verification_key_wire.t option
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

[%%define_locally Verification_key_wire.(digest_vk, dummy_vk_hash)]

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
      (let empty = Sequence_events.empty_state_element in
       [ empty; empty; empty; empty; empty ] )
  ; last_sequence_slot = Mina_numbers.Global_slot.zero
  ; proved_state = false
  }

let digest (t : t) =
  Random_oracle.(
    hash ~init:Hash_prefix_states.zkapp_account (pack_input (to_input t)))

let default_digest = lazy (digest default)
