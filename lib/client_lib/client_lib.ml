open Core_kernel
open Async
open Nanobit_base

module Send_transaction = struct
  type query = Public_key.t * Transaction.Payload.t [@@deriving bin_io]
  type response = unit [@@deriving bin_io]
  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Send_transaction" ~version:0
      ~bin_query ~bin_response
end

module Get_balance = struct
  type query = Public_key.t [@@deriving bin_io]
  type response = Balance.Amount.t [@@deriving bin_io]
  type error = unit [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_balance" ~version:0
      ~bin_query ~bin_response
end

