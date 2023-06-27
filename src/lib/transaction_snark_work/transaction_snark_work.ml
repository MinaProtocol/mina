open Core_kernel
open Currency
open Signature_lib

module With_hash = struct
  type 'a t = { hash : int; data : 'a }

  let create ~f data =
    O1trace.sync_thread "snark_work_with_hash_create"
    @@ fun () ->
    { hash =
        Ppx_hash_lib.Std.Hash.of_fold
          (One_or_two.hash_fold_t Transaction_snark.Statement.hash_fold_t)
          (f data)
    ; data
    }

  let hash { hash; _ } = hash

  let map ~f { hash; data } = { hash; data = f data }

  let data { data; _ } = data
end

module Statement = struct
  module Arg = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t = Transaction_snark.Statement.Stable.V2.t One_or_two.Stable.V1.t
        [@@deriving hash, sexp, compare]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t = Transaction_snark.Statement.Stable.V2.t One_or_two.Stable.V1.t
      [@@deriving equal, compare, hash, sexp, yojson]

      let to_latest = Fn.id

      let (_ : (t, Arg.Stable.V2.t) Type_equal.t) = Type_equal.T

      include Hashable.Make_binable (Arg.Stable.V2)
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, hash, compare, yojson, equal]

  include Hashable.Make (Stable.Latest)

  let gen = One_or_two.gen Transaction_snark.Statement.gen

  let compact_json t =
    `List
      ( One_or_two.map ~f:(fun s -> `Int (Transaction_snark.Statement.hash s)) t
      |> One_or_two.to_list )

  let work_ids t : int One_or_two.t =
    One_or_two.map t ~f:Transaction_snark.Statement.work_id
end

module Statement_with_hash = struct
  module T = struct
    type t = Statement.t With_hash.t

    let hash = With_hash.hash

    let hash_fold_t st With_hash.{ hash; _ } = Int.hash_fold_t st hash

    let equal With_hash.{ data = d1; _ } With_hash.{ data = d2; _ } =
      Statement.equal d1 d2

    let compare With_hash.{ data = d1; _ } With_hash.{ data = d2; _ } =
      Statement.compare d1 d2

    let create = With_hash.create ~f:Fn.id

    let t_of_sexp =
      Fn.compose create
        (One_or_two.t_of_sexp Transaction_snark.Statement.t_of_sexp)

    let sexp_of_t With_hash.{ data; _ } =
      One_or_two.sexp_of_t Transaction_snark.Statement.sexp_of_t data

    let to_yojson With_hash.{ data; _ } =
      One_or_two.to_yojson Transaction_snark.Statement.to_yojson data
  end

  include T
  include Hashable.Make (T)
end

module Info = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        { statements : Statement.Stable.V2.t
        ; work_ids : int One_or_two.Stable.V1.t
        ; fee : Fee.Stable.V1.t
        ; prover : Public_key.Compressed.Stable.V1.t
        }
      [@@deriving compare, sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { statements : Statement.t
    ; work_ids : int One_or_two.t
    ; fee : Fee.t
    ; prover : Public_key.Compressed.t
    }
  [@@deriving to_yojson, sexp, compare]
end

module T = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t = Mina_wire_types.Transaction_snark_work.V2.t =
        { fee : Fee.Stable.V1.t
        ; proofs : Ledger_proof.Stable.V2.t One_or_two.Stable.V1.t
        ; prover : Public_key.Compressed.Stable.V1.t
        }
      [@@deriving equal, compare, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { fee : Fee.t
    ; proofs : Ledger_proof.t One_or_two.t
    ; prover : Public_key.Compressed.t
    }
  [@@deriving compare, yojson, sexp]

  let statement t = One_or_two.map t.proofs ~f:Ledger_proof.statement

  let info t =
    let statements = One_or_two.map t.proofs ~f:Ledger_proof.statement in
    { Info.statements
    ; work_ids = One_or_two.map statements ~f:Transaction_snark.Statement.hash
    ; fee = t.fee
    ; prover = t.prover
    }
end

include T

type unchecked = t

module Checked = struct
  include T

  let create_unsafe = Fn.id
end

let forget = Fn.id

let fee { fee; _ } = fee
