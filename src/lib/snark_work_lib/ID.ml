open Core_kernel

module ID = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* this identifies a One_or_two work from Work_selector's perspective *)
      type t = ID of int64 [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

(* A Pairing.Single.t identifies one part of a One_or_two work *)
module Single = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* Case `One` indicate no need to pair. *)
      type t = [ `First of ID.Stable.V1.t | `Second of ID.Stable.V1.t | `One ]
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

(* A Pairing.Sub_zkapp.t identifies a sub-zkapp level work *)
module Sub_zkapp = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* Case `One` indicate no need to pair. ID is still needed because zkapp command
         might be left in pool of half completion. *)
      type t =
        { which_one : [ `First | `Second | `One ]
        ; pairing_id : ID.Stable.V1.t
        ; job_id : ID.Stable.V1.t
        }
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]

  let of_single (id_gen : unit -> ID.t) : Single.t -> t = function
    | `First id ->
        { which_one = `First; id }
    | `Second id ->
        { which_one = `Second; id }
    | `One ->
        { which_one = `One; id = id_gen () }
end
