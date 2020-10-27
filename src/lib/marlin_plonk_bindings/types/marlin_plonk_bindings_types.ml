module Or_infinite = struct
  type 'a t = Infinite | Finite of 'a
end
