open Core_kernel
open Mina_base

module Entry = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | Header of Mina_block.Header.Stable.V2.t
        | Invalid of
            { parent_state_hash : State_hash.Stable.V1.t
            ; blockchain_length : Mina_numbers.Length.Stable.V1.t
                  (* This field is set only if at the time of transition's
                     invalidation, body was present in block storage *)
            ; body_ref : Consensus.Body_reference.Stable.V1.t option
            }
      [@@deriving bin_io, version { binable }]

      let to_latest = Fn.id
    end
  end]
end

module F (Db : Generic.Db) = struct
  type holder = (State_hash.t, Entry.t) Db.t

  let mk_maps { Db.create } =
    create
      (Conv.bin_prot_conv State_hash.Stable.Latest.bin_t)
      (Conv.bin_prot_conv Entry.Stable.Latest.bin_t)

  let config = { Generic.default_config with initial_mmap_size = 16 lsl 20 }
end

module Storage = Generic.Read_write (F)

type t = Storage.t * Storage.holder

let iter (env, db) = Storage.iter ~env db

let set (env, db) = Storage.set ~env db

let remove (env, db) = Storage.remove ~env db

let create = Storage.create

let get (env, db) = Storage.get ~env db
