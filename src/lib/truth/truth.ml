include Core_kernel

module True = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = unit

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t
end

module False = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = unit

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t
end

type true_ = True.t

type false_ = False.t

(* can't use %%versioned here because the generated 'deriving bin_io' doesn't work with GADTs;
   but we don't need the bin_io here; this type is only versioned because it's
   used in External_transition.Validated, which has a versioned type 't', but that type
   uses Binable.Of_binable to rely on another type's serialization
 *)
module Stable = struct
  module V1 = struct
    module T = struct
      type ('witness, _) t =
        | True : 'witness -> ('witness, True.Stable.V1.t) t
        | False : ('witness, False.Stable.V1.t) t
      [@@deriving version]
    end

    include T
  end

  module Latest = V1
end

type ('witness, 'b) t = ('witness, 'b) Stable.Latest.t =
  | True : 'witness -> ('witness, true_) t
  | False : ('witness, false_) t

type 'witness true_t = ('witness, true_) t

type 'witness false_t = ('witness, false_) t
