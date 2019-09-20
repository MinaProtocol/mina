module True : sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving version]
    end

    module Latest = V1
  end

  type t = Stable.V1.t
end

module False : sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving version]
    end

    module Latest = V1
  end

  type t = Stable.V1.t
end

type true_ = True.t

type false_ = False.t

module Stable : sig
  module V1 : sig
    type ('witness, _) t =
      | True : 'witness -> ('witness, True.Stable.Latest.t) t
      | False : ('witness, False.Stable.Latest.t) t
    [@@deriving version]
  end

  module Latest = V1
end

type ('witness, 'b) t = ('witness, 'b) Stable.Latest.t =
  | True : 'witness -> ('witness, true_) t
  | False : ('witness, false_) t

type 'witness true_t = ('witness, true_) t

type 'witness false_t = ('witness, false_) t
