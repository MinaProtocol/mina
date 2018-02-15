open Core
open Async
open Nanobit_base
open Cli_common

module State = Blockchain_state

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
    type response = Proof.t [@@deriving bin_io]
    let rpc = Rpc.Rpc.create ~name ~version ~bin_query ~bin_response
  end

  module Extend_blockchain = struct
    let name      = "extend_blockchain"
    let version   = 0
    type query    = Blockchain.t * Block.t [@@deriving bin_io]
    type response = Blockchain.t [@@deriving bin_io]

    let rpc = Rpc.Rpc.create ~name ~version ~bin_query ~bin_response
  end

  module Verify = struct
    let name      = "verify"
    let version   = 0
    type query    = Blockchain.t [@@deriving bin_io]
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

  module Transition = Nanobit_base.Blockchain_transition

  module Keys = Transition_keys.Make(struct end)

  module Transition_utils = struct
    open Keys

    let instance_hash =
      let self =
        Step.Verifier.Verification_key.to_bool_list Wrap.verification_key
      in
      fun state ->
        let open Tick.Pedersen in
        let s = State.create params in
        let s = State.update_fold s (List.fold self) in
        let s =
          State.update_fold s
            (List.fold
              (Digest.Bits.to_bits
                 (Blockchain_state.hash state)))
        in
        State.digest s

    let wrap : Tick.Pedersen.Digest.t -> Tick.Proof.t -> Tock.Proof.t =
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
      in
      fun hash proof ->
        Tock.prove Wrap.proving_key (Wrap.input ())
          { Wrap.Prover_state.proof }
          Wrap.main
          (embed hash)

    let step ~prev_proof ~prev_state block =
      let prev_proof = wrap (instance_hash prev_state) prev_proof in
      let next_state = State.update_exn prev_state block in
      Tick.prove Step.proving_key (Step.input ())
        { Step.Prover_state.prev_proof
        ; wrap_vk = Wrap.verification_key
        ; prev_state
        ; update = block
        }
        Step.main
        (instance_hash next_state)

    let verify state proof =
      Tick.verify proof
        (Step.verification_key) (Step.input ()) (instance_hash state)
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
    lazy begin
      if Insecure.compute_base_proof
      then begin
        let s = "0H\150A)W\135\192\t5\202\159\194\193\195s)w\1808o\1578\015zK\1278\234\152\226\020\204\237\204SUo\002\000\00010\226<\229]\252_\198\001$\174\166o\225\189i\230\255F\"\251\214\197\004\224\190nI\181c\174\210\156\140)\160\204z\003\000\00000\144\021\255\207\024\183P\1670\200Fyk\131\191\015\140e]v\\\022\218MHJ\028\213bO:1)\137\242\130C\001\000\000\128\151\000H\135\019;/B\186\152\204\254f\131\179\018\156=$\243\211\140\166\217\011r4]\240_K\144\158;\000\177\002\000\00010\149\208\232\188W\200\191\253Q\023\151M\215\024\149E\237s\185\187j\219\224d\146\147l>\201\152\021s\140\240\152\168\006\002\000\00000\224e]n`\245U\002\207\198\170(0\217\247j.`\144\"\169\221\161\241\162.\226\002N+\231K\185\137}:\007\001\000\00010\249V\197\226\201\202\173\146\196\178\168\005\198p\163B\166\020H\
                \nE\022\250\252\151\140\253\242a|\162t\220\179\227\213p\001\000\00010e#^E\133n\177\2216sl\020\244\170\004\139\219\228\139\227Oft\231\144\184\127\001\1689a?\184\0232\021\131\002\000\00010\133e\197Lm\204\180\193\232\237[\193\195\175%\226\247\024z\132\144=\022\230\228\019}\145(QN\160mE\235V\238\000\000\0001"
        in
        Tick_curve.Proof.of_string s
      end else begin
        let dummy_proof =
          let open Tock in
          let input = Data_spec.[] in
          let main =
            let one = Cvar.constant Field.one in
            assert_equal one one
          in
          let keypair = generate_keypair input main in
          prove (Keypair.pk keypair) input () main
        in
        Tick.prove (Keys.Step.proving_key) (Keys.Step.input ())
          { Keys.Step.Prover_state.prev_proof = dummy_proof
          ; wrap_vk  = Keys.Wrap.verification_key
          ; prev_state = Blockchain.State.negative_one
          ; update = Block.genesis
          }
          Keys.Step.main
          (Lazy.force base_hash)
      end
    end
  ;;

  let initialize () = ignore (Lazy.force base_proof)

  let extend_blockchain_exn { Blockchain.state=prev_state; proof=prev_proof } block =
    let proof =
      if Insecure.extend_blockchain
      then Lazy.force base_proof
      else Transition_utils.step ~prev_proof ~prev_state block
    in
    { Blockchain.proof; state = Blockchain.State.update_exn prev_state block }
  ;;

  let implementations =
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
               else return (Transition_utils.verify state proof))
        ]
      ~on_unknown_rpc:(`Call (fun () ~rpc_tag ~version ->
        eprintf "prover: unknown rpc: %s %d\n" rpc_tag version;
        `Continue))

  let main () =
    initialize ();
    let%bind server =
      Tcp.Server.create
        ~on_handler_error:(`Call (fun net exn -> eprintf "%s\n" (Exn.to_string_mach exn)))
        (Tcp.Where_to_listen.of_port Params.port)
        (fun address reader writer -> 
          Rpc.Connection.server_with_close
            reader writer
            ~heartbeat_config
            ~implementations
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
