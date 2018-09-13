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
    ; ledger_merkle_root: string
    ; conf_dir: string
    ; peers: string list
    ; transactions_sent: int
    ; run_snark_worker: bool
    ; propose: bool }
  [@@deriving yojson, bin_io, fields]

  (* Text response *)
  let to_text s =
    let title = "Coda Daemon Status\n-----------------------------------\n" in
    let entries =
      let f x = Field.get x s in
      Fields.fold ~init:[]
        ~num_accounts:(fun acc x ->
          ("Number of Accounts", Int.to_string (f x)) :: acc )
        ~block_count:(fun acc x -> ("Block Count", Int.to_string (f x)) :: acc)
        ~uptime_secs:(fun acc x -> ("Uptime", sprintf "%ds" (f x)) :: acc)
        ~ledger_merkle_root:(fun acc x -> ("Ledger Merkle Root", f x) :: acc)
        ~conf_dir:(fun acc x -> ("Configuration Dir", f x) :: acc)
        ~peers:(fun acc x -> ("Peers", List.to_string ~f:Fn.id (f x)) :: acc)
        ~transactions_sent:(fun acc x ->
          ("Transactions Sent", Int.to_string (f x)) :: acc )
        ~run_snark_worker:(fun acc x ->
          ("Snark Worker Running", Bool.to_string (f x)) :: acc )
        ~propose:(fun acc x ->
          ("Proposer Running", Bool.to_string (f x)) :: acc )
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

module Get_status = struct
  type query = unit [@@deriving bin_io]

  type response = Status.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_status" ~version:0 ~bin_query ~bin_response
end
