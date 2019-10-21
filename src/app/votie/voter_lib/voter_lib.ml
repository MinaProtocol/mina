open Core
open Async
open Votie_lib

let daemon = {Host_and_port.host= "0.0.0.0"; port= 8812}

module Rpcs = struct
  module Elections_status = struct
    type response = Election_status.t Election_description.Map.t
    [@@deriving bin_io]

    type query = unit [@@deriving bin_io]

    let rpc =
      Rpc.Rpc.create ~name:"elections-state" ~version:0 ~bin_query
        ~bin_response
  end

  module Vote = struct
    type response = unit Or_error.t [@@deriving bin_io]

    type query = {witness: Snark.Witness.t; election: string; vote: Vote.t}
    [@@deriving bin_io]

    let rpc =
      Rpc.Rpc.create ~name:"elections-state" ~version:0 ~bin_query
        ~bin_response
  end
end
