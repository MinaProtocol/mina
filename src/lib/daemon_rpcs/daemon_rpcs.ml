open Core_kernel
open Async
open Coda_base
open Signature_lib
module Types = Types
module Client = Client

module Get_transaction_status = struct
  module Query = struct
    type t = User_command.Stable.V1.t [@@deriving bin_io_unversioned]
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          Transaction_status.State.Stable.V1.t Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_transaction_status" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Send_user_commands = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = User_command_input.Stable.V1.t list

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Network_pool.Transaction_pool.Resource_pool.Diff.Stable.V1.t
          * Network_pool.Transaction_pool.Resource_pool.Diff.Rejected.Stable.V1
            .t )
          Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Send_user_commands" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Get_ledger = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Staged_ledger_hash.Stable.V1.t option

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Account.Stable.V1.t list Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_ledger" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Get_balance = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Account_id.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          Currency.Balance.Stable.V1.t option Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_balance" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Get_trust_status = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Core.Unix.Inet_addr.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Trust_system.Peer_status.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_trust_status" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Get_trust_status_all = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Core.Unix.Inet_addr.Stable.V1.t
          * Trust_system.Peer_status.Stable.V1.t )
          list

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_trust_status_all" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Reset_trust_status = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Core.Unix.Inet_addr.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Trust_system.Peer_status.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Reset_trust_status" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Verify_proof = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          Account_id.Stable.V1.t
          * User_command.Stable.V1.t
          * (Receipt.Chain_hash.Stable.V1.t * User_command.Stable.V1.t list)

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Verify_proof" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Prove_receipt = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Receipt.Chain_hash.Stable.V1.t * Account_id.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          (Receipt.Chain_hash.Stable.V1.t * User_command.Stable.V1.t list)
          Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Prove_receipt" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Get_inferred_nonce = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Account_id.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          Account.Nonce.Stable.V1.t option Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_inferred_nonce" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Get_nonce = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Account_id.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          Account.Nonce.Stable.V1.t option Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_nonce" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Get_status = struct
  type query = [`Performance | `None] [@@deriving bin_io]

  type response = Types.Status.t [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_status" ~version:0 ~bin_query ~bin_response
end

module Clear_hist_status = struct
  type query = [`Performance | `None] [@@deriving bin_io]

  type response = Types.Status.t [@@deriving bin_io]

  let rpc : (query, response) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Clear_hist_status" ~version:0 ~bin_query
      ~bin_response
end

module Get_public_keys_with_details = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = (string * int * int) list Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_public_keys_with_details" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Get_public_keys = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = string list Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_public_keys" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Stop_daemon = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Stop_daemon" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Snark_job_list = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = string Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Snark_job_list" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Snark_pool_list = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = string

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Snark_pool_list" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Start_tracing = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Start_tracing" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Stop_tracing = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Stop_tracing" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Set_staking = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Keypair.Stable.V1.t list

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Set_staking" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Visualization = struct
  module Frontier = struct
    module Query = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t = string

          let to_latest = Fn.id
        end
      end]

      type t = Stable.Latest.t
    end

    module Response = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t = [`Active of unit | `Bootstrapping]

          let to_latest = Fn.id
        end
      end]

      type t = Stable.Latest.t
    end

    let rpc : (Query.t, Response.t) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Visualize_frontier" ~version:0
        ~bin_query:Query.Stable.Latest.bin_t
        ~bin_response:Response.Stable.Latest.bin_t
  end

  module Registered_masks = struct
    module Query = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t = string

          let to_latest = Fn.id
        end
      end]

      type t = Stable.Latest.t
    end

    module Response = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t = unit

          let to_latest = Fn.id
        end
      end]

      type t = Stable.Latest.t
    end

    let rpc : (Query.t, Response.t) Rpc.Rpc.t =
      Rpc.Rpc.create ~name:"Visualize_registered_masks" ~version:0
        ~bin_query:Query.Stable.Latest.bin_t
        ~bin_response:Response.Stable.Latest.bin_t
  end
end

module Add_trustlist = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Core.Unix.Inet_addr.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Add_trustlist" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Remove_trustlist = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Core.Unix.Inet_addr.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit Core_kernel.Or_error.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Remove_trustlist" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

module Get_trustlist = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = unit

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Core.Unix.Inet_addr.Stable.V1.t list

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_trustlist" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end

(** daemon-level Get_telemetry_data; implementation invokes
    Coda_networking's Get_telemetry_data for each provided peer
 *)
module Get_telemetry_data = struct
  module Query = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Network_peer.Peer.Id.Stable.V1.t list option

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  module Response = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          Coda_networking.Rpcs.Get_telemetry_data.Telemetry_data.Stable.V1.t
          Core_kernel.Or_error.Stable.V1.t
          list

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t
  end

  let rpc : (Query.t, Response.t) Rpc.Rpc.t =
    Rpc.Rpc.create ~name:"Get_telemetry_data" ~version:0
      ~bin_query:Query.Stable.Latest.bin_t
      ~bin_response:Response.Stable.Latest.bin_t
end
