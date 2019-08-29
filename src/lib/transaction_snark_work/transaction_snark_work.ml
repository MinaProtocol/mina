open Core_kernel
open Async_kernel
open Module_version
open Currency
open Signature_lib

let proofs_length = 2

module Statement = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Transaction_snark.Statement.Stable.V1.t list
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

  let gen =
    Quickcheck.Generator.list_with_length proofs_length
      Transaction_snark.Statement.gen

  let compact_json t =
    `List (List.map ~f:(fun s -> `Int (Transaction_snark.Statement.hash s)) t)

  let work_ids t : int list = List.map t ~f:Transaction_snark.Statement.hash
end

module Info = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { statements: Statement.Stable.V1.t
          ; work_ids: int list
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
    ; work_ids: int list
    ; fee: Fee.Stable.V1.t
    ; prover: Public_key.Compressed.Stable.V1.t }
  [@@deriving to_yojson, sexp]
end

module T = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          { fee: Fee.Stable.V1.t
          ; proofs: Ledger_proof.Stable.V1.t list
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
    {fee: Fee.t; proofs: Ledger_proof.t list; prover: Public_key.Compressed.t}
  [@@deriving to_yojson, sexp]

  let info t =
    let statements = List.map t.proofs ~f:Ledger_proof.statement in
    { Info.statements
    ; work_ids= List.map statements ~f:Transaction_snark.Statement.hash
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
