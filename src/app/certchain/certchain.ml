open Core
open Core_kernel


module Backend = Snarky.Backends.Bn128.Default
module Impl = Snarky.Snark.Run.Make(Backend) (Unit)
module Signature_lib = Signature_lib



open Signature_lib


type ('pk, 'sigg) certShow = 
  {
    domain : string
    ; public_key_domain : 'pk
    ; self_sig_on_domain : 'sigg
    ; public_key_autho : 'pk
    ; auth_sig_on_domain_pk :  'sigg;
  }


  

let queryGen domain  =
  let kp = Signature_lib.Keypair.create () in
  let signature = Signature_lib.Schnorr.sign kp.private_key domain in
  (kp.public_key, kp.private_key, signature)

module Cert = struct
  let certify (sk_authority : Schnorr.Private_key.t) domain (pk_domain : Schnorr.Public_key.t) signature =
    let (b : bool) = Signature_lib.Schnorr.verify signature pk_domain domain in
    if b = false then None
    else 
    let hvalue = Random_oracle.hash [|(domain :> field); (pk_domain :> field)|] in
    let signature_auth = Schnorr.sign sk_authority hvalue in
    Some signature_auth 
end





  

(* # introduce random oracle and hash (domain, pk_domain) to be signed by authority *)





