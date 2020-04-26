[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module T = Coda_numbers.Length
module Protocol_constants = Genesis_constants.Protocol.In_snark

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = T.Stable.V1.t Protocol_constants.Poly.Stable.V1.t
      [@@deriving eq, ord, hash, sexp, to_yojson, compare]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving to_yojson, eq, sexp, compare]

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Let_syntax in
    let%map k = Int.gen_incl 1 5000 in
    Protocol_constants.create ~k:(T.of_int k)
end

type t = Genesis_constants.Protocol.In_snark.t

type value = Value.t

let value_of_t (t : Genesis_constants.Protocol.In_snark.t) : value =
  Protocol_constants.(create ~k:(T.of_int t.k))

let t_of_value (v : value) : Genesis_constants.Protocol.In_snark.t =
  Protocol_constants.create ~k:(T.to_int v.k)

let to_input (t : value) =
  Random_oracle.Input.bitstring (T.to_bits (Protocol_constants.k t))

[%%if
defined consensus_mechanism]

type var = T.Checked.t Protocol_constants.Poly.t

let to_hlist (t : _ Protocol_constants.Poly.t) =
  H_list.[Protocol_constants.k t]

let of_hlist : (unit, 'a -> unit) H_list.t -> 'a Protocol_constants.Poly.t =
 fun H_list.[k] -> Protocol_constants.create ~k

let data_spec = Data_spec.[T.Checked.typ]

let typ =
  Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_to_input (var : var) =
  let s = Bitstring_lib.Bitstring.Lsb_first.to_list in
  let%map k = T.Checked.to_bits (Protocol_constants.k var) in
  Random_oracle.Input.bitstring (s k)

let%test_unit "value = var" =
  let compiled = Genesis_constants.compiled.protocol.in_snark in
  let test protocol_constants =
    let open Snarky in
    let p_var =
      let%map p = exists typ ~compute:(As_prover.return protocol_constants) in
      As_prover.read typ p
    in
    let _, res = Or_error.ok_exn (run_and_check p_var ()) in
    [%test_eq: Value.t] res protocol_constants ;
    [%test_eq: Value.t] protocol_constants
      (t_of_value protocol_constants |> value_of_t)
  in
  Quickcheck.test ~trials:100 Value.gen ~examples:[value_of_t compiled] ~f:test

[%%endif]
