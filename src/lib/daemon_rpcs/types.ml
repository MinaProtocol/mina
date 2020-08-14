open Core_kernel
open Async

module Git_sha = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = string [@@deriving sexp, to_yojson, eq]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, to_yojson, eq]

  let of_string s = s
end

module Status = struct
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
      type 'a t = {dispatch: 'a; impl: 'a}
      [@@deriving to_yojson, bin_io_unversioned, fields]
    end

    type t =
      { get_staged_ledger_aux: Perf_histograms.Report.t option Rpc_pair.t
      ; answer_sync_ledger_query: Perf_histograms.Report.t option Rpc_pair.t
      ; get_ancestry: Perf_histograms.Report.t option Rpc_pair.t
      ; get_transition_chain_proof: Perf_histograms.Report.t option Rpc_pair.t
      ; get_transition_chain: Perf_histograms.Report.t option Rpc_pair.t }
    [@@deriving to_yojson, bin_io_unversioned, fields]

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
          |> maybe_cons
               ~f:(fun impl -> (name `Impl, summarize_report impl))
               impl
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
    [@@deriving to_yojson, bin_io_unversioned, fields]

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
                ("Snark Worker a->b (hist.)", summarize_report report) :: acc
            )
          ~snark_worker_merge_time:(fun acc x ->
            match f x with
            | None ->
                acc
            | Some report ->
                ("Snark Worker Merge (hist.)", summarize_report report) :: acc
            )
      in
      digest_entries ~title:"Performance Histograms" entries
  end

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

    let snark_worker =
      map_entry "SNARK worker" ~f:(Option.value ~default:"None")

    let snark_work_fee = int_entry "SNARK work fee"

    let sync_status = map_entry "Sync status" ~f:Sync_status.to_string

    let block_production_keys =
      list_entry "Block producers running" ~to_string:Fn.id

    let histograms = option_entry "Histograms" ~f:Histograms.to_text

    let next_block_production =
      option_entry "Next block will be produced in" ~f:(fun producer_timing ->
          let str time =
            let open Block_time in
            let current_time =
              (* TODO: We will temporarily have to create a time controller
                  until the inversion relationship between GraphQL and the RPC code inverts *)
              Block_time.now
              @@ Block_time.Controller.basic ~logger:(Logger.create ())
            in
            let diff = diff time current_time in
            if Span.(zero < diff) then
              sprintf "in %s" (Span.to_string_hum diff)
            else "Producing a block now..."
          in
          match producer_timing with
          | `Check_again time ->
              sprintf "None this epoch… checking at %s" (str time)
          | `Produce producing_time ->
              str producing_time
          | `Produce_now ->
              "Now" )

    let consensus_time_best_tip =
      option_entry "Best tip consensus time"
        ~f:Consensus.Data.Consensus_time.to_string_hum

    let consensus_time_now =
      map_entry "Consensus time now"
        ~f:Consensus.Data.Consensus_time.to_string_hum

    let consensus_mechanism = string_entry "Consensus mechanism"

    let consensus_configuration =
      let ms_to_string i =
        float_of_int i |> Time.Span.of_ms |> Time.Span.to_string
      in
      (* Time.to_string is safe here because this is for display. *)
      let time_to_string = Fn.compose Time.to_string Block_time.to_time in
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
          ~genesis_state_timestamp:
            (fmt_field "Genesis state timestamp" time_to_string)
        |> List.map ~f:(fun (s, v) -> ("\t" ^ s, v))
        |> digest_entries ~title:""
      in
      map_entry "Consensus configuration" ~f:render

    let addrs_and_ports =
      let render conf =
        let fmt_field name op field = [(name, op (Field.get field conf))] in
        Node_addrs_and_ports.Display.Stable.V1.Fields.to_list
          ~external_ip:(fmt_field "External IP" Fn.id)
          ~bind_ip:(fmt_field "Bind IP" Fn.id)
          ~client_port:(fmt_field "Client port" string_of_int)
          ~libp2p_port:(fmt_field "Libp2p port" string_of_int)
          ~peer:(fun field ->
            let peer = Field.get field conf in
            match peer with
            | Some peer ->
                [("Libp2p PeerID", peer.peer_id)]
            | None ->
                [] )
        |> List.concat
        |> List.map ~f:(fun (s, v) -> ("\t" ^ s, v))
        |> digest_entries ~title:""
      in
      map_entry "Addresses and ports" ~f:render
  end

  type t =
    { num_accounts: int option
    ; blockchain_length: int option
    ; highest_block_length_received: int
    ; uptime_secs: int
    ; ledger_merkle_root: string option
    ; state_hash: string option
    ; commit_id: Git_sha.Stable.Latest.t
    ; conf_dir: string
    ; peers: string list
    ; user_commands_sent: int
    ; snark_worker: string option
    ; snark_work_fee: int
    ; sync_status: Sync_status.Stable.Latest.t
    ; block_production_keys: string list
    ; histograms: Histograms.t option
    ; consensus_time_best_tip:
        Consensus.Data.Consensus_time.Stable.Latest.t option
    ; next_block_production:
        [ `Check_again of Block_time.Stable.Latest.t
        | `Produce of Block_time.Stable.Latest.t
        | `Produce_now ]
        option
    ; consensus_time_now: Consensus.Data.Consensus_time.Stable.Latest.t
    ; consensus_mechanism: string
    ; consensus_configuration: Consensus.Configuration.Stable.Latest.t
    ; addrs_and_ports: Node_addrs_and_ports.Display.Stable.Latest.t }
  [@@deriving to_yojson, bin_io_unversioned, fields]

  let entries (s : t) =
    let module M = Make_entries (struct
      type nonrec 'a t = ([`Read | `Set_and_create], t, 'a) Field.t_with_perm

      let get field = Field.get field s
    end) in
    let open M in
    Fields.to_list ~sync_status ~num_accounts ~blockchain_length
      ~highest_block_length_received ~uptime_secs ~ledger_merkle_root
      ~state_hash ~commit_id ~conf_dir ~peers ~user_commands_sent ~snark_worker
      ~block_production_keys ~histograms ~consensus_time_best_tip
      ~consensus_time_now ~consensus_mechanism ~consensus_configuration
      ~next_block_production ~snark_work_fee ~addrs_and_ports
    |> List.filter_map ~f:Fn.id

  let to_text (t : t) =
    let title = "Coda daemon status\n-----------------------------------\n" in
    digest_entries ~title (entries t)
end
