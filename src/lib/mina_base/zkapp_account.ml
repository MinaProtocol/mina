[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick
open Zkapp_basic

module Event = struct
  (* Arbitrary hash input, encoding determined by the zkApp's developer. *)
  type t = Field.t array [@@deriving compare, sexp]

  let hash (x : t) = Random_oracle.hash ~init:Hash_prefix_states.zkapp_event x

  [%%ifdef consensus_mechanism]

  type var = Field.Var.t array

  let hash_var (x : Field.Var.t array) =
    Random_oracle.Checked.hash ~init:Hash_prefix_states.zkapp_event x

  [%%endif]

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck in
    Generator.map ~f:Array.of_list @@ Generator.list Field.gen
end

module Make_events (Inputs : sig
  val salt_phrase : string

  val hash_prefix : field Random_oracle.State.t

  val deriver_name : string
end) =
struct
  type t = Event.t list [@@deriving compare, sexp]

  let empty_hash =
    Hash_prefix_create.salt Inputs.salt_phrase |> Random_oracle.digest

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
      (Random_oracle.Checked.hash ~init:Inputs.hash_prefix
         [| Data_as_hash.hash tl; Data_as_hash.hash hd |] )
      (Data_as_hash.hash events) ;
    (hd, tl)

  [%%endif]

  let deriver obj =
    let open Fields_derivers_zkapps in
    let events = list @@ array field (o ()) in
    needs_custom_js
      ~js_type:(Data_as_hash.deriver events)
      ~name:Inputs.deriver_name events obj
end

module Events = struct
  include Make_events (struct
    let salt_phrase = "MinaZkappEventsEmpty"

    let hash_prefix = Hash_prefix_states.zkapp_events

    let deriver_name = "Events"
  end)
end

module Actions = struct
  include Make_events (struct
    let salt_phrase = "MinaZkappActionsEmpty"

    let hash_prefix = Hash_prefix_states.zkapp_actions

    let deriver_name = "Actions"
  end)

  let is_empty_var (e : var) =
    Snark_params.Tick.Field.(
      Checked.equal (Data_as_hash.hash e) (Var.constant empty_hash))

  let empty_state_element =
    let salt_phrase = "MinaZkappActionStateEmptyElt" in
    Hash_prefix_create.salt salt_phrase |> Random_oracle.digest

  let push_events (acc : Field.t) (events : t) : Field.t =
    push_hash acc (hash events)

  [%%ifdef consensus_mechanism]

  let push_events_checked (x : Field.Var.t) (e : var) : Field.Var.t =
    Random_oracle.Checked.hash ~init:Hash_prefix_states.zkapp_actions
      [| x; Data_as_hash.hash e |]

  [%%endif]
end

module Zkapp_uri = struct
  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = string [@@deriving sexp, equal, compare, hash, yojson]

        let to_latest = Fn.id

        let max_length = 255

        let check (x : t) = assert (String.length x <= max_length)

        let t_of_sexp sexp =
          let res = t_of_sexp sexp in
          check res ; res

        let of_yojson json =
          let res = of_yojson json in
          Result.bind res ~f:(fun res ->
              Result.try_with (fun () -> check res)
              |> Result.map ~f:(Fn.const res)
              |> Result.map_error
                   ~f:(Fn.const "Zkapp_uri.of_yojson: symbol is too long") )
      end

      include T

      include
        Binable.Of_binable_without_uuid
          (Core_kernel.String.Stable.V1)
          (struct
            type t = string

            let to_binable = Fn.id

            let of_binable x = check x ; x
          end)
    end
  end]

  [%%define_locally
  Stable.Latest.
    (sexp_of_t, t_of_sexp, equal, to_yojson, of_yojson, max_length, check)]
end

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('app_state, 'vk, 'zkapp_version, 'field, 'slot, 'bool, 'zkapp_uri) t =
        { app_state : 'app_state
        ; verification_key : 'vk
        ; zkapp_version : 'zkapp_version
        ; action_state : 'field Pickles_types.Vector.Vector_5.Stable.V1.t
        ; last_action_slot : 'slot
        ; proved_state : 'bool
        ; zkapp_uri : 'zkapp_uri
        }
      [@@deriving sexp, equal, compare, hash, yojson, hlist, fields, annot]
    end
  end]
end

type ('app_state, 'vk, 'zkapp_version, 'field, 'slot, 'bool, 'zkapp_uri) t_ =
      ('app_state, 'vk, 'zkapp_version, 'field, 'slot, 'bool, 'zkapp_uri) Poly.t =
  { app_state : 'app_state
  ; verification_key : 'vk
  ; zkapp_version : 'zkapp_version
  ; action_state : 'field Pickles_types.Vector.Vector_5.t
  ; last_action_slot : 'slot
  ; proved_state : 'bool
  ; zkapp_uri : 'zkapp_uri
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
      , Mina_numbers.Global_slot_since_genesis.Stable.V1.t
      , bool
      , Zkapp_uri.Stable.V1.t )
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
  , Mina_numbers.Global_slot_since_genesis.t
  , bool
  , Zkapp_uri.t )
  Poly.t
[@@deriving sexp, equal, compare, hash, yojson]

let (_ : (t, Stable.Latest.t) Type_equal.t) = Type_equal.T

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
    , Mina_numbers.Global_slot_since_genesis.Checked.t
    , Boolean.var
    , string Data_as_hash.t )
    Poly.t

  open Pickles_types

  let to_input' (t : _ Poly.t) :
      Snark_params.Tick.Field.Var.t Random_oracle.Input.Chunked.t =
    let open Random_oracle.Input.Chunked in
    let f mk acc field = mk (Core_kernel.Field.get field t) :: acc in
    let app_state v =
      Random_oracle.Input.Chunked.field_elements (Vector.to_array v)
    in
    Poly.Fields.fold ~init:[] ~app_state:(f app_state)
      ~verification_key:(f field)
      ~zkapp_version:(f Mina_numbers.Zkapp_version.Checked.to_input)
      ~action_state:(f app_state)
      ~last_action_slot:
        (f Mina_numbers.Global_slot_since_genesis.Checked.to_input)
      ~proved_state:
        (f (fun (b : Boolean.var) ->
             Random_oracle.Input.Chunked.packed ((b :> Field.Var.t), 1) ) )
      ~zkapp_uri:(f field)
    |> List.reduce_exn ~f:append

  let to_input (t : t) =
    to_input'
      { t with
        verification_key = Data_as_hash.hash t.verification_key.data
      ; zkapp_uri = Data_as_hash.hash t.zkapp_uri
      }

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

(* This preimage cannot be attained by any string, due to the trailing [true]
   added below.
*)
let zkapp_uri_non_preimage =
  lazy (Random_oracle_input.Chunked.field_elements [| Field.zero; Field.zero |])

let hash_zkapp_uri_opt (zkapp_uri_opt : string option) =
  let input =
    match zkapp_uri_opt with
    | Some zkapp_uri ->
        (* We use [length*8 + 1] to pass a final [true] after the end of the
           string, to ensure that trailing null bytes don't alias in the hash
           preimage.
        *)
        let bits = Array.create ~len:((String.length zkapp_uri * 8) + 1) true in
        String.foldi zkapp_uri ~init:() ~f:(fun i () c ->
            let c = Char.to_int c in
            (* Insert the bits into [bits], LSB order. *)
            for j = 0 to 7 do
              (* [Int.test_bit c j] *)
              bits.((i * 8) + j) <- Int.bit_and c (1 lsl j) <> 0
            done ) ;
        Random_oracle_input.Chunked.packeds
          (Array.map ~f:(fun b -> (field_of_bool b, 1)) bits)
    | None ->
        Lazy.force zkapp_uri_non_preimage
  in
  Random_oracle.pack_input input
  |> Random_oracle.hash ~init:Hash_prefix_states.zkapp_uri

let hash_zkapp_uri (zkapp_uri : string) = hash_zkapp_uri_opt (Some zkapp_uri)

let typ : (Checked.t, t) Typ.t =
  let open Poly in
  Typ.of_hlistable
    [ Zkapp_state.typ Field.typ
    ; Flagged_option.lazy_option_typ
        ~default:(lazy { With_hash.data = None; hash = dummy_vk_hash () })
        (Data_as_hash.typ ~hash:With_hash.hash)
      |> Typ.transport
           ~there:(Option.map ~f:(With_hash.map ~f:Option.some))
           ~back:
             (Option.map ~f:(With_hash.map ~f:(fun x -> Option.value_exn x)))
    ; Mina_numbers.Zkapp_version.typ
    ; Pickles_types.Vector.typ Field.typ Pickles_types.Nat.N5.n
    ; Mina_numbers.Global_slot_since_genesis.typ
    ; Boolean.typ
    ; Data_as_hash.typ ~hash:hash_zkapp_uri
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

[%%endif]

let zkapp_uri_to_input zkapp_uri =
  Random_oracle.Input.Chunked.field @@ hash_zkapp_uri zkapp_uri

let to_input (t : t) : _ Random_oracle.Input.Chunked.t =
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
    ~action_state:(f app_state)
    ~last_action_slot:(f Mina_numbers.Global_slot_since_genesis.to_input)
    ~proved_state:
      (f (fun b -> Random_oracle.Input.Chunked.packed (field_of_bool b, 1)))
    ~zkapp_uri:(f zkapp_uri_to_input)
  |> List.reduce_exn ~f:append

let default : _ Poly.t =
  (* These are the permissions of a "user"/"non zkapp" account. *)
  { app_state =
      Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun _ ->
          F.zero )
  ; verification_key = None
  ; zkapp_version = Mina_numbers.Zkapp_version.zero
  ; action_state =
      (let empty = Actions.empty_state_element in
       [ empty; empty; empty; empty; empty ] )
  ; last_action_slot = Mina_numbers.Global_slot_since_genesis.zero
  ; proved_state = false
  ; zkapp_uri = ""
  }

let digest (t : t) =
  Random_oracle.(
    hash ~init:Hash_prefix_states.zkapp_account (pack_input (to_input t)))

let default_digest = lazy (digest default)

let hash_zkapp_account_opt' = function
  | None ->
      Lazy.force default_digest
  | Some (a : t) ->
      digest a

let action_state_deriver obj =
  let open Fields_derivers_zkapps.Derivers in
  let list_5 = list ~static_length:5 (field @@ o ()) in
  let open Pickles_types.Vector.Vector_5 in
  iso ~map:of_list_exn ~contramap:to_list (list_5 (o ())) obj

let deriver obj =
  let open Fields_derivers_zkapps in
  let ( !. ) = ( !. ) ~t_fields_annots:Poly.t_fields_annots in
  finish "ZkappAccount" ~t_toplevel_annots:Poly.t_toplevel_annots
  @@ Poly.Fields.make_creator
       ~app_state:!.(Zkapp_state.deriver field)
       ~verification_key:
         !.(option ~js_type:Or_undefined (verification_key_with_hash @@ o ()))
       ~zkapp_version:!.uint32 ~action_state:!.action_state_deriver
       ~last_action_slot:!.global_slot_since_genesis
       ~proved_state:!.bool ~zkapp_uri:!.string obj

let gen_uri =
  let open Quickcheck in
  let open Generator.Let_syntax in
  let%bind parts =
    String.gen_with_length 8 Char.gen_alphanum |> Generator.list_with_length 3
  in
  let%map domain = Generator.of_list [ "com"; "org"; "net"; "info" ] in
  Printf.sprintf "https://%s.%s" (String.concat ~sep:"." parts) domain

let gen : t Quickcheck.Generator.t =
  let open Quickcheck in
  let open Generator.Let_syntax in
  let app_state =
    Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun _ ->
        F.random () )
  in
  let%bind zkapp_version = Mina_numbers.Zkapp_version.gen in
  let%bind seq_state = Generator.list_with_length 5 Field.gen in
  let%bind last_sequence_slot = Mina_numbers.Global_slot_since_genesis.gen in
  let%map zkapp_uri = gen_uri in
  let five = Pickles_types.Nat.(S (S (S (S (S Z))))) in
  { app_state
  ; verification_key = None
  ; zkapp_version
  ; action_state = Pickles_types.(Vector.of_list_and_length_exn seq_state five)
  ; last_action_slot = Mina_numbers.Global_slot_since_genesis.zero
  ; proved_state = false
  ; zkapp_uri
  }
