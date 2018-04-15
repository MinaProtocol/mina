open Core
open Async
open Nanobit_base
open Blockchain_snark
open Cli_common

type t =
  { host_and_port : Host_and_port.t
  ; connection : Persistent_connection.Rpc.t
  }

let default_port = 8300

let dispatch t rpc q =
  let%bind conn = Persistent_connection.Rpc.connected t.connection in
  Rpc.Rpc.dispatch rpc conn q
;;

(* Someday: Use janestreet's rpc_parallel library for this *)

module Rpcs = struct
  module Initialized = struct
    let name      = "initialized"
    let version   = 0
    type query    = unit [@@deriving bin_io, sexp]
    type response = Initialized [@@deriving bin_io, sexp]

    let rpc = Rpc.Rpc.create ~name ~version ~bin_query ~bin_response
  end

  module Genesis_proof = struct
    let name      = "genesis_proof"
    let version   = 0
    type query    = unit [@@deriving bin_io]
    type response = Proof.Stable.V1.t [@@deriving bin_io]
    let rpc = Rpc.Rpc.create ~name ~version ~bin_query ~bin_response
  end

  module Extend_blockchain = struct
    let name      = "extend_blockchain"
    let version   = 0
    type query    = Blockchain.Stable.V1.t * Block.Stable.V1.t [@@deriving bin_io]
    type response = Blockchain.Stable.V1.t [@@deriving bin_io]

    let rpc = Rpc.Rpc.create ~name ~version ~bin_query ~bin_response
  end

  module Verify = struct
    let name      = "verify"
    let version   = 0
    type query    = Blockchain.Stable.V1.t [@@deriving bin_io]
    type response = bool [@@deriving bin_io]

    let rpc = Rpc.Rpc.create ~name ~version ~bin_query ~bin_response
  end
end

let heartbeat_config =
  Rpc.Connection.Heartbeat_config.create
    ~send_every:(Time_ns.Span.of_sec 10.)
    ~timeout:(Time_ns.Span.of_min 5.)

let connect host_and_port =
  let connection =
    Persistent_connection.Rpc.create'
      ~retry_delay:(fun () -> Time.Span.of_min 10.)
      ~heartbeat_config
      ~handshake_timeout:(Time.Span.of_min 10.)
      ~server_name:"prover"
      (fun () -> Deferred.Or_error.return host_and_port)
  in
  return { host_and_port; connection }
;;

let create ?debug ~port =
  (* Soon: This channel should be authenticated somehow *)
  let%bind process =
    Process.create_exn
      ~prog:Sys.argv.(0)
      ~args:["prover"; "-port"; Int.to_string port ]
      ()
  in
  Option.iter debug ~f:(fun () ->
    let stderr = Lazy.force Writer.stderr  in
    let transfer_to_stderr r =
      ignore (Writer.transfer stderr (Reader.pipe r) (Writer.write stderr))
    in
    transfer_to_stderr (Process.stdout process);
    transfer_to_stderr (Process.stderr process)
  );
  let localhost = "127.0.0.1" in
  let host_and_port = { Host_and_port.port; host = localhost } in
  connect host_and_port
;;

let extend_blockchain t chain block =
  dispatch t Rpcs.Extend_blockchain.rpc (chain, block)

let verify t chain = dispatch t Rpcs.Verify.rpc chain

let initialized t =
  let open Deferred.Or_error.Let_syntax in
  match%map dispatch t Rpcs.Initialized.rpc () with
  | Initialized -> ()
;;

let genesis_proof t = dispatch t Rpcs.Genesis_proof.rpc ()

module type Params_intf = sig
  val port : int
end

module Main (Params : Params_intf) = struct
  open Snark_params

  module Digest = Tick.Pedersen.Digest

  module Transition = Blockchain_transition

  module Keys = Keys.Make()

  module Transaction_snark = Transaction_snark.Make(struct let keys = Keys.transaction_snark_keys end)

  module State = struct
    include (Blockchain_state : module type of Blockchain_state with module Checked := Blockchain_state.Checked)
    module U = Blockchain_state.Make_update(Transaction_snark)
    include (U : module type of U with module Checked := U.Checked)
    module Checked = struct
      include Blockchain_state.Checked
      include U.Checked
    end
  end

  module Transition_utils = struct
    open Keys

    let instance_hash =
      let self =
        Step.Verifier.Verification_key.to_bool_list Wrap.verification_key
      in
      fun state ->
        let open Tick.Pedersen.State in
        let s = create Tick.Pedersen.params in
        let s = update_fold s (List.fold self) in
        let s = update_fold s (State_hash.fold (Blockchain_state.hash state)) in
        digest s

    let embed (x : Tick.Field.t) : Tock.Field.t =
      let n = Tick.Bigint.of_field x in
      let rec go pt acc i =
        if i = Tick.Field.size_in_bits
        then acc
        else
          go (Tock.Field.add pt pt)
            (if Tick.Bigint.test_bit n i
            then Tock.Field.add pt acc
            else acc)
            (i + 1)
      in
      go Tock.Field.one Tock.Field.zero 0

    let wrap : Tick.Pedersen.Digest.t -> Tick.Proof.t -> Tock.Proof.t =
      fun hash proof ->
        Tock.prove Wrap.proving_key (Wrap.input ())
          { Wrap.Prover_state.proof }
          Wrap.main
          (embed hash)

    let step ~prev_proof ~prev_state block =
      let next_state = State.update_exn prev_state block in
      let next_state_top_hash = instance_hash next_state in
      let prev_proof =
        Tick.prove Step.proving_key (Step.input ())
          { Step.Prover_state.prev_proof
          ; wrap_vk = Wrap.verification_key
          ; prev_state
          ; update = block
          }
          Step.main
          next_state_top_hash
      in
      wrap next_state_top_hash prev_proof

    let verify state proof =
      Tock.verify proof
        (Wrap.verification_key) (Wrap.input ()) (embed (instance_hash state))
  end

  (* TODO: Hard code base_hash, or in any case make it not depend on
  transition *)
  let base_hash =
    lazy begin
      if Insecure.compute_base_hash
      then Tick.Field.zero
      else Transition_utils.instance_hash Blockchain.State.zero
    end

  let base_proof =
    if Insecure.compute_base_proof
    then begin
      Tock.Proof.dummy
    end else lazy begin
      let dummy_proof = Lazy.force Tock.Proof.dummy in
      let base_hash = Lazy.force base_hash in
      let tick =
        Tick.prove (Keys.Step.proving_key) (Keys.Step.input ())
          { Keys.Step.Prover_state.prev_proof = dummy_proof
          ; wrap_vk  = Keys.Wrap.verification_key
          ; prev_state = Blockchain.State.negative_one
          ; update = Block.genesis
          }
          Keys.Step.main
          base_hash
      in
      Transition_utils.wrap base_hash tick
    end
  ;;

  let initialize () = ignore (Lazy.force base_proof)

  let extend_blockchain_exn { Blockchain.state=prev_state; proof=prev_proof } block =
    let proof =
      if Insecure.extend_blockchain
      then Lazy.force base_proof
      else Transition_utils.step ~prev_proof ~prev_state block
    in
    { Blockchain.proof
    ; state = State.update_exn prev_state block 
    }
  ;;

  let implementations log =
    Rpc.Implementations.create_exn
      ~implementations:
        [ Rpc.Rpc.implement Rpcs.Extend_blockchain.rpc
            (fun s (chain, block) ->
               In_thread.run
                 (fun () -> extend_blockchain_exn chain block))
        ; Rpc.Rpc.implement Rpcs.Initialized.rpc
            (fun s () ->
               initialize ();
               return Rpcs.Initialized.Initialized)
        ; Rpc.Rpc.implement Rpcs.Genesis_proof.rpc
            (fun s () -> 
               return (Lazy.force base_proof))
        ; Rpc.Rpc.implement Rpcs.Verify.rpc
            (fun s ({ Blockchain.state; proof }) ->
               if Insecure.verify_blockchain
               then return true
               else
                 let proof_verifies = Transition_utils.verify state proof in
                 return proof_verifies)
        ]
      ~on_unknown_rpc:(`Call (fun () ~rpc_tag ~version ->
        Logger.error log "prover: unknown rpc: %s %d" rpc_tag version;
        `Continue))

  let main () =
    let log = Logger.create () in
    initialize ();
    let%bind server =
      Tcp.Server.create
        ~on_handler_error:(`Call (fun net exn -> Logger.error log "%s" (Exn.to_string_mach exn)))
        (Tcp.Where_to_listen.of_port Params.port)
        (fun address reader writer -> 
          Rpc.Connection.server_with_close
            reader writer
            ~heartbeat_config
            ~implementations:(implementations log)
            ~connection_state:(fun _ -> ())
            ~on_handshake_error:`Ignore)
    in
    never ()
  ;;
end

let command : Command.t =
  Command.async ~summary:"Prover server process" begin
    let open Command.Let_syntax in
    let%map_open port =
      flag "port" ~doc:"port to listen on" (required int16)
    in
    fun () -> 
      let module M = Main(struct let port = port end) in
      M.main ()
  end
