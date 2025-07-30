open Core_kernel
open Snark_params.Tick.Run
open Signature_lib

let initial_state = lazy (List.init 8 ~f:(fun _ -> Field.Constant.zero))

let initialize public_key =
  Zkapps_examples.wrap_main
    ~public_key:(Public_key.Compressed.var_of_t public_key)
    (fun account_update ->
      let initial_state =
        List.map ~f:Field.constant (Lazy.force initial_state)
      in
      account_update#assert_state_unproved ;
      account_update#set_full_state initial_state )

type _ Snarky_backendless.Request.t +=
  | New_state : Field.Constant.t list Snarky_backendless.Request.t

let update_state_handler (new_state : Field.Constant.t list)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | New_state ->
      respond (Provide new_state)
  | _ ->
      respond Unhandled

let update_state public_key =
  Zkapps_examples.wrap_main
    ~public_key:(Public_key.Compressed.var_of_t public_key)
    (fun account_update ->
      let new_state =
        exists (Typ.list ~length:8 Field.typ) ~request:(fun () -> New_state)
      in
      account_update#assert_state_proved ;
      account_update#set_full_state new_state )

let initialize_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Initialize snapp"
  ; prevs = []
  ; main = initialize public_key
  ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
  }

let update_state_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Update state"
  ; prevs = []
  ; main = update_state public_key
  ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
  }
