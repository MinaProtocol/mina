[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Snark_params.Step

[%%endif]

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'comm t = { account_update : 'comm; calls : 'comm }
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
    type t = Zkapp_command.Transaction_commitment.Stable.V1.t Poly.Stable.V1.t
    [@@deriving sexp, yojson]

    let to_latest = Fn.id
  end
end]

let to_field_elements : t -> _ = Poly.to_field_elements

let of_tree (type account_update)
    ({ account_update = _; account_update_digest; calls } :
      ( account_update
      , Zkapp_command.Digest.Account_update.t
      , Zkapp_command.Digest.Forest.t )
      Zkapp_command.Call_forest.Tree.t ) : t =
  { account_update =
      (account_update_digest :> Zkapp_command.Transaction_commitment.t)
  ; calls =
      ( Zkapp_command.Call_forest.hash calls
        :> Zkapp_command.Transaction_commitment.t )
  }

let zkapp_statements_of_forest' (type data)
    (forest : data Zkapp_command.Call_forest.With_hashes_and_data.t) :
    (data * t) Zkapp_command.Call_forest.With_hashes_and_data.t =
  Zkapp_command.Call_forest.mapi_with_trees forest
    ~f:(fun _i (account_update, data) tree ->
      (account_update, (data, of_tree tree)) )

let zkapp_statements_of_forest (type account_update)
    (forest : (account_update, _, _) Zkapp_command.Call_forest.t) :
    (account_update * t, _, _) Zkapp_command.Call_forest.t =
  Zkapp_command.Call_forest.mapi_with_trees forest
    ~f:(fun _i account_update tree -> (account_update, of_tree tree))

[%%ifdef consensus_mechanism]

module Checked = struct
  type t = Zkapp_command.Transaction_commitment.Checked.t Poly.t

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
    Zkapp_command.Transaction_commitment.[ typ; typ ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

[%%endif]
