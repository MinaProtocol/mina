open Core_kernel
open Mina_base

module Get_staged_ledger_aux_and_pending_coinbases_at_hash_result = struct
  module Data = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type t =
          (* TODO replace with V2 to fix the incorrect serialization issue *)
          Staged_ledger.Scan_state.Stable.V3.t
          * Ledger_hash.Stable.V1.t
          * Pending_coinbase.Stable.V2.t
          * Mina_state.Protocol_state.Value.Stable.V2.t list

        let to_latest = Fn.id
      end
    end]
  end

  type data_tag = Data.Stable.Latest.t State_hash.File_storage.tag

  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          | Tag of Data.Stable.Latest.t State_hash.File_storage.tag
          | Data of Data.Stable.Latest.t

        let to_latest = Fn.id
      end

      include T

      include
        Binable.Of_binable_without_uuid
          (Data.Stable.V1)
          (struct
            type t = T.t

            let to_binable = function
              | Tag x ->
                  (* TODO This code deserializes the data stored in the file
                     and serializes it back. This is a bad thing to do.
                     But in future we will have a special communication
                     protocol between libp2p helper and daemon to push file reading
                     to the helper, and then we won't have deserialization anymore.
                  *)
                  State_hash.File_storage.read (module Data.Stable.Latest) x
                  |> Or_error.ok_exn
              | Data x ->
                  x

            let of_binable x = Data x
          end)
    end
  end]
end
