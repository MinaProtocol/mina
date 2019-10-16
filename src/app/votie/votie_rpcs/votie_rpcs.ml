open Core_kernel
open Async_rpc_kernel
open Votie_lib

let server_address = "0.0.0.0"
let server_port = 8123

module Path = struct
  type query = { index : int } [@@deriving bin_io]

  type response = Hash.t list
  [@@deriving bin_io]

  let rpc =
    Rpc.Rpc.create ~name:"path"
      ~version:0
      ~bin_query
      ~bin_response
end

module Register = struct
  type query = Voter.Commitment.t [@@deriving bin_io]

  type response = { index : int }
  [@@deriving bin_io]

  let rpc =
    Rpc.Rpc.create ~name:"register"
      ~version:0
      ~bin_query
      ~bin_response
end
