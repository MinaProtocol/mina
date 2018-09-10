open Core_kernel
open Async
open Nanobit_base
open Signature_lib

module Send_transaction = struct
  type query = Transaction.Stable.V1.t [@@deriving bin_io]

  type response = unit [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Send_transaction" ~version:0 ~bin_query ~bin_response
end

module Get_balance = struct
  type query = Public_key.Compressed.Stable.V1.t [@@deriving bin_io]

  type response = Currency.Balance.Stable.V1.t option [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_balance" ~version:0 ~bin_query ~bin_response
end

module Get_nonce = struct
  type query = Public_key.Compressed.Stable.V1.t [@@deriving bin_io]

  type response = Account.Nonce.Stable.V1.t option [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_nonce" ~version:0 ~bin_query ~bin_response
end

module Status = struct
  (* NOTE: yojson deriving generates code that violates warning 39 *)
  type t =
    { num_accounts: int
    ; block_count: int
    ; uptime_secs: int
    ; conf_dir: string
    ; peers: string list
    ; transactions_sent: int
    ; run_snark_worker: bool
    ; propose: bool }
  [@@deriving yojson, bin_io]

  (* Text response *)
  let to_text s =
    let title = "Coda Daemon Status\n-----------------------------------\n" in
    let entries =
      [ ("Uptime", sprintf "%ds" s.uptime_secs)
      ; ("Block Count", Int.to_string s.block_count)
      ; ("Number of Accounts", Int.to_string s.num_accounts)
      ; ("Transactions Sent", Int.to_string s.transactions_sent)
      ; ("Snark Worker Running", Bool.to_string s.run_snark_worker)
      ; ("Proposer Running", Bool.to_string s.propose)
      ; ("Peers", List.to_string ~f:Fn.id s.peers) ]
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
          sprintf "%s: %s\t%s" s padding x )
      |> String.concat ~sep:"\n"
    in
    title ^ output ^ "\n"
end

module Get_status = struct
  type query = unit [@@deriving bin_io]

  type response = Status.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_status" ~version:0 ~bin_query ~bin_response
end
