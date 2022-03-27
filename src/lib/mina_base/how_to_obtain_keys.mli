module T : sig
  type t = Load_both of { step : string; wrap : string } | Generate_both

  val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

  val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t
end

val of_string : string -> T.t

val to_string : T.t -> string

type t = T.t = Load_both of { step : string; wrap : string } | Generate_both

val t_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> t

val sexp_of_t : t -> Ppx_sexp_conv_lib.Sexp.t

val arg_type : t Core.Command.Arg_type.t

val obtain_keys :
     (module Snark_params.Snark_intf
        with type Keypair.t = 'kp
         and type Proving_key.t = 'pk
         and type Verification_key.t = 'vk)
  -> t
  -> (unit -> 'kp)
  -> ('vk * 'pk) lazy_t
