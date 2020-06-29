open Core_kernel
open Coda_base
open Core

open Async

open Import
open Snark_params
open Snarky
open Tick
open Signature_lib
open Let_syntax

open Currency
open Coda_numbers
open Sparse_ledger_lib

module Domain = struct
  type t = string [@@deriving sexp, eq, to_yojson]

  let to_bits : t -> bool list =
    fun d ->
      failwith "TODO"
end

module Certificate_authority : sig
  type t

  val register
    : t
    -> domain: Domain.t
    -> public_key:Signature_lib.Schnorr.Public_key.t
    -> self_signature:Signature.t
    -> Signature.t Or_error.t
end = struct
  type t = Private_key.t

  let nybble_bits = function
| 0x0 ->
        [false; false; false; false]
| 0x1 ->
        [false; false; false; true]
| 0x2 ->
        [false; false; true; false]
| 0x3 ->
        [false; false; true; true]
| 0x4 ->
        [false; true; false; false]
| 0x5 ->
        [false; true; false; true]
| 0x6 ->
        [false; true; true; false]
| 0x7 ->
        [false; true; true; true]
| 0x8 ->
        [true; false; false; false]
| 0x9 ->
        [true; false; false; true]
| 0xA ->
        [true; false; true; false]
| 0xB ->
        [true; false; true; true]
| 0xC ->
        [true; true; false; false]
| 0xD ->
        [true; true; false; true]
| 0xE ->
        [true; true; true; false]
| 0xF ->
        [true; true; true; true]
| _ ->
        failwith "nybble_bits: expected value from 0 to 0xF"

  let char_bits c =
    let open Core_kernel in
    let n = Char.to_int c in
    let hi = Int.(shift_right (bit_and n 0xF0) 4) in
    let lo = Int.bit_and n 0x0F in
    List.concat_map [hi; lo] ~f:nybble_bits

  let string_to_input s =
    Random_oracle.Input.
            { field_elements= [||]
            ; bitstrings=
    Stdlib.(Array.of_seq (Seq.map char_bits (String.to_seq s))) }


  module My_cool_record = struct
    type t =
      { a : int; b : string }
  end

  let record = { My_cool_record. a=1; b= "hello" }

  let register (skca : t) (domain : Domain.t) (pkd : Public_key.t) (signature_self : Signature_lib.Schnorr.Signature.t)  =
    let (b : bool) =
      Schnorr.verify signature_self 
        (Inner_curve.of_affine pkd)
        (string_to_input domain)
    in
    let msg =
      let (x, y) = pkd in
      { Random_oracle.Input.
        field_elements= [| x; y |]
      ; bitstrings=
          [| Domain.to_bits domain
          |]
      }
    in
    if b then Ok (Signature_lib.Schnorr.sign skca msg)
    else Or_error.error_string "invalid query"
end

module DomainAccount = struct
  module T = struct
    type t = {domain: Domain.t; pkd: Signature_lib.Schnorr.Public_key.t; cert: Signature_lib.Schnorr.Signature.t}
    [@@deriving bin_io, eq, sexp, to_yojson]
  end

  include T

  let key {domain; _} = domain

  (* TODO: Should use poseidon (i.e., Random_oracle) *)
  let data_hash t = Md5.digest_string (Binable.to_string (module T) t)

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map domain = String.quickcheck_generator
    and let kp = Signature_lib.Keypair.create () in
    {domain; kp.public_key; kp.private_key}
end




  (* TODO: Should use poseidon (i.e., Random_oracle) *)
module Hash = struct
  (* TODO: Use Random_oracle.Digest *)
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


module Merkle_tree_maintainer : sig
  type t 

  val get_path: Domain.t -> [`Left of Hash.t | `Right of Hash.t] list
end = struct
  include Sparse_ledger_lib.Sparse_ledger.Make (Hash) (Domain) (DomainAccount)
end

module Proof = struct
  type t = Tick.Proof.t
end

module Statement = struct
  type t =
    { merkle_root_old: Hash.t
    ; merkle_root_new: Hash.t
    }
end

module Witness = struct
  type t =
    { path        : [`Left of Hash.t | `Right of Hash.t] list
    ; account_old : DomainAccount.t
    ; account_new : DomainAccount.t
    }
end

module Prover : sig
  type t

  val prove : Witness.t -> Proof.t * Statement.t
end = struct

  (* *)
  let prove (w : Witness.t) =
    (* Use the function

       Tick.prove
    *)
end
