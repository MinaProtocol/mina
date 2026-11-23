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
          (with_version ~txn_version
             { With_hash.data = Side_loaded_verification_key.dummy; hash } )
    }
  else return t

let digest_covers_verification_key_version () =
  let vk =
    { With_hash.data = Side_loaded_verification_key.dummy
    ; hash = dummy_vk_hash ()
    }
  in
  let digest_at txn_version =
    digest
      { default with verification_key = Some (with_version ~txn_version vk) }
  in
  [%test_pred: Field.t * Field.t]
    (fun (a, b) -> not (Field.equal a b))
    ( digest_at Mina_numbers.Txn_version.mesa
    , digest_at Mina_numbers.Txn_version.(succ mesa) )

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

let upgrade_drops_only_the_zkapp_version () =
  let generator =
    Quickcheck.Generator.tuple2 Zkapp_account.gen Mina_numbers.Zkapp_version.gen
  in
  Quickcheck.test generator ~trials:50 ~f:(fun (t, zkapp_version) ->
      let v3 : Stable.V3.t =
        { app_state = t.app_state
        ; verification_key = Zkapp_account.verification_key_wire t
        ; zkapp_version
        ; action_state = t.action_state
        ; last_action_slot = t.last_action_slot
        ; proved_state = t.proved_state
        ; zkapp_uri = t.zkapp_uri
        }
      in
      [%test_eq: Zkapp_account.t] t (Stable.V3.to_latest v3) )

let v3_of_latest (t : Zkapp_account.t) : Stable.V3.t =
  { app_state = t.app_state
  ; verification_key = verification_key_wire t
  ; zkapp_version = Mina_numbers.Zkapp_version.zero
  ; action_state = t.action_state
  ; last_action_slot = t.last_action_slot
  ; proved_state = t.proved_state
  ; zkapp_uri = t.zkapp_uri
  }

let upgrade_gives_key_the_mesa_version () =
  Quickcheck.test gen_with_verification_key ~trials:50 ~f:(fun t ->
      let upgraded = Stable.V3.to_latest (v3_of_latest t) in
      [%test_eq: Verification_key_wire.t option] (verification_key_wire t)
        (verification_key_wire upgraded) ;
      [%test_eq: Mina_numbers.Txn_version.t option]
        (Option.map (verification_key_wire t) ~f:(fun _ ->
             Mina_numbers.Txn_version.mesa ) )
        (verification_key_txn_version upgraded) )

let upgraded_account_keeps_other_fields () =
  Quickcheck.test gen_with_verification_key ~trials:50 ~f:(fun t ->
      let upgraded = Stable.V3.to_latest (v3_of_latest t) in
      [%test_eq: Zkapp_account.t]
        { t with verification_key = upgraded.verification_key }
        upgraded )
