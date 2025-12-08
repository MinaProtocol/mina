open Core_kernel
open Mina_base

module Tag_or_data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t =
        | Tag of
            (State_hash.Stable.V1.t, 'a) Multi_key_file_storage.Tag.Stable.V1.t
        | Data of 'a

      let to_latest = Fn.id
    end
  end]
end

module Make' (Data : Binable.S) = struct
  include Bin_prot.Utils.Of_minimal (struct
    type t = Data.t Tag_or_data.t

    let bin_shape_t = Data.bin_shape_t

    let __bin_read_t__ buf ~pos_ref vint =
      Tag_or_data.Data (Data.__bin_read_t__ buf ~pos_ref vint)

    let bin_read_t buf ~pos_ref =
      Tag_or_data.Data (Data.bin_read_t buf ~pos_ref)

    let bin_size_t = function
      | Tag_or_data.Tag tag ->
          State_hash.File_storage.size tag
      | Data x ->
          Data.bin_size_t x

    let bin_write_t buf ~pos = function
      | Tag_or_data.Tag tag ->
          let data =
            State_hash.File_storage.read_bytes tag |> Or_error.ok_exn
          in
          let bs = Bigstring.of_bytes data in
          let len = Bigstring.length bs in
          Bigstring.blit ~src:bs ~src_pos:0 ~dst:buf ~dst_pos:pos ~len ;
          pos + len
      | Data x ->
          Data.bin_write_t buf ~pos x
  end)

  let extract = function
    | Tag_or_data.Tag x ->
        State_hash.File_storage.read (module Data) x
    | Data x ->
        Or_error.return x

  type data_tag = Data.t State_hash.File_storage.tag
end

module Staged_ledger_aux_and_pending_coinbases = struct
  module Data = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]

      module V1 = struct
        type t =
          Staged_ledger.Scan_state.Stable.V2.t
          * Ledger_hash.Stable.V1.t
          * Pending_coinbase.Stable.V2.t
          * Mina_state.Protocol_state.Value.Stable.V2.t list

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      type t = Data.Stable.Latest.t Tag_or_data.t

      let to_latest = Fn.id

      include Make' (Data.Stable.V1)
    end
  end]

  let extract = Stable.Latest.extract

  type data_tag = Stable.Latest.data_tag
end

module Block = struct
  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      type t = Mina_block.Stable.V2.t Tag_or_data.t

      let to_latest = Fn.id

      include Make' (Mina_block.Stable.V2)
    end
  end]

  let extract = Stable.Latest.extract

  type data_tag = Stable.Latest.data_tag
end
