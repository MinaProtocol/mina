[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
module Coda_numbers = Coda_numbers

[%%else]

module Coda_numbers = Coda_numbers_nonconsensus.Coda_numbers
module Currency = Currency_nonconsensus.Currency
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module Predicate = Snapp_predicate

(* This is the statement against which snapp proofs are created. *)
module Statement = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('predicate, 'updates) t =
          {predicate: 'predicate; updates: 'updates}
        [@@deriving hlist]

        let to_latest = Fn.id
      end
    end]

    let typ spec =
      let open Stable.Latest in
      Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Predicate.Stable.V1.t
        , Snapp_command.Union_payload.Stable.V1.t )
        Poly.Stable.V1.t

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t

  module Checked = struct
    type t =
      ( Predicate.Checked.t
      , Snapp_command.Union_payload.Checked.t )
      Poly.Stable.Latest.t
  end

  let typ () : (Checked.t, t) Typ.t =
    Poly.typ [Predicate.typ (); Snapp_command.Union_payload.typ ()]
end
