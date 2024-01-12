open Core_kernel
open Currency
open Signature_lib

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

      include Comparable.Make_binable (Arg.Stable.V2)
      include Hashable.Make_binable (Arg.Stable.V2)
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, hash, compare, yojson, equal]

  include Comparable.Make_binable (Stable.Latest)
  include Hashable.Make (Stable.Latest)

  let gen = One_or_two.gen Transaction_snark.Statement.gen

  let compact_json t =
    let f s = `Int (Transaction_snark.Statement.hash s) in
    `List (One_or_two.map ~f t |> One_or_two.to_list)

  let work_ids t : int One_or_two.t =
    One_or_two.map t ~f:Transaction_snark.Statement.hash
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
