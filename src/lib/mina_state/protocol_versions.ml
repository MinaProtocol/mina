open Core_kernel
open Snark_params.Tick
module Flagged_option = Mina_base.Zkapp_basic.Flagged_option

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('version, 'proposed) t =
            ( 'version
            , 'proposed )
            Mina_wire_types.Mina_state.Protocol_versions.Poly.V1.t =
        { current : 'version; proposed : 'proposed }
      [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
    end
  end]
end

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Protocol_version.Stable.V2.t
        , Protocol_version.Stable.V2.t option )
        Poly.Stable.V1.t
      [@@deriving sexp, equal, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Version = struct
  module Component = Mina_numbers.Nat.Make32 ()

  type 'a poly = { transaction : 'a; network : 'a; patch : 'a }
  [@@deriving hlist]

  type var = Component.Checked.t poly

  let to_poly v =
    { transaction = Component.of_int (Protocol_version.transaction v)
    ; network = Component.of_int (Protocol_version.network v)
    ; patch = Component.of_int (Protocol_version.patch v)
    }

  let of_poly { transaction; network; patch } =
    Protocol_version.create
      ~transaction:(Component.to_int transaction)
      ~network:(Component.to_int network) ~patch:(Component.to_int patch)

  let typ : (var, Protocol_version.t) Typ.t =
    Typ.of_hlistable
      [ Component.typ; Component.typ; Component.typ ]
      ~var_to_hlist:poly_to_hlist ~var_of_hlist:poly_of_hlist
      ~value_to_hlist:poly_to_hlist ~value_of_hlist:poly_of_hlist
    |> Typ.transport ~there:to_poly ~back:of_poly

  let zero = Protocol_version.create ~transaction:0 ~network:0 ~patch:0

  let to_input v =
    let { transaction; network; patch } = to_poly v in
    Random_oracle.Input.Chunked.(
      List.reduce_exn ~f:append
        [ Component.to_input transaction
        ; Component.to_input network
        ; Component.to_input patch
        ])

  let var_to_input ({ transaction; network; patch } : var) =
    Random_oracle.Input.Chunked.(
      List.reduce_exn ~f:append
        [ Component.Checked.to_input transaction
        ; Component.Checked.to_input network
        ; Component.Checked.to_input patch
        ])
end

type var = (Version.var, (Boolean.var, Version.var) Flagged_option.t) Poly.t

let typ : (var, Value.t) Typ.t =
  Typ.of_hlistable
    [ Version.typ; Flagged_option.option_typ ~default:Version.zero Version.typ ]
    ~var_to_hlist:Poly.to_hlist ~var_of_hlist:Poly.of_hlist
    ~value_to_hlist:Poly.to_hlist ~value_of_hlist:Poly.of_hlist

let create ~current ~proposed : Value.t = { current; proposed }

let of_daemon () =
  create ~current:Protocol_version.current
    ~proposed:(Protocol_version.get_proposed_opt ())

let legacy =
  create
    ~current:(Protocol_version.create ~transaction:4 ~network:0 ~patch:0)
    ~proposed:None

let to_input ({ current; proposed } : Value.t) =
  Random_oracle.Input.Chunked.append (Version.to_input current)
    (Flagged_option.to_input
       (Flagged_option.of_option proposed ~default:Version.zero)
       ~default:Version.zero ~f:Version.to_input
       ~field_of_bool:Mina_base_util.field_of_bool )

let var_to_input ({ current; proposed } : var) =
  Random_oracle.Input.Chunked.append
    (Version.var_to_input current)
    (Flagged_option.to_input' proposed ~f:Version.var_to_input
       ~field_of_bool:(fun (b : Boolean.var) -> (b :> Field.Var.t)) )

let assert_current_is_this_protocol ({ current; _ } : var) =
  let open Checked.Let_syntax in
  let assert_is component expected =
    Version.Component.Checked.Assert.equal component
      (Version.Component.Checked.constant (Version.Component.of_int expected))
  in
  let%bind () =
    assert_is current.transaction Protocol_version.(transaction current)
  in
  assert_is current.network Protocol_version.(network current)
