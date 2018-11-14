open Core
open Snark_params

module T = struct
  type t = Load_both of {step: string; wrap: string} | Generate_both
  [@@deriving sexp]
end

include Sexpable.To_stringable (T)
include T

let arg_type = Command.Arg_type.create of_string

let obtain_keys (type vk pk kp)
    (module Impl : Snark_intf
      with type Verification_key.t = vk
       and type Proving_key.t = pk
       and type Keypair.t = kp) t f =
  let keypair_of_sexp s =
    let x, y = [%of_sexp: string * string] s in
    (Impl.Verification_key.of_string x, Impl.Proving_key.of_string y)
  in
  lazy
    ( match t with
    | Generate_both ->
        let ks = f () in
        (Impl.Keypair.vk ks, Impl.Keypair.pk ks)
    | Load_both {step} -> Sexp.load_sexp_conv_exn step keypair_of_sexp )
