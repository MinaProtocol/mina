open Core_kernel
module Good :
sig
  include
    sig
      module Stable :
      sig
        module V2 :
        sig
          type t = int[@@deriving (bin_io, version)]
          include
            sig
              [@@@ocaml.warning "-32"]
              include Bin_prot.Binable.S with type  t :=  t
              val __versioned__ : unit
            end[@@ocaml.doc "@inline"]
        end
        module Latest = V2
        module V1 :
        sig
          type t = string[@@deriving (bin_io, version)]
          include
            sig
              [@@@ocaml.warning "-32"]
              include Bin_prot.Binable.S with type  t :=  t
              val __versioned__ : unit
            end[@@ocaml.doc "@inline"]
          val to_latest : t -> V2.t
        end
        val versions :
          (int * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t))
            array
        val bin_read_to_latest_opt :
          Bin_prot.Common.buf -> pos_ref:int ref -> Latest.t option
      end
      type t = Stable.Latest.t
    end
  val is_42 : t -> bool
end
