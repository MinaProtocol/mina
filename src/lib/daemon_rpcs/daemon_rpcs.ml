open Core_kernel
open Async
open Coda_base
open Signature_lib

module Types = struct
  module Git_sha = struct
    type t = string [@@deriving sexp, yojson, bin_io, eq]

    let of_string s = s
  end

  module Status = struct
    (* NOTE: yojson deriving generates code that violates warning 39 *)
    type t =
      { num_accounts: int
      ; block_count: int
      ; uptime_secs: int
      ; ledger_merkle_root: string
      ; ledger_builder_hash: string
      ; state_hash: string
      ; commit_id: Git_sha.t option
      ; conf_dir: string
      ; peers: string list
      ; user_commands_sent: int
      ; run_snark_worker: bool
      ; external_transition_latency: Perf_histograms.Report.t option
      ; snark_worker_transition_time: Perf_histograms.Report.t option
      ; snark_worker_merge_time: Perf_histograms.Report.t option
      ; propose_pubkey: Public_key.t option }
    [@@deriving to_yojson, bin_io, fields]

    (* Text response *)
    let to_text s =
      let title =
        "Coda Daemon Status\n-----------------------------------\n"
      in
      let entries =
        let f x = Field.get x s in
        let summarize_report
            {Perf_histograms.Report.values; intervals; overflow; underflow} =
          (* Show the largest 3 buckets *)
          let zipped = List.zip_exn values intervals in
          let best =
            List.sort zipped ~compare:(fun (a, _) (a', _) ->
                -1 * Int.compare a a' )
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
              (Printf.sprintf "Total: %d (overflow:%d) (underflow:%d)\n\t"
                 total overflow underflow) ~f:(fun acc x -> acc ^ "\n\t" ^ x )
          ^ "\n\t..."
        in
        Fields.fold ~init:[]
          ~num_accounts:(fun acc x ->
            ("Number of Accounts", Int.to_string (f x)) :: acc )
          ~block_count:(fun acc x ->
            ("Block Count", Int.to_string (f x)) :: acc )
          ~uptime_secs:(fun acc x -> ("Uptime", sprintf "%ds" (f x)) :: acc)
          ~ledger_merkle_root:(fun acc x -> ("Ledger Merkle Root", f x) :: acc)
          ~ledger_builder_hash:(fun acc x ->
            ("Ledger-builder hash", f x) :: acc )
          ~state_hash:(fun acc x -> ("State Hash", f x) :: acc)
          ~commit_id:(fun acc x ->
            match f x with
            | None -> acc
            | Some sha1 ->
                ("Git SHA1", Git_sha.sexp_of_t sha1 |> Sexp.to_string) :: acc
            )
          ~conf_dir:(fun acc x -> ("Configuration Dir", f x) :: acc)
          ~peers:(fun acc x ->
            let peers = f x in
            ( "Peers"
            , Printf.sprintf "Total: %d " (List.length peers)
              ^ List.to_string ~f:Fn.id peers )
            :: acc )
          ~user_commands_sent:(fun acc x ->
            ("User_commands Sent", Int.to_string (f x)) :: acc )
          ~run_snark_worker:(fun acc x ->
            ("Snark Worker Running", Bool.to_string (f x)) :: acc )
          ~external_transition_latency:(fun acc x ->
            match f x with
            | None -> acc
            | Some report ->
                ("Block Latencies (hist.)", summarize_report report) :: acc )
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
                ("Snark Worker Merge (hist.)", summarize_report report) :: acc
            )
          ~propose_pubkey:(fun acc x ->
            match f x with
            | None -> ("Proposer Running", "false") :: acc
            | Some pubkey ->
                ( "Proposer Running"
                , Printf.sprintf !"%{sexp: Public_key.t}" pubkey )
                :: acc )
        |> List.rev
      in
      let max_key_length =
        List.map ~f:(fun (s, _) -> String.length s) entries
        |> List.max_elt ~compare:Int.compare
        |> Option.value_exn
      in
      let output =
        List.map entries ~f:(fun (s, x) ->
            let padding =
              String.init (max_key_length - String.length s) ~f:(fun _ -> ' ')
            in
            sprintf "%s: %s %s" s padding x )
        |> String.concat ~sep:"\n"
      in
      title ^ output ^ "\n"
  end
end

module Send_user_command = struct
  type query = User_command.Stable.V1.t [@@deriving bin_io]

  type response = Receipt.Chain_hash.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Send_user_command" ~version:0 ~bin_query
      ~bin_response
end

module Send_user_commands = struct
  type query = User_command.Stable.V1.t list [@@deriving bin_io]

  type response = unit [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Send_user_commands" ~version:0 ~bin_query
      ~bin_response
end

module Get_ledger = struct
  type query = Ledger_builder_hash.Stable.V1.t [@@deriving bin_io]

  type response = Account.t list Or_error.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_ledger" ~version:0 ~bin_query ~bin_response
end

module Get_balance = struct
  type query = Public_key.Compressed.Stable.V1.t [@@deriving bin_io]

  type response = Currency.Balance.Stable.V1.t option [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_balance" ~version:0 ~bin_query ~bin_response
end

module Verify_proof = struct
  type query =
    Public_key.Compressed.Stable.V1.t * User_command.t * Payment_proof.t
  [@@deriving bin_io]

  type response = unit Or_error.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Verify_proof" ~version:0 ~bin_query ~bin_response
end

module Prove_receipt = struct
  type query = Receipt.Chain_hash.t * Public_key.Compressed.Stable.V1.t
  [@@deriving bin_io]

  type response = Payment_proof.t Or_error.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Prove_receipt" ~version:0 ~bin_query ~bin_response
end

module Get_nonce = struct
  type query = Public_key.Compressed.Stable.V1.t [@@deriving bin_io]

  type response = Account.Nonce.Stable.V1.t option [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_nonce" ~version:0 ~bin_query ~bin_response
end

module Get_status = struct
  type query = unit [@@deriving bin_io]

  type response = Types.Status.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_status" ~version:0 ~bin_query ~bin_response
end

module Clear_hist_status = struct
  type query = unit [@@deriving bin_io]

  type response = Types.Status.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Clear_hist_status" ~version:0 ~bin_query
      ~bin_response
end

module Get_public_keys_with_balances = struct
  type query = unit [@@deriving bin_io]

  type response = (int * string) list [@@deriving bin_io, sexp]

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
