open Core
open Core_kernel
open Async
open Import
open Snark_params
open Snarky
open Tick
open Let_syntax

module Backend = Snarky.Backends.Bn128.Default
module Impl = Snarky.Snark.Run.Make(Backend) (Unit)
module Signature_lib = Signature_lib
module U = (val (Snarky_universe.default ()))


open Signature_lib

open! U.Impl
open! U

include Non_zero_curve_point (* AAA should this come here to add .Compressed for Domain, should Domain be of different type*)
module Domain = struct
  
  type t = Signature_lib.Schnorr.Message.t
  type var = Signature_lib.Schnorr.Message.var
  
  module Constant = struct
    [@deriving yojson]
    type t = Field.Constant.t
  end

  let queryGen (domain : t)  =
    let kp = Signature_lib.Keypair.create () in
    let signature = Signature_lib.Schnorr.sign kp.private_key domain in
    (kp.public_key, kp.private_key, signature)

end


module Certificate_authority = struct
  type t = Private_key.t

  let register (skca : t) (domain : Domain.t) (pkd : Signature_lib.Schnorr.Public_key.t) (signature_self : Signature_lib.Schnorr.Signature.t)  =
    let (b : bool) = Signature_lib.Schnorr.verify signature_self pkd domain in
    if b then Ok (Signature_lib.Schnorr.sign skca (domain, pkd))
    else Or_error.error_string "invalid query"

  (* let register t (domain : Domain.t) (pkd : Public_key.t) (signature_self : Signature_lib.Schnorr.Signature.t)  =
    let domain =  Command.Param.(anon ("domain" %: Domain.t)) in 
    let pkd = Command.Param.(anon ("pkd" %: Public_key.t)) in
    let signature_self  = Command.Param.(anon ("signature_self" %: Signature_lib.Schnorr.Signature.t))  in
*)   
end
  (* AAA review the sig, needs to be able to run queryGen, how to include that, how to explicitly include ability to call register *))
 type domain_owner = {
   domain : Domain.t;
   pkd : Signature_lib.Schnorr.Public_key.t;
   skd : Signature_lib.Schnorr.Private_key.t;
   self_signature : Signature_lib.Schnorr.Signature.t;
   certificate : Signature_lib.Schnorr.Public_key.t * Signature_lib.Schnorr.Signature.t;
} 











module Merkle_tree_maintainer = struct

end