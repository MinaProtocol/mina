open Core
open Snark_params

module Stable = struct
  module V1 = struct
    (* TODO: This should be stable. *)
    module T = struct
      type t = Tock.Proof.t

      let to_string = Tock_backend.Proof.to_string

      let of_string = Tock_backend.Proof.of_string
    end

    include T
    include Sexpable.Of_stringable (T)

    let to_yojson t = `String (to_string t)

    let of_yojson = function
      | `String x -> Ok (of_string x)
      | _ -> Error "expected `String"

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
end

let dummy = Tock.Proof.dummy

include Stable.V1
