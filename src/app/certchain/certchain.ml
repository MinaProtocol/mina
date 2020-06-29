open Core
open Core_kernel
open Async
open Coda_base
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
open Random_oracle 

include Non_zero_curve_point 
module Domain = struct
  
  type t = Signature_lib.Schnorr.Message.t
  type var = Signature_lib.Schnorr.Message.var
  
  module Constant = struct
    [@deriving yojson]
    type t = Field.Constant.t
  end

  

end




module Certificate_authority = struct
  type t = Private_key.t


  let register (skca : t) (domain : Domain.t) (pkd : Signature_lib.Schnorr.Public_key.t) (signature_self : Signature_lib.Schnorr.Signature.t)  =
    let (b : bool) = Signature_lib.Schnorr.verify signature_self pkd domain in
    let msg = Random_oracle.hash ~init:[] 
    {Random_oracle.Input.field_elements= [||]; Random_oracle.Input.bitstrings= [|Random_oracle.Input.to_bits domain; Public_key.to_bigstring pkd|]} in
    if b then Ok (Signature_lib.Schnorr.sign skca msg)
    else Or_error.error_string "invalid query"

end


module Domain_owner = struct

 type t = {
   domain : Domain.t;
   pkd : Signature_lib.Schnorr.Public_key.t;
   skd : Signature_lib.Schnorr.Private_key.t;
   self_signature : Signature_lib.Schnorr.Signature.t;
   certificate : Signature_lib.Schnorr.Public_key.t * Signature_lib.Schnorr.Signature.t;
} 

let queryGen (domain : Domain.t)  =
  let kp = Signature_lib.Keypair.create () in
  let self_signature = Signature_lib.Schnorr.sign kp.private_key domain in
  (kp.public_key, kp.private_key, self_signature)


end










module Merkle_tree_maintainer = struct

  module Hash = struct
    type t = Core_kernel.Md5.t [@@deriving sexp, compare]

    let equal h1 h2 = Int.equal (compare h1 h2) 0

    let to_yojson md5 = `String (Core_kernel.Md5.to_hex md5)

    let merge ~height x y =
      let open Md5 in
      digest_string
        (sprintf "sparse-ledger_%03d" height ^ to_binary x ^ to_binary y)

    let gen =
      Quickcheck.Generator.map String.quickcheck_generator
        ~f:Md5.digest_string
  end



end