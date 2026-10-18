open Core_kernel
open Mina_base

module Hash = struct
  include Ledger_hash.Stable.V1

  let to_base58_check = Ledger_hash.to_base58_check

  let merge = Ledger_hash.merge

  let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

  let empty_account = Ledger_hash.of_digest (Lazy.force Account.empty_digest)
end

module Root_hash = struct
  include Ledger_hash

  let to_hash (h : t) = Ledger_hash.of_digest (h :> Random_oracle.Digest.t)
end

module Mask = Syncable_ledger.Make (struct
  module Addr = Ledger.Location.Addr
  module MT = Ledger
  module Account = Account.Stable.Latest
  module Hash = Hash
  module Root_hash = Root_hash

  let account_subtree_height = 6
end)

module Any_ledger = Syncable_ledger.Make (struct
  module Addr = Ledger.Location.Addr
  module MT = Ledger.Any_ledger.M
  module Account = Account.Stable.Latest
  module Hash = Hash
  module Root_hash = Root_hash

  let account_subtree_height = 6
end)

module Root = Syncable_ledger.Make (struct
  module Addr = Ledger.Location.Addr
  module MT = Root
  module Account = Account.Stable.Latest
  module Hash = Hash
  module Root_hash = Root_hash

  let account_subtree_height = 6
end)

module Answer = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V4 = struct
      type t =
        ( Ledger_hash.Stable.V1.t
        , Account.Stable.V3.t )
        Syncable_ledger.Answer.Stable.V2.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  (* unused `rec` flag warning *)
  [@@@warning "-39"]

  (* TODO: generate this in ppx_version: issue #12111 *)
  type t = (Ledger_hash.t, Account.t) Syncable_ledger.Answer.t
    constraint t = Stable.Latest.t
  [@@deriving sexp, to_yojson]

  (** An account in an answer, either decoded or as the bytes of its
      [Account.Stable.V3] encoding, such as those stored in a ledger database.
      Both forms encode identically and share [Account.Stable.V3]'s shape, so a
      responder can forward stored accounts without decoding them. Decoding
      always produces [Decoded].
  *)
  module Raw_account = struct
    type t = Raw of Bigstring.t | Decoded of Account.Stable.V3.t

    let to_account = function
      | Raw bytes ->
          Account.Stable.V3.bin_read_t bytes ~pos_ref:(ref 0)
      | Decoded account ->
          account

    let sexp_of_t t = Account.Stable.V3.sexp_of_t (to_account t)

    let t_of_sexp sexp = Decoded (Account.Stable.V3.t_of_sexp sexp)

    let bin_shape_t = Account.Stable.V3.bin_shape_t

    let bin_size_t = function
      | Raw bytes ->
          Bigstring.length bytes
      | Decoded account ->
          Account.Stable.V3.bin_size_t account

    let bin_write_t buf ~pos = function
      | Raw bytes ->
          let len = Bigstring.length bytes in
          Bigstring.blit ~src:bytes ~src_pos:0 ~dst:buf ~dst_pos:pos ~len ;
          pos + len
      | Decoded account ->
          Account.Stable.V3.bin_write_t buf ~pos account

    let bin_read_t buf ~pos_ref =
      Decoded (Account.Stable.V3.bin_read_t buf ~pos_ref)

    let __bin_read_t__ _buf ~pos_ref _vint =
      Bin_prot.Common.raise_variant_wrong_type
        "Sync_ledger.Answer.Raw_account.t" !pos_ref

    let bin_writer_t : t Bin_prot.Type_class.writer =
      { size = bin_size_t; write = bin_write_t }

    let bin_reader_t : t Bin_prot.Type_class.reader =
      { read = bin_read_t; vtag_read = __bin_read_t__ }

    let bin_t : t Bin_prot.Type_class.t =
      { shape = bin_shape_t; writer = bin_writer_t; reader = bin_reader_t }
  end

  (** An answer whose accounts may be held as their stored encodings. It has
      the same shape and encoding as [Stable.Latest.t]. *)
  module With_raw_accounts = struct
    type t =
      ( Ledger_hash.Stable.V1.t
      , Raw_account.t )
      Syncable_ledger.Answer.Stable.V2.t
    [@@deriving sexp, bin_io_unversioned]

    let of_answer : Stable.Latest.t -> t = function
      | Child_hashes_are hashes ->
          Child_hashes_are hashes
      | Contents_are accounts ->
          Contents_are (List.map accounts ~f:(fun a -> Raw_account.Decoded a))
      | Num_accounts (count, hash) ->
          Num_accounts (count, hash)

    let to_answer : t -> Stable.Latest.t = function
      | Child_hashes_are hashes ->
          Child_hashes_are hashes
      | Contents_are accounts ->
          Contents_are (List.map accounts ~f:Raw_account.to_account)
      | Num_accounts (count, hash) ->
          Num_accounts (count, hash)
  end
end

module Query = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        Ledger.Location.Addr.Stable.V1.t Syncable_ledger.Query.Stable.V2.t
      [@@deriving sexp, to_yojson, hash, compare]

      let to_latest = Fn.id
    end

    module V1 = struct
      type t =
        Ledger.Location.Addr.Stable.V1.t Syncable_ledger.Query.Stable.V1.t
      [@@deriving sexp, to_yojson, hash, compare]

      let to_latest : t -> V2.t = Syncable_ledger.Query.Stable.V1.to_latest

      (* Not a standard versioning function *)

      (* Attempts to downgrade v2 -> v1 *)
      let from_v2 : V2.t -> t = function
        | What_child_hashes (a, _) ->
            What_child_hashes a
        | What_contents a ->
            What_contents a
        | Num_accounts ->
            Num_accounts
    end
  end]

  (* unused `rec` flag warning *)
  [@@@warning "-39"]

  (* TODO: generate this in ppx_version: issue #12111 *)
  type t = Ledger.Location.Addr.t Syncable_ledger.Query.t
    constraint t = Stable.Latest.t
  [@@deriving sexp, to_yojson, hash, compare]
end
