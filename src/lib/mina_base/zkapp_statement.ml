[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%endif]

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'comm t = { party : 'comm; calls : 'comm }
      [@@deriving hlist, sexp, yojson]
    end
  end]

  let to_field_elements (t : 'c t) : 'c array =
    let [ x0; x1 ] = to_hlist t in
    [| x0; x1 |]
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t = Parties.Transaction_commitment.Stable.V1.t Poly.Stable.V1.t
    [@@deriving sexp, yojson]

    let to_latest = Fn.id
  end
end]

let to_field_elements : t -> _ = Poly.to_field_elements

let of_tree (type party)
    ({ party = _; party_digest; calls } :
      ( party
      , Parties.Digest.Party.t
      , Parties.Digest.Forest.t )
      Parties.Call_forest.Tree.t ) : t =
  { Poly.party = (party_digest :> Parties.Transaction_commitment.t)
  ; calls = (Parties.Call_forest.hash calls :> Parties.Transaction_commitment.t)
  }

let zkapp_statements_of_forest' (type data)
    (forest : data Parties.Call_forest.With_hashes_and_data.t) :
    (data * t) Parties.Call_forest.With_hashes_and_data.t =
  Parties.Call_forest.mapi_with_trees forest ~f:(fun _i (party, data) tree ->
      (party, (data, of_tree tree)) )

let zkapp_statements_of_forest (type party)
    (forest : (party, _, _) Parties.Call_forest.t) :
    (party * t, _, _) Parties.Call_forest.t =
  Parties.Call_forest.mapi_with_trees forest ~f:(fun _i party tree ->
      (party, of_tree tree) )

[%%ifdef consensus_mechanism]

module Checked = struct
  type t = Parties.Transaction_commitment.Checked.t Poly.t

  let to_field_elements : t -> _ = Poly.to_field_elements

  open Pickles.Impls.Step

  module Assert = struct
    let equal (t1 : t) (t2 : t) =
      Array.iter2_exn ~f:Field.Assert.equal (to_field_elements t1)
        (to_field_elements t2)
  end
end

let typ =
  let open Poly in
  Typ.of_hlistable
    Parties.Transaction_commitment.[ typ; typ ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

[%%endif]
