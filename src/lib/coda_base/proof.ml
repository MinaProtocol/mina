open Core
open Snark_params

module Stable = struct
  module V1 = struct
    (* TODO: This should be stable. *)
    module T = struct
      (* Tock.Proof.t is not bin_io; should we wrap that snarky type? *)
      type t = Tock.Proof.t [@@deriving version {asserted; unnumbered}]

      let to_string = Binable.to_string (module Tock_backend.Proof)

      let of_string = Binable.of_string (module Tock_backend.Proof)

      let compare a b = String.compare (to_string a) (to_string b)

      let version_byte = Base58_check.Version_bytes.proof

      let description = "Tock proof"
    end

    include T
    include Sexpable.Of_stringable (T)
    module Base58_check = Base58_check.Make (T)

    let to_yojson s = `String (Base58_check.encode (to_string s))

    let of_yojson = function
      | `String s -> (
        match Base58_check.decode s with
        | Ok decoded ->
            Ok (of_string decoded)
        | Error e ->
            Error
              (sprintf "Proof.of_yojson, bad Base58Check: %s"
                 (Error.to_string_hum e)) )
      | _ ->
          Error "Proof.of_yojson expected `String"

    (* TODO: Figure out what the right thing to do is for conversion failures *)
    let ( { Bin_prot.Type_class.reader= bin_reader_t
          ; writer= bin_writer_t
          ; shape= bin_shape_t } as bin_t ) =
      Bin_prot.Type_class.cnv Fn.id to_string of_string String.bin_t

    let {Bin_prot.Type_class.read= bin_read_t; vtag_read= __bin_read_t__} =
      bin_reader_t

    let {Bin_prot.Type_class.write= bin_write_t; size= bin_size_t} =
      bin_writer_t
  end

  module Latest = V1
end

type t = Stable.Latest.t

let dummy = Tock.Proof.dummy

include Sexpable.Of_stringable (Stable.Latest)

[%%define_locally
Stable.Latest.(to_yojson, of_yojson)]
