open Core_kernel
open Module_version
open Currency
open Signature_lib

module Statement = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Transaction_snark.Statement.Stable.V1.t One_or_two.Stable.V1.t
        [@@deriving bin_io, sexp, hash, compare, yojson, version]
      end

      include T
      include Registration.Make_latest_version (T)
      include Hashable.Make_binable (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "transaction_snark_work_statement"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t [@@deriving sexp, hash, compare, yojson]

  include Hashable.Make (Stable.Latest)

  let gen = One_or_two.gen Transaction_snark.Statement.gen

  let compact_json t =
    `List
      ( One_or_two.map ~f:(fun s -> `Int (Transaction_snark.Statement.hash s)) t
      |> One_or_two.to_list )

  let work_ids t : int One_or_two.t =
    One_or_two.map t ~f:Transaction_snark.Statement.hash
end

module Info = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { statements: Statement.Stable.V1.t
          ; work_ids: int One_or_two.Stable.V1.t
          ; fee: Fee.Stable.V1.t
          ; prover: Public_key.Compressed.Stable.V1.t }
        [@@deriving sexp, to_yojson, bin_io, version]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "transaction_snark_work"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t =
    { statements: Statement.Stable.V1.t
    ; work_ids: int One_or_two.t
    ; fee: Fee.Stable.V1.t
    ; prover: Public_key.Compressed.Stable.V1.t }
  [@@deriving to_yojson, sexp, compare]
end

module T = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { fee: Fee.Stable.V1.t
          ; proofs: Ledger_proof.Stable.V1.t One_or_two.Stable.V1.t
          ; prover: Public_key.Compressed.Stable.V1.t }
        [@@deriving sexp, to_yojson, bin_io, version]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "transaction_snark_work"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t =
    { fee: Fee.t
    ; proofs: Ledger_proof.t One_or_two.t
    ; prover: Public_key.Compressed.t }
  [@@deriving to_yojson, sexp]

  let info t =
    let statements = One_or_two.map t.proofs ~f:Ledger_proof.statement in
    { Info.statements
    ; work_ids= One_or_two.map statements ~f:Transaction_snark.Statement.hash
    ; fee= t.fee
    ; prover= t.prover }
end

include T

type unchecked = t

module Checked = struct
  include T

  let create_unsafe = Fn.id
end

let forget = Fn.id

let fee {fee; _} = fee
