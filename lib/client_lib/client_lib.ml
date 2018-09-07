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
    { num_accounts : int
    ; block_count : int
    ; uptime_secs : int
    ; conf_dir : string
    ; peers : string list
    ; transactions_sent : int
    ; run_snark_worker : bool
    ; propose : bool
    }
  [@@deriving yojson, bin_io]
end

module Get_status = struct
  type query = unit [@@deriving bin_io]

  type response = Status.t [@@deriving bin_io]

  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_status" ~version:0 ~bin_query ~bin_response
end


