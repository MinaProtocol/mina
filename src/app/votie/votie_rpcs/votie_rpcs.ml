open Core_kernel
open Async_rpc_kernel
open Votie_lib

let registrar = {Host_and_port.host= "0.0.0.0"; port= 8123}

module Vote = struct
  type t = Statement.t * Proof.t [@@deriving bin_io]
end

module Submit_vote = struct
  type query = Vote.t [@@deriving bin_io]

  type response = unit Or_error.t [@@deriving bin_io]

  let rpc =
    Rpc.Rpc.create ~name:"submit-vote" ~version:0 ~bin_query ~bin_response
end

module Votes = struct
  type state = Elections_state.t [@@deriving bin_io]

  type query = unit [@@deriving bin_io]

  type update = Vote.t [@@deriving bin_io]

  let rpc =
    Rpc.State_rpc.create ~name:"votes" ~version:0 ~bin_query ~bin_state
      ~bin_update ~bin_error:Core_kernel.Error.bin_t ()
end

module Path = struct
  type query = Voter.Commitment.t [@@deriving bin_io]

  type response = (int * Hash.t list) Or_error.t [@@deriving bin_io]

  let rpc = Rpc.Rpc.create ~name:"path" ~version:0 ~bin_query ~bin_response
end

module Register = struct
  type query = Voter.Commitment.t [@@deriving bin_io]

  type response = {index: int} [@@deriving bin_io]

  let rpc = Rpc.Rpc.create ~name:"register" ~version:0 ~bin_query ~bin_response
end
