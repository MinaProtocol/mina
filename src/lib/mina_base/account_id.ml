[%%import "/src/config.mlh"]

open Core_kernel
open Mina_base_import

module Make_sig (T : Mina_wire_types.Mina_base.Account_id.Types.S) = struct
  module type S =
    Account_id_intf.S
      with type Digest.Stable.V1.t = T.Digest.V1.t
       and type Stable.V2.t = T.V2.t
end

module Make_str (T : Mina_wire_types.Mina_base.Account_id.Concrete) = struct
  let invalid = (Public_key.Compressed.empty, Pickles.Backend.Tick.Field.zero)

  module Digest = struct
    [%%ifdef consensus_mechanism]

    let of_bigstring_exn =
      Binable.of_bigstring (module Pickles.Backend.Tick.Field.Stable.Latest)

    let to_bigstring =
      Binable.to_bigstring (module Pickles.Backend.Tick.Field.Stable.Latest)

    [%%else]

    let of_bigstring_exn =
      Binable.of_bigstring (module Snark_params.Tick.Field.Stable.Latest)

    let to_bigstring =
      Binable.to_bigstring (module Snark_params.Tick.Field.Stable.Latest)

    [%%endif]

    module Base58_check = Base58_check.Make (struct
      let description = "Token ID"

      let version_byte = Base58_check.Version_bytes.token_id_key
    end)

    let to_base58_check t : string =
      Base58_check.encode (to_bigstring t |> Bigstring.to_string)

    let of_base58_check_exn (s : string) =
      let decoded = Base58_check.decode_exn s in
      decoded |> Bigstring.of_string |> of_bigstring_exn

    let to_string = to_base58_check

    let of_string = of_base58_check_exn

    let of_field = Fn.id

    let to_field_unsafe = Fn.id

    [%%ifdef consensus_mechanism]

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Pickles.Backend.Tick.Field.Stable.V1.t
        [@@deriving sexp, equal, compare, hash]

        let to_yojson (t : t) : Yojson.Safe.t = `String (to_string t)

        let of_yojson (j : Yojson.Safe.t) : (t, string) result =
          try Ok (of_string (Yojson.Safe.Util.to_string j))
          with e -> Error (Exn.to_string e)

        let to_latest = Fn.id
      end
    end]

    [%%else]

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Snark_params.Tick.Field.Stable.V1.t
        [@@deriving sexp, equal, compare, hash]

        let to_yojson (t : t) : Yojson.Safe.t = `String (to_string t)

        let of_yojson (j : Yojson.Safe.t) : (t, string) result =
          try Ok (of_string (Yojson.Safe.Util.to_string j))
          with e -> Error (Exn.to_string e)

        let to_latest = Fn.id
      end
    end]

    [%%endif]

    [%%define_locally Stable.Latest.(of_yojson, to_yojson)]

    include Comparable.Make_binable (Stable.Latest)
    include Hashable.Make_binable (Stable.Latest)

    let to_input : t -> _ Random_oracle_input.Chunked.t =
      Random_oracle_input.Chunked.field

    (* Just matters that this no one can find a preimage to this with poseidon.
       Chose 1 for consistency for the old uint64 based token IDs *)
    let default : t = Snark_params.Tick.Field.one

    let gen : t Quickcheck.Generator.t = Snark_params.Tick.Field.gen

    let gen_non_default =
      Quickcheck.Generator.filter gen ~f:(fun x -> not (equal x default))

    [%%ifdef consensus_mechanism]

    module Checked = struct
      open Pickles.Impls.Step

      type t = Field.t

      let to_input : t -> _ Random_oracle_input.Chunked.t =
        Random_oracle_input.Chunked.field

      let constant : Stable.Latest.t -> t = Field.constant

      let equal : t -> t -> Boolean.var = Field.equal

      let if_ = Field.if_

      let of_field = Fn.id

      let to_field_unsafe = Fn.id

      module Assert = struct
        let equal : t -> t -> unit = Field.Assert.equal
      end
    end

    let typ = Snark_params.Tick.Field.typ

    [%%endif]
  end

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Public_key.Compressed.Stable.V1.t * Digest.Stable.V1.t
      [@@deriving sexp, equal, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let create key tid = (key, tid)

  let empty : t = (Public_key.Compressed.empty, Digest.default)

  let public_key (key, _tid) = key

  let token_id (_key, id) = id

  let to_input ((key, tid) : t) =
    Random_oracle_input.Chunked.(
      append (Public_key.Compressed.to_input key) (field tid))

  let derive_token_id ~(owner : t) : Digest.t =
    Random_oracle.hash ~init:Hash_prefix.derive_token_id
      (Random_oracle.pack_input (to_input owner))

  let gen =
    let open Quickcheck.Let_syntax in
    let%map key = Public_key.Compressed.gen and tid = Digest.gen in
    (key, tid)

  include Comparable.Make_binable (Stable.Latest)
  include Hashable.Make_binable (Stable.Latest)

  let to_input ((key, tid) : t) =
    Random_oracle.Input.Chunked.append
      (Public_key.Compressed.to_input key)
      (Digest.to_input tid)

  [%%ifdef consensus_mechanism]

  type var = Public_key.Compressed.var * Digest.Checked.t

  let typ = Snarky_backendless.Typ.(Public_key.Compressed.typ * Digest.typ)

  let var_of_t ((key, tid) : t) =
    ( Public_key.Compressed.var_of_t key
    , Snark_params.Tick.Field.Var.constant tid )

  module Checked = struct
    open Snark_params
    open Tick

    let create key tid = (key, tid)

    let public_key (key, _tid) = key

    let token_id (_key, tid) = tid

    let to_input ((key, tid) : var) =
      let tid = Digest.Checked.to_input tid in
      Random_oracle.Input.Chunked.append
        (Public_key.Compressed.Checked.to_input key)
        tid

    let derive_token_id ~(owner : var) : Digest.Checked.t =
      Random_oracle.Checked.hash ~init:Hash_prefix.derive_token_id
        (Random_oracle.Checked.pack_input (to_input owner))

    let equal (pk1, tid1) (pk2, tid2) =
      let%bind pk_equal = Public_key.Compressed.Checked.equal pk1 pk2 in
      let%bind tid_equal = Snark_params.Tick.Field.Checked.equal tid1 tid2 in
      Tick.Boolean.(pk_equal && tid_equal)

    let if_ b ~then_:(pk_then, tid_then) ~else_:(pk_else, tid_else) =
      let%bind pk =
        Public_key.Compressed.Checked.if_ b ~then_:pk_then ~else_:pk_else
      in
      let%map tid =
        Snark_params.Tick.Field.Checked.if_ b ~then_:tid_then ~else_:tid_else
      in
      (pk, tid)
  end

  [%%endif]
end

include Mina_wire_types.Mina_base.Account_id.Make (Make_sig) (Make_str)
