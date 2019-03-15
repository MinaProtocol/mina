open Core_kernel
open Async
open Coda_base
open Signature_lib

module Types = struct
  module Git_sha = struct
    type t = string [@@deriving sexp, to_yojson, bin_io, eq]

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
          (Printf.sprintf "Total: %d (overflow:%d) (underflow:%d)\n\t" total
             overflow underflow) ~f:(fun acc x -> acc ^ "\n\t" ^ x )
      ^ "\n\t..."

    module Rpc_timings = struct
      module Rpc_pair = struct
        type 'a t = {dispatch: 'a; impl: 'a}
        [@@deriving to_yojson, bin_io, fields]
      end

      type t =
        { get_staged_ledger_aux: Perf_histograms.Report.t option Rpc_pair.t
        ; answer_sync_ledger_query: Perf_histograms.Report.t option Rpc_pair.t
        ; get_ancestry: Perf_histograms.Report.t option Rpc_pair.t
        ; transition_catchup: Perf_histograms.Report.t option Rpc_pair.t }
      [@@deriving to_yojson, bin_io, fields]

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
            ~transition_catchup:(fun acc x ->
              add_rpcs ~name:"Transition Catchup" (f x) acc )
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
      [@@deriving to_yojson, bin_io, fields]

      let to_text s =
        let entries =
          let f x = Field.get x s in
          Fields.fold ~init:[]
            ~rpc_timings:(fun acc x ->
              ("RPC Timings", Rpc_timings.to_text (f x)) :: acc )
            ~external_transition_latency:(fun acc x ->
              match f x with
              | None -> acc
              | Some report ->
                  ("Block Latencies (hist.)", summarize_report report) :: acc
              )
            ~accepted_transition_local_latency:(fun acc x ->
              match f x with
              | None -> acc
              | Some report ->
                  ( "Accepted local block Latencies (hist.)"
                  , summarize_report report )
                  :: acc )
            ~accepted_transition_remote_latency:(fun acc x ->
              match f x with
              | None -> acc
              | Some report ->
                  ( "Accepted remote block Latencies (hist.)"
                  , summarize_report report )
                  :: acc )
            ~snark_worker_transition_time:(fun acc x ->
              match f x with
              | None -> acc
              | Some report ->
                  ("Snark Worker a->b (hist.)", summarize_report report) :: acc
              )
            ~snark_worker_merge_time:(fun acc x ->
              match f x with
              | None -> acc
              | Some report ->
                  ("Snark Worker Merge (hist.)", summarize_report report)
                  :: acc )
        in
        digest_entries ~title:"Performance Histograms" entries
    end

    module Make_entries (FieldT : sig
      type 'a t

      val get : 'a t -> 'a
    end) =
    struct
      let map_entry ~f (name : string) field =
        Some (name, f @@ FieldT.get field)

      let string_entry (name : string) (field : string FieldT.t) =
        map_entry ~f:Fn.id name field

      let int_entry = map_entry ~f:Int.to_string

      let bool_entry = map_entry ~f:Bool.to_string

      let option_entry ~(f : 'a -> string) (name : string)
          (field : 'a option FieldT.t) =
        match FieldT.get field with None -> None | Some x -> Some (name, f x)

      let string_option_entry = option_entry ~f:Fn.id

      let int_option_entry = option_entry ~f:Int.to_string

      let num_accounts = int_option_entry "Global Number of Accounts"

      let block_count = int_option_entry "Block Count"

      let uptime_secs = map_entry "Local Uptime" ~f:(sprintf "%ds")

      let ledger_merkle_root = string_option_entry "Ledger Merkle Root"

      let staged_ledger_hash = string_option_entry "Staged-ledger Hash"

      let state_hash = string_option_entry "Staged Hash"

      let commit_id =
        option_entry "GIT SHA1"
          ~f:(Fn.compose Sexp.to_string Git_sha.sexp_of_t)

      let conf_dir = string_entry "Configuration Directory"

      let peers =
        map_entry "Peers" ~f:(fun peers ->
            Printf.sprintf "Total: %d " (List.length peers)
            ^ List.to_string ~f:Fn.id peers )

      let user_commands_sent = int_entry "User_commands Sent"

      let run_snark_worker = bool_entry "Snark Worker Running"

      let is_bootstrapping = bool_entry "Is Bootstrapping"

      let propose_pubkey =
        map_entry "Proposer Running"
          ~f:
            (Option.value_map ~default:"false"
               ~f:(Printf.sprintf !"%{sexp: Public_key.t}"))

      let histograms = option_entry "Histograms" ~f:Histograms.to_text

      let consensus_time_best_tip =
        string_option_entry "Best Tip Consensus Time"

      let consensus_time_now = string_entry "Consensus Time Now"

      let consensus_mechanism = string_entry "Consensus Mechanism"

      let consensus_configuration =
        let render conf =
          match Consensus.Configuration.to_yojson conf with
          | `Assoc ls ->
              List.fold_left ls ~init:"" ~f:(fun acc (k, v) ->
                  acc ^ sprintf "\n    %s = %s" k (Yojson.Safe.to_string v) )
              ^ "\n"
          | _ -> failwith "unexpected consensus configuration json format"
        in
        map_entry "Consensus Configuration" ~f:render
    end

    type t =
      { num_accounts: int option
      ; block_count: int option
      ; uptime_secs: int
      ; ledger_merkle_root: string option
      ; staged_ledger_hash: string option
      ; state_hash: string option
      ; commit_id: Git_sha.t option
      ; conf_dir: string
      ; peers: string list
      ; user_commands_sent: int
      ; run_snark_worker: bool
      ; is_bootstrapping: bool
      ; propose_pubkey: Public_key.t option
      ; histograms: Histograms.t option
      ; consensus_time_best_tip: string option
      ; consensus_time_now: string
      ; consensus_mechanism: string
      ; consensus_configuration: Consensus.Configuration.t }
    [@@deriving to_yojson, bin_io, fields]

    let entries (s : t) =
      let module M = Make_entries (struct
        type nonrec 'a t = ([`Read | `Set_and_create], t, 'a) Field.t_with_perm

        let get field = Field.get field s
      end) in
      let open M in
      Fields.to_list ~is_bootstrapping ~num_accounts ~block_count ~uptime_secs
        ~ledger_merkle_root ~staged_ledger_hash ~state_hash ~commit_id
        ~conf_dir ~peers ~user_commands_sent ~run_snark_worker ~propose_pubkey
        ~histograms ~consensus_time_best_tip ~consensus_time_now
        ~consensus_mechanism ~consensus_configuration
      |> List.filter_map ~f:Fn.id

    let to_text (t : t) =
      let title =
        "Coda Daemon Status\n-----------------------------------\n"
      in
      digest_entries ~title (entries t)
  end
end

module Send_user_command = struct
  type query = User_command.Stable.Latest.t [@@deriving bin_io]

  type response = Receipt.Chain_hash.t Or_error.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Send_user_command" ~version:0 ~bin_query
      ~bin_response
end

module Send_user_commands = struct
  type query = User_command.Stable.Latest.t list [@@deriving bin_io]

  type response = unit [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Send_user_commands" ~version:0 ~bin_query
      ~bin_response
end

module Get_ledger = struct
  type query = Staged_ledger_hash.Stable.Latest.t [@@deriving bin_io]

  type response = Account.Stable.V1.t list Or_error.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_ledger" ~version:0 ~bin_query ~bin_response
end

module Get_balance = struct
  type query = Public_key.Compressed.Stable.Latest.t [@@deriving bin_io]

  type response = Currency.Balance.Stable.Latest.t option [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_balance" ~version:0 ~bin_query ~bin_response
end

module Verify_proof = struct
  type query =
    Public_key.Compressed.Stable.Latest.t * User_command.t * Payment_proof.t
  [@@deriving bin_io]

  type response = unit Or_error.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Verify_proof" ~version:0 ~bin_query ~bin_response
end

module Prove_receipt = struct
  type query = Receipt.Chain_hash.t * Public_key.Compressed.Stable.Latest.t
  [@@deriving bin_io]

  type response = Payment_proof.t Or_error.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Prove_receipt" ~version:0 ~bin_query ~bin_response
end

module Get_nonce = struct
  type query = Public_key.Compressed.Stable.Latest.t [@@deriving bin_io]

  type response = Account.Nonce.Stable.Latest.t option [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_nonce" ~version:0 ~bin_query ~bin_response
end

module Get_status = struct
  type query = [`Performance | `None] [@@deriving bin_io]

  type response = Types.Status.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_status" ~version:0 ~bin_query ~bin_response
end

module Clear_hist_status = struct
  type query = [`Performance | `None] [@@deriving bin_io]

  type response = Types.Status.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Clear_hist_status" ~version:0 ~bin_query
      ~bin_response
end

module Get_public_keys_with_balances = struct
  type query = unit [@@deriving bin_io]

  type response = (string * int) list [@@deriving bin_io, sexp]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_public_keys_with_balances" ~version:0 ~bin_query
      ~bin_response
end

module Get_public_keys = struct
  type query = unit [@@deriving bin_io]

  type response = string list [@@deriving bin_io, sexp]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_public_keys" ~version:0 ~bin_query ~bin_response
end

module Stop_daemon = struct
  type query = unit [@@deriving bin_io]

  type response = unit [@@deriving bin_io]

  type error = unit

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Stop_daemon" ~version:0 ~bin_query ~bin_response
end

module Snark_job_list = struct
  type query = unit [@@deriving bin_io]

  type response = string [@@deriving bin_io]

  type error = unit

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Snark_job_list" ~version:0 ~bin_query ~bin_response
end

module Start_tracing = struct
  type query = unit [@@deriving bin_io]

  type response = unit [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Start_tracing" ~version:0 ~bin_query ~bin_response
end

module Stop_tracing = struct
  type query = unit [@@deriving bin_io]

  type response = unit [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Stop_tracing" ~version:0 ~bin_query ~bin_response
end

module Visualize_frontier = struct
  type query = string [@@deriving bin_io]

  type response = [`Active of unit | `Bootstrapping] [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Visualize_frontier" ~version:0 ~bin_query
      ~bin_response
end
