open Core_kernel
open Async
open Coda_base
open Signature_lib

module Git_sha = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = string [@@deriving sexp, yojson, eq]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, yojson, eq]

  let of_string s = s
end

let digest_entries ~title entries =
  let max_key_length =
    List.map ~f:(fun (s, _) -> String.length s) entries
    |> List.max_elt ~compare:Int.compare
    |> Option.value ~default:0
  in
  let output =
    List.map entries ~f:(fun (s, x) ->
        let padding =
          String.init (max_key_length - String.length s) ~f:(fun _ -> ' ')
        in
        sprintf "%s: %s %s" s padding x )
    |> String.concat ~sep:"\n"
  in
  title ^ "\n" ^ output ^ "\n"

let summarize_report
    {Perf_histograms.Report.values; intervals; overflow; underflow} =
  (* Show the largest 3 buckets *)
  let zipped = List.zip_exn values intervals in
  let best =
    List.sort zipped ~compare:(fun (a, _) (a', _) -> -1 * Int.compare a a')
    |> Fn.flip List.take 4
  in
  let msgs =
    List.map best ~f:(fun (v, (lo, hi)) ->
        Printf.sprintf
          !"(%{sexp: Time.Span.t}, %{sexp: Time.Span.t}): %d"
          lo hi v )
  in
  let total = List.sum (module Int) values ~f:Fn.id in
  List.fold msgs
    ~init:
      (Printf.sprintf "\n\tTotal: %d (overflow:%d) (underflow:%d)\n\t" total
         overflow underflow) ~f:(fun acc x -> acc ^ "\n\t" ^ x)
  ^ "\n\t..."

module Rpc_timings = struct
  module Rpc_pair = struct
    type 'a t = {dispatch: 'a; impl: 'a} [@@deriving yojson, bin_io, fields]
  end

  type t =
    { get_staged_ledger_aux: Perf_histograms.Report.t option Rpc_pair.t
    ; answer_sync_ledger_query: Perf_histograms.Report.t option Rpc_pair.t
    ; get_ancestry: Perf_histograms.Report.t option Rpc_pair.t
    ; get_transition_chain_proof: Perf_histograms.Report.t option Rpc_pair.t
    ; get_transition_chain: Perf_histograms.Report.t option Rpc_pair.t }
  [@@deriving yojson, bin_io, fields]

  let to_text s =
    let entries =
      let add_rpcs ~name {Rpc_pair.dispatch; impl} acc =
        let name k =
          let go s = sprintf "%s (%s)" name s in
          match k with `Dispatch -> go "dispatch" | `Impl -> go "impl"
        in
        let maybe_cons ~f x xs =
          match x with Some x -> f x :: xs | None -> xs
        in
        maybe_cons
          ~f:(fun dispatch -> (name `Dispatch, summarize_report dispatch))
          dispatch acc
        |> maybe_cons ~f:(fun impl -> (name `Impl, summarize_report impl)) impl
      in
      let f x = Field.get x s in
      Fields.fold ~init:[]
        ~get_staged_ledger_aux:(fun acc x ->
          add_rpcs ~name:"Get Staged Ledger Aux" (f x) acc )
        ~answer_sync_ledger_query:(fun acc x ->
          add_rpcs ~name:"Answer Sync Ledger Query" (f x) acc )
        ~get_ancestry:(fun acc x -> add_rpcs ~name:"Get Ancestry" (f x) acc)
        ~get_transition_chain_proof:(fun acc x ->
          add_rpcs ~name:"Get transition chain proof" (f x) acc )
        ~get_transition_chain:(fun acc x ->
          add_rpcs ~name:"Get transition chain" (f x) acc )
      |> List.rev
    in
    digest_entries ~title:"RPCs" entries
end

module Histograms = struct
  type t =
    { rpc_timings: Rpc_timings.t
    ; external_transition_latency: Perf_histograms.Report.t option
    ; accepted_transition_local_latency: Perf_histograms.Report.t option
    ; accepted_transition_remote_latency: Perf_histograms.Report.t option
    ; snark_worker_transition_time: Perf_histograms.Report.t option
    ; snark_worker_merge_time: Perf_histograms.Report.t option }
  [@@deriving yojson, bin_io, fields]

  let to_text s =
    let entries =
      let f x = Field.get x s in
      Fields.fold ~init:[]
        ~rpc_timings:(fun acc x ->
          ("RPC Timings", Rpc_timings.to_text (f x)) :: acc )
        ~external_transition_latency:(fun acc x ->
          match f x with
          | None ->
              acc
          | Some report ->
              ("Block Latencies (hist.)", summarize_report report) :: acc )
        ~accepted_transition_local_latency:(fun acc x ->
          match f x with
          | None ->
              acc
          | Some report ->
              ( "Accepted local block Latencies (hist.)"
              , summarize_report report )
              :: acc )
        ~accepted_transition_remote_latency:(fun acc x ->
          match f x with
          | None ->
              acc
          | Some report ->
              ( "Accepted remote block Latencies (hist.)"
              , summarize_report report )
              :: acc )
        ~snark_worker_transition_time:(fun acc x ->
          match f x with
          | None ->
              acc
          | Some report ->
              ("Snark Worker a->b (hist.)", summarize_report report) :: acc )
        ~snark_worker_merge_time:(fun acc x ->
          match f x with
          | None ->
              acc
          | Some report ->
              ("Snark Worker Merge (hist.)", summarize_report report) :: acc )
    in
    digest_entries ~title:"Performance Histograms" entries
end

type t =
  { num_accounts: int option
  ; blockchain_length: int option
  ; highest_block_length_received: int
  ; uptime_secs: int
  ; ledger_merkle_root: string option
  ; state_hash: string option
  ; commit_id: Git_sha.Stable.V1.t
  ; conf_dir: string
  ; peers: string list
  ; user_commands_sent: int
  ; snark_worker: string option
  ; snark_work_fee: int
  ; sync_status: Sync_status.Stable.V1.t
  ; propose_pubkeys: Public_key.Compressed.Stable.V1.t list
  ; consensus_time_best_tip: Consensus.Data.Consensus_time.Stable.V1.t option
  ; next_proposals: Consensus.Data.Consensus_time.Stable.V1.t list
  ; consensus_time_now: Consensus.Data.Consensus_time.Stable.V1.t
  ; consensus_mechanism: string
  ; consensus_configuration: Consensus.Configuration.t
  ; addrs_and_ports: Kademlia.Node_addrs_and_ports.Display.Stable.V1.t
  ; libp2p_peer_id: string }
[@@deriving yojson, fields]

module Make_entries (FieldT : sig
  type 'a t

  val get : 'a t -> 'a
end) =
struct
  let map_entry ~f (name : string) field = Some (name, f @@ FieldT.get field)

  let string_entry (name : string) (field : string FieldT.t) =
    map_entry ~f:Fn.id name field

  let int_entry = map_entry ~f:Int.to_string

  let bool_entry = map_entry ~f:Bool.to_string

  let option_entry ~(f : 'a -> string) (name : string)
      (field : 'a option FieldT.t) =
    Option.map (FieldT.get field) ~f:(fun x -> (name, f x))

  let string_option_entry = option_entry ~f:Fn.id

  let int_option_entry = option_entry ~f:Int.to_string

  let list_entry name ~to_string =
    map_entry name ~f:(fun keys ->
        let len = List.length keys in
        let list_str =
          if len > 0 then " " ^ List.to_string ~f:to_string keys else ""
        in
        Printf.sprintf "%d%s" len list_str )

  let num_accounts = int_option_entry "Global number of accounts"

  let blockchain_length = int_option_entry "Block height"

  let highest_block_length_received = int_entry "Max observed block length"

  let uptime_secs =
    map_entry "Local uptime" ~f:(fun secs ->
        Time.Span.to_string (Time.Span.of_int_sec secs) )

  let ledger_merkle_root = string_option_entry "Ledger Merkle root"

  let staged_ledger_hash = string_option_entry "Staged-ledger hash"

  let state_hash = string_option_entry "Protocol state hash"

  let commit_id = string_entry "Git SHA-1"

  let conf_dir = string_entry "Configuration directory"

  let peers = list_entry "Peers" ~to_string:Fn.id

  let user_commands_sent = int_entry "User_commands sent"

  let snark_worker = map_entry "SNARK worker" ~f:(Option.value ~default:"None")

  let snark_work_fee = int_entry "SNARK work fee"

  let sync_status = map_entry "Sync status" ~f:Sync_status.to_string

  let propose_pubkeys =
    list_entry "Block producers running"
      ~to_string:Public_key.Compressed.to_base58_check

  let consensus_time_best_tip =
    option_entry "Best tip consensus time"
      ~f:Consensus.Data.Consensus_time.to_string_hum

  let next_proposals =
    map_entry "Next proposal"
      ~f:(fun (next_proposals : Consensus.Data.Consensus_time.t list) ->
        let current_time =
          Block_time.now
          @@ Block_time.Controller.basic ~logger:(Logger.create ())
        in
        match
          List.sort ~compare:Consensus.Data.Consensus_time.compare
            next_proposals
        with
        | [] ->
            let check_again_time =
              Consensus.Data.Consensus_time.to_time
              @@ Consensus.Hooks.check_again_time current_time
            in
            let diff = Block_time.diff check_again_time current_time in
            sprintf
              !"None this epoch... checking at %s"
              (Block_time.Span.to_string_hum diff)
        | soonest_proposal :: next_proposals ->
            let proposing_block_time =
              Consensus.Data.Consensus_time.to_time soonest_proposal
            in
            if Block_time.(current_time <= proposing_block_time) then
              "Proposing now"
            else
              sprintf
                !"Upcoming proposal times in: [%s]"
                ( String.concat ~sep:", "
                @@ List.map (soonest_proposal :: next_proposals)
                     ~f:(fun proposal_time ->
                       let proposing_block_time =
                         Consensus.Data.Consensus_time.to_time proposal_time
                       in
                       let diff =
                         Block_time.diff proposing_block_time current_time
                       in
                       Block_time.Span.to_string_hum diff ) ) )

  let consensus_time_now =
    map_entry "Consensus time now"
      ~f:Consensus.Data.Consensus_time.to_string_hum

  let consensus_mechanism = string_entry "Consensus mechanism"

  let consensus_configuration =
    let ms_to_string i =
      float_of_int i |> Time.Span.of_ms |> Time.Span.to_string
    in
    let render conf =
      let fmt_field name op field = (name, op (Field.get field conf)) in
      Consensus.Configuration.Fields.to_list
        ~delta:(fmt_field "Delta" string_of_int)
        ~k:(fmt_field "k" string_of_int)
        ~c:(fmt_field "c" string_of_int)
        ~c_times_k:(fmt_field "c * k" string_of_int)
        ~slots_per_epoch:(fmt_field "Slots per epoch" string_of_int)
        ~slot_duration:(fmt_field "Slot duration" ms_to_string)
        ~epoch_duration:(fmt_field "Epoch duration" ms_to_string)
        ~acceptable_network_delay:
          (fmt_field "Acceptable network delay" ms_to_string)
      |> List.map ~f:(fun (s, v) -> ("\t" ^ s, v))
      |> digest_entries ~title:""
    in
    map_entry "Consensus configuration" ~f:render

  let addrs_and_ports =
    let render conf =
      let fmt_field name op field = (name, op (Field.get field conf)) in
      Kademlia.Node_addrs_and_ports.Display.Stable.V1.Fields.to_list
        ~external_ip:(fmt_field "External IP" Fn.id)
        ~bind_ip:(fmt_field "Bind IP" Fn.id)
        ~discovery_port:(fmt_field "Haskell Kademlia port" string_of_int)
        ~client_port:(fmt_field "Client port" string_of_int)
        ~libp2p_port:(fmt_field "Discovery (libp2p) port" string_of_int)
        ~communication_port:(fmt_field "External port" string_of_int)
      |> List.map ~f:(fun (s, v) -> ("\t" ^ s, v))
      |> digest_entries ~title:""
    in
    map_entry "Addresses and ports" ~f:render

  let libp2p_peer_id = string_entry "Libp2p PeerID"
end

let entries (s : t) =
  let module M = Make_entries (struct
    type nonrec 'a t = ([`Read | `Set_and_create], t, 'a) Field.t_with_perm

    let get field = Field.get field s
  end) in
  let open M in
  Fields.to_list ~sync_status ~num_accounts ~blockchain_length
    ~highest_block_length_received ~uptime_secs ~ledger_merkle_root ~state_hash
    ~commit_id ~conf_dir ~peers ~user_commands_sent ~snark_worker
    ~propose_pubkeys ~consensus_time_best_tip ~consensus_time_now
    ~consensus_mechanism ~consensus_configuration ~next_proposals
    ~snark_work_fee ~addrs_and_ports ~libp2p_peer_id
  |> List.filter_map ~f:Fn.id

let to_text (t : t) =
  let title = "Coda daemon status\n-----------------------------------\n" in
  digest_entries ~title (entries t)

let start_time = Time_ns.now ()

let num_accounts =
  Option.map ~f:(fun best_tip ->
      Transition_frontier.Breadcrumb.staged_ledger best_tip
      |> Staged_ledger.ledger |> Ledger.num_accounts )

let blockchain_length =
  Option.map ~f:(fun best_tip ->
      let consensus_state =
        Transition_frontier.Breadcrumb.consensus_state best_tip
      in
      Coda_numbers.Length.to_int
      @@ Consensus.Data.Consensus_state.blockchain_length consensus_state )

let highest_block_length_received coda =
  Coda_numbers.Length.to_int
  @@ Consensus.Data.Consensus_state.blockchain_length
  @@ Coda_transition.External_transition.consensus_state
  @@ Pipe_lib.Broadcast_pipe.Reader.peek
       (Coda_lib.most_recent_valid_transition coda)

let uptime_secs () =
  Time_ns.diff (Time_ns.now ()) start_time
  |> Time_ns.Span.to_sec |> Int.of_float

let ledger_merkle_root =
  Option.map ~f:(fun best_tip ->
      Transition_frontier.Breadcrumb.blockchain_state best_tip
      |> Coda_state.Blockchain_state.staged_ledger_hash
      |> Staged_ledger_hash.ledger_hash |> Ledger_hash.to_string )

let state_hash =
  Option.map ~f:(fun best_tip ->
      Transition_frontier.Breadcrumb.state_hash best_tip
      |> State_hash.to_string )

let commit_id = Coda_version.commit_id

let conf_dir coda = (Coda_lib.config coda).conf_dir

let peers coda =
  List.map (Coda_lib.peers coda) ~f:(fun peer ->
      Network_peer.Peer.to_discovery_host_and_port peer
      |> Host_and_port.to_string )

let user_commands_sent () = !Coda_commands.txn_count

let snark_worker coda =
  Option.map
    (Coda_lib.snark_worker_key coda)
    ~f:Public_key.Compressed.to_base58_check

let snark_work_fee coda = Currency.Fee.to_int @@ Coda_lib.snark_work_fee coda

let sync_status coda =
  Coda_incremental.Status.stabilize () ;
  Coda_incremental.Status.Observer.value_exn @@ Coda_lib.sync_status coda

let propose_public_keys coda =
  Coda_lib.propose_public_keys coda |> Public_key.Compressed.Set.to_list

let histograms () =
  let r = Perf_histograms.report in
  let rpc_timings =
    let open Rpc_timings in
    { get_staged_ledger_aux=
        { Rpc_pair.dispatch= r ~name:"rpc_dispatch_get_staged_ledger_aux"
        ; impl= r ~name:"rpc_impl_get_staged_ledger_aux" }
    ; answer_sync_ledger_query=
        { Rpc_pair.dispatch= r ~name:"rpc_dispatch_answer_sync_ledger_query"
        ; impl= r ~name:"rpc_impl_answer_sync_ledger_query" }
    ; get_ancestry=
        { Rpc_pair.dispatch= r ~name:"rpc_dispatch_get_ancestry"
        ; impl= r ~name:"rpc_impl_get_ancestry" }
    ; get_transition_chain_proof=
        { Rpc_pair.dispatch= r ~name:"rpc_dispatch_get_transition_chain_proof"
        ; impl= r ~name:"rpc_impl_get_transition_chain_proof" }
    ; get_transition_chain=
        { Rpc_pair.dispatch= r ~name:"rpc_dispatch_get_transition_chain"
        ; impl= r ~name:"rpc_impl_get_transition_chain" } }
  in
  { Histograms.rpc_timings
  ; external_transition_latency= r ~name:"external_transition_latency"
  ; accepted_transition_local_latency=
      r ~name:"accepted_transition_local_latency"
  ; accepted_transition_remote_latency=
      r ~name:"accepted_transition_remote_latency"
  ; snark_worker_transition_time= r ~name:"snark_worker_transition_time"
  ; snark_worker_merge_time= r ~name:"snark_worker_merge_time" }

let consensus_time_best_tip =
  Option.map ~f:(fun best_tip ->
      Transition_frontier.Breadcrumb.consensus_state best_tip
      |> Consensus.Data.Consensus_state.consensus_time )

let consensus_time_of_int64 time =
  time |> Block_time.Span.of_ms |> Block_time.of_span_since_epoch
  |> Consensus.Data.Consensus_time.of_time_exn

let next_proposals coda =
  Option.value_map ~default:[] (Coda_lib.next_proposal coda) ~f:(function
    | `Propose_now (_, _) ->
        [ Consensus.Data.Consensus_time.of_time_exn
            (Block_time.now (Coda_lib.config coda).time_controller) ]
    | `Propose value ->
        let time, _, _ = value in
        [consensus_time_of_int64 time]
    | `Check_again _ ->
        [] )

let consensus_time_now coda =
  Consensus.Data.Consensus_time.of_time_exn
  @@ Block_time.now (Coda_lib.config coda).time_controller

let consensus_mechanism = Consensus.name

let consensus_configuration = Consensus.Configuration.t

let addrs_and_ports coda =
  Kademlia.Node_addrs_and_ports.to_display
    (Coda_lib.config coda).gossip_net_params.addrs_and_ports

let libp2p_peer_id coda =
  Option.value ~default:"<not connected to libp2p>"
    Option.(
      Coda_lib.net coda |> Coda_networking.net2 >>= Coda_net2.me
      >>| Coda_net2.Keypair.to_peerid >>| Coda_net2.PeerID.to_string)

let create coda =
  let best_tip = Participating_state.active @@ Coda_lib.best_tip coda in
  { num_accounts= num_accounts best_tip
  ; blockchain_length= blockchain_length best_tip
  ; highest_block_length_received= highest_block_length_received coda
  ; uptime_secs= uptime_secs ()
  ; ledger_merkle_root= ledger_merkle_root best_tip
  ; state_hash= state_hash best_tip
  ; commit_id
  ; conf_dir= conf_dir coda
  ; peers= peers coda
  ; user_commands_sent= user_commands_sent ()
  ; snark_worker= snark_worker coda
  ; snark_work_fee= snark_work_fee coda
  ; sync_status= sync_status coda
  ; propose_pubkeys= propose_public_keys coda
  ; consensus_time_best_tip= consensus_time_best_tip best_tip
  ; next_proposals= next_proposals coda
  ; consensus_time_now= consensus_time_now coda
  ; consensus_mechanism
  ; consensus_configuration
  ; addrs_and_ports= addrs_and_ports coda
  ; libp2p_peer_id= libp2p_peer_id coda }
