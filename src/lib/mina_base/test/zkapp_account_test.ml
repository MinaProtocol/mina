(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- \
                  test '^zkapp-accounts$'
    Subject:    Test zkApp accounts.
 *)

open Core_kernel
open Snark_params.Tick
open Mina_base
open Zkapp_account

module type Events_list_intf = sig
  type t

  type var

  val typ : (var, Event.t list) Typ.t

  val push_to_data_as_hash : var -> Event.var -> var

  val pop_from_data_as_hash : var -> Event.t Data_as_hash.t * var

  val empty_stack_msg : string
end

let gen_events =
  let open Quickcheck in
  let open Generator.Let_syntax in
  let%bind num_events = Int.gen_incl 1 20 in
  let%bind event_len = Int.gen_incl 1 10 in
  let%map events =
    Generator.list_with_length num_events
      (Generator.list_with_length event_len Field.gen)
  in
  List.map ~f:Array.of_list events

let checked_pop_reverses_push (module E : Events_list_intf) () =
  Quickcheck.test gen_events ~trials:50 ~f:(fun events ->
      let events_vars = List.map events ~f:(Array.map ~f:Field.Var.constant) in
      let f () () =
        Run.as_prover (fun () ->
            let empty_var = Run.exists E.typ ~compute:(fun _ -> []) in
            let pushed =
              List.fold_right events_vars ~init:empty_var
                ~f:(Fn.flip E.push_to_data_as_hash)
            in
            let popped =
              let rec go acc var =
                try
                  let event_with_hash, tl_var = E.pop_from_data_as_hash var in
                  let event =
                    Run.As_prover.read
                      (Data_as_hash.typ ~hash:Event.hash)
                      event_with_hash
                  in
                  go (event :: acc) tl_var
                with
                | Snarky_backendless.Snark0.Runtime_error (_, Failure s, _)
                | Failure s
                when String.equal s E.empty_stack_msg
                ->
                  List.rev acc
              in
              go [] pushed
            in
            [%test_eq: Event.t list] events popped )
      in
      match Snark_params.Tick.Run.run_and_check f with
      | Ok () ->
          ()
      | Error err ->
          failwithf "Error from run_and_check: %s" (Error.to_string_hum err) () )

let gen_with_verification_key =
  let open Quickcheck.Generator.Let_syntax in
  let%bind t = Zkapp_account.gen in
  let%bind has_vk = Bool.quickcheck_generator in
  if has_vk then
    let%map hash = Field.gen and txn_version = Mina_numbers.Txn_version.gen in
    { t with
      verification_key =
        Some
          { Vk_with_version.Poly.vk =
              { With_hash.data = Side_loaded_verification_key.dummy; hash }
          ; txn_version
          }
    }
  else return t

(* The digest of a zkApp account in the layout that kept the verification key
   and a [zkapp_version] as separate fields. As there, the inputs are folded in
   reverse field order. *)
let flat_layout_digest (t : Zkapp_account.t) =
  let vk, zkapp_version = Vk_with_version.to_flat t.verification_key in
  let open Random_oracle.Input.Chunked in
  List.rev
    [ field_elements (Pickles_types.Vector.to_array t.app_state)
    ; field (Option.value_map vk ~default:(dummy_vk_hash ()) ~f:With_hash.hash)
    ; Mina_numbers.Zkapp_version.to_input zkapp_version
    ; field_elements (Pickles_types.Vector.to_array t.action_state)
    ; Mina_numbers.Global_slot_since_genesis.to_input t.last_action_slot
    ; packed (Zkapp_basic.field_of_bool t.proved_state, 1)
    ; field (hash_zkapp_uri t.zkapp_uri)
    ]
  |> List.reduce_exn ~f:append |> Random_oracle.pack_input
  |> Random_oracle.hash ~init:Hash_prefix_states.zkapp_account

let digest_matches_flat_layout () =
  Quickcheck.test gen_with_verification_key ~trials:50 ~f:(fun t ->
      [%test_eq: Field.t] (flat_layout_digest t) (digest t) )

let checked_digest_matches_unchecked () =
  Quickcheck.test gen_with_verification_key ~trials:10 ~f:(fun t ->
      let f () () =
        let var = Run.exists typ ~compute:(fun () -> t) in
        let digest_var = Checked.digest var in
        Run.as_prover (fun () ->
            [%test_eq: Field.t] (digest t) (Run.As_prover.read_var digest_var) )
      in
      match Snark_params.Tick.Run.run_and_check f with
      | Ok () ->
          ()
      | Error err ->
          failwithf "Error from run_and_check: %s" (Error.to_string_hum err) () )

let flat_round_trip () =
  Quickcheck.test gen_with_verification_key ~trials:50 ~f:(fun t ->
      let vk, zkapp_version = Vk_with_version.to_flat t.verification_key in
      [%test_eq: Vk_with_version.t option] t.verification_key
        (Or_error.ok_exn (Vk_with_version.of_flat ~zkapp_version vk)) )

let flat_version_without_key_is_rejected () =
  [%test_pred: Vk_with_version.t option Or_error.t] Result.is_error
    (Vk_with_version.of_flat
       ~zkapp_version:(Mina_numbers.Zkapp_version.of_int 1)
       None )
