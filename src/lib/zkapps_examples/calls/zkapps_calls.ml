open Core_kernel
open Snark_params.Tick.Run
open Signature_lib
open Mina_base

(** State to initialize the zkApp to after deployment. *)
let initial_state = lazy (List.init 8 ~f:(fun _ -> Field.Constant.zero))

(** Rule to initialize the zkApp.

    Asserts that the state was not last updated by a proof (ie. the zkApp is
    freshly deployed, or that the state was modified -- tampered with --
    without using a proof).
    The app state is set to the initial state.
*)
let initialize public_key =
  Zkapps_examples.wrap_main
    ~public_key:(Public_key.Compressed.var_of_t public_key) (fun party ->
      let initial_state =
        List.map ~f:Field.constant (Lazy.force initial_state)
      in
      party#assert_state_unproved ;
      party#set_full_state initial_state ;
      None )

(** The type underlying the opaque call data digest field used by the call
    rules.
*)
module Call_data = struct
  (** The type of inputs that the zkApp rules receive when called by another
      zkApp.
  *)
  module Input = struct
    module Constant = struct
      type t = { old_state : Field.Constant.t } [@@deriving hlist]

      let to_ro_input { old_state } =
        Random_oracle_input.Chunked.field_elements [| old_state |]
    end

    module Circuit = struct
      type t = { old_state : Field.t } [@@deriving hlist]

      let to_ro_input { old_state } =
        Random_oracle_input.Chunked.field_elements [| old_state |]
    end

    let typ =
      Typ.of_hlistable ~value_to_hlist:Constant.to_hlist
        ~value_of_hlist:Constant.of_hlist ~var_to_hlist:Circuit.to_hlist
        ~var_of_hlist:Circuit.of_hlist [ Field.typ ]
  end

  (** The type of outputs that the zkApp rules receive when called by another
      zkApp.
  *)
  module Output = struct
    module Constant = struct
      type t =
        { blinding_value : Field.Constant.t; new_state : Field.Constant.t }
      [@@deriving hlist]

      let to_ro_input { blinding_value; new_state } =
        Random_oracle_input.Chunked.field_elements
          [| blinding_value; new_state |]
    end

    module Circuit = struct
      type t = { blinding_value : Field.t; new_state : Field.t }
      [@@deriving hlist]

      let to_ro_input { blinding_value; new_state } =
        Random_oracle_input.Chunked.field_elements
          [| blinding_value; new_state |]
    end

    let typ =
      Typ.of_hlistable ~value_to_hlist:Constant.to_hlist
        ~value_of_hlist:Constant.of_hlist ~var_to_hlist:Circuit.to_hlist
        ~var_of_hlist:Circuit.of_hlist [ Field.typ; Field.typ ]
  end

  module Constant = struct
    type t = { input : Input.Constant.t; output : Output.Constant.t }
    [@@deriving hlist]

    let to_ro_input { input; output } =
      Random_oracle_input.Chunked.append
        (Input.Constant.to_ro_input input)
        (Output.Constant.to_ro_input output)

    let digest (t : t) =
      let open Random_oracle in
      to_ro_input t |> pack_input |> update ~state:initial_state |> digest
  end

  module Circuit = struct
    type t = { input : Input.Circuit.t; output : Output.Circuit.t }
    [@@deriving hlist]

    let to_ro_input { input; output } =
      Random_oracle_input.Chunked.append
        (Input.Circuit.to_ro_input input)
        (Output.Circuit.to_ro_input output)

    let digest (t : t) =
      let open Random_oracle.Checked in
      to_ro_input t |> pack_input |> update ~state:initial_state |> digest
  end

  let typ =
    Typ.of_hlistable ~value_to_hlist:Constant.to_hlist
      ~value_of_hlist:Constant.of_hlist ~var_to_hlist:Circuit.to_hlist
      ~var_of_hlist:Circuit.of_hlist [ Input.typ; Output.typ ]
end

type _ Snarky_backendless.Request.t +=
  | Old_state : Field.Constant.t Snarky_backendless.Request.t
  | Call_data :
      Call_data.Input.Constant.t
      -> ( Call_data.Output.Constant.t
         * Zkapp_call_forest.party
         * Zkapp_call_forest.t )
         Snarky_backendless.Request.t

let update_state_handler (old_state : Field.Constant.t)
    (compute_call :
         Call_data.Input.Constant.t
      -> Call_data.Output.Constant.t
         * Zkapp_call_forest.party
         * Zkapp_call_forest.t )
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Old_state ->
      respond (Provide old_state)
  | Call_data input ->
      respond (Provide (compute_call input))
  | _ ->
      respond Unhandled

let update_state_call public_key =
  Zkapps_examples.wrap_main
    ~public_key:(Public_key.Compressed.var_of_t public_key) (fun party ->
      let old_state = exists Field.typ ~request:(fun () -> Old_state) in
      let call_inputs = { Call_data.Input.Circuit.old_state } in
      let call_outputs, called_party, sub_calls =
        exists
          (Typ.tuple3 Call_data.Output.typ
             (Zkapp_call_forest.Checked.party_typ ())
             Zkapp_call_forest.typ )
          ~request:(fun () ->
            let input = As_prover.read Call_data.Input.typ call_inputs in
            Call_data input )
      in
      let () =
        (* Check that previous party's call data is consistent. *)
        let call_data_digest =
          Call_data.Circuit.digest
            { input = call_inputs; output = call_outputs }
        in
        Field.Assert.equal call_data_digest called_party.party.data.call_data
      in
      party#assert_state_proved ;
      party#set_state 0 old_state ;
      party#call called_party sub_calls ;
      None )

type _ Snarky_backendless.Request.t +=
  | Call_input : Call_data.Input.Constant.t Snarky_backendless.Request.t

let call_handler (call_input : Call_data.Input.Constant.t)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Call_input ->
      respond (Provide call_input)
  | _ ->
      respond Unhandled

let call public_key =
  Zkapps_examples.wrap_main
    ~public_key:(Public_key.Compressed.var_of_t public_key) (fun party ->
      let input = exists Call_data.Input.typ ~request:(fun () -> Call_input) in
      let blinding_value = exists Field.typ ~compute:Field.Constant.random in
      let modify_value = exists Field.typ ~compute:Field.Constant.random in
      let new_state = Field.add input.old_state modify_value in
      let output = { Call_data.Output.Circuit.blinding_value; new_state } in
      let call_data_digest = Call_data.Circuit.digest { input; output } in
      party#assert_state_proved ;
      party#set_call_data call_data_digest ;
      Some output )

type _ Snarky_backendless.Request.t +=
  | Recursive_call_input :
      Call_data.Input.Constant.t Snarky_backendless.Request.t
  | Recursive_call_data :
      Call_data.Input.Constant.t
      -> ( Call_data.Output.Constant.t
         * Zkapp_call_forest.party
         * Zkapp_call_forest.t )
         Snarky_backendless.Request.t

let recursive_call_handler (recursive_call_input : Call_data.Input.Constant.t)
    (compute_call :
         Call_data.Input.Constant.t
      -> Call_data.Output.Constant.t
         * Zkapp_call_forest.party
         * Zkapp_call_forest.t )
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Recursive_call_input ->
      respond (Provide recursive_call_input)
  | Recursive_call_data input ->
      respond (Provide (compute_call input))
  | _ ->
      respond Unhandled

let recursive_call public_key =
  Zkapps_examples.wrap_main
    ~public_key:(Public_key.Compressed.var_of_t public_key) (fun party ->
      let call_inputs =
        exists Call_data.Input.typ ~request:(fun () -> Recursive_call_input)
      in
      let recursive_call_outputs, called_party, sub_calls =
        exists
          (Typ.tuple3 Call_data.Output.typ
             (Zkapp_call_forest.Checked.party_typ ())
             Zkapp_call_forest.typ )
          ~request:(fun () ->
            let input = As_prover.read Call_data.Input.typ call_inputs in
            Recursive_call_data input )
      in
      let () =
        (* Check that previous party's call data is consistent. *)
        let call_data_digest =
          Call_data.Circuit.digest
            { input = call_inputs; output = recursive_call_outputs }
        in
        Field.Assert.equal call_data_digest called_party.party.data.call_data
      in
      let blinding_value = exists Field.typ ~compute:Field.Constant.random in
      let modify_value = exists Field.typ ~compute:Field.Constant.random in
      let new_state = Field.add recursive_call_outputs.new_state modify_value in
      let call_outputs =
        { Call_data.Output.Circuit.blinding_value; new_state }
      in
      let call_data_hash =
        Call_data.Circuit.digest { input = call_inputs; output = call_outputs }
      in
      party#assert_state_proved ;
      party#set_call_data call_data_hash ;
      party#call called_party sub_calls ;
      Some call_outputs )

let initialize_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Initialize snapp"
  ; prevs = []
  ; main = initialize public_key
  ; uses_lookup = false
  }

let update_state_call_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Update state call"
  ; prevs = []
  ; main = update_state_call public_key
  ; uses_lookup = false
  }

let call_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Call"
  ; prevs = []
  ; main = call public_key
  ; uses_lookup = false
  }

let recursive_call_rule public_key : _ Pickles.Inductive_rule.t =
  { identifier = "Recursive call"
  ; prevs = []
  ; main = recursive_call public_key
  ; uses_lookup = false
  }
