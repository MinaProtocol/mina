module Or_infinite = struct
  type 'a t = Infinite | Finite of 'a
end

module Poly_comm = struct
  type 'a t = {shifted: 'a option; unshifted: 'a array}
end
