open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = { staged_ledger_diff : Staged_ledger_diff.Stable.V1.t }
    [@@deriving compare, sexp, fields]

    let to_latest = Fn.id

    let to_yojson _ = `String "<opaque>"

    module Creatable = struct
      let id = "block_body"

      type nonrec t = t

      let sexp_of_t = sexp_of_t

      let t_of_sexp = t_of_sexp

      type 'a creator = Staged_ledger_diff.Stable.Latest.t -> 'a

      let map_creator c ~f staged_ledger_diff = f (c staged_ledger_diff)

      let create staged_ledger_diff = { staged_ledger_diff }
    end

    include (
      Allocation_functor.Make.Basic
        (Creatable) :
          Allocation_functor.Intf.Output.Basic_intf
            with type t := t
             and type 'a creator := 'a Creatable.creator )

    include (
      Allocation_functor.Make.Sexp
        (Creatable) :
          Allocation_functor.Intf.Output.Sexp_intf
            with type t := t
             and type 'a creator := 'a Creatable.creator )
  end
end]

type t = Stable.Latest.t

[%%define_locally
Stable.Latest.
  (create, to_yojson, sexp_of_t, t_of_sexp, compare, staged_ledger_diff)]
