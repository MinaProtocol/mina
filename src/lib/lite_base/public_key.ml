open Fold_lib
open Sexplib.Std
open Bin_prot.Std
module Field = Crypto_params.Tock.Fq

type t = Crypto_params.Tock.G1.t

module Compressed = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = {x: Field.t; is_odd: bool}
        [@@deriving bin_io, eq, sexp, version {asserted}]

        module Display = struct
          type t = {x: string; is_odd: bool} [@@deriving to_yojson]
        end

        let to_yojson {x; is_odd} =
          Display.to_yojson {Display.x= Field.to_string x; is_odd}
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t = {x: Field.t; is_odd: bool} [@@deriving eq, sexp]

  module Display = struct
    type t = {x: string; is_odd: bool} [@@deriving to_yojson]
  end

  let to_yojson {x; is_odd} =
    Display.to_yojson {Display.x= Field.to_string x; is_odd}

  let fold_bits {is_odd; x} =
    {Fold.fold= (fun ~init ~f -> f ((Field.fold_bits x).fold ~init ~f) is_odd)}

  let fold t = Fold.group3 ~default:false (fold_bits t)

  let length_in_triples = (Field.length_in_bits + 1 + 2) / 3
end
