module V1 = struct
  type 'a t = [ `One of 'a | `Two of 'a * 'a ]
end
