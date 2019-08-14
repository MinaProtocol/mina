module True = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = unit [@@deriving version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t
end

module False = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = unit [@@deriving version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t
end

type true_ = True.t

type false_ = False.t

module Stable = struct
  module V1 = struct
    module T = struct
      type ('witness, _) t =
        | True : 'witness -> ('witness, True.Stable.Latest.t) t
        | False : ('witness, False.Stable.Latest.t) t
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
