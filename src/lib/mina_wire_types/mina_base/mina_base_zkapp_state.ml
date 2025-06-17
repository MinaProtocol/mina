module V = struct
  module V2 = struct
    type 'a t = ('a, Pickles_types.Nat.eight) Pickles_types.Vector.t
  end
end
