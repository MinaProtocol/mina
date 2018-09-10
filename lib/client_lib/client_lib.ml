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
    let output = "Coda Daemon Status\n" in
    let output =
      output ^ sprintf "Uptime:             \t%ds\n" s.uptime_secs
    in
    let output = output ^ sprintf "Block Count:        \t%d\n" s.block_count in
    let output =
      output ^ sprintf "Number of Accounts: \t%d\n" s.num_accounts
    in
    let output =
      output ^ sprintf "Transactions Sent:  \t%d\n" s.transactions_sent
    in
    let output =
      output ^ sprintf "Snark Worker Running: \t%B\n" s.run_snark_worker
    in
    let output = output ^ sprintf "Proposer Running: \t%B\n" s.propose in
    let output = output ^ sprintf "Peers: \t" in
    let output = output ^ List.to_string ~f:Fn.id s.peers in
    output
end

module Get_status = struct
  type query = unit [@@deriving bin_io]

  type response = Status.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_status" ~version:0 ~bin_query ~bin_response
end
