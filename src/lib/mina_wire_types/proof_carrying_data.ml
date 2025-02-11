module V1 = struct
  type ('a, 'p) t = { data : 'a; proof : 'p }
end

type ('a, 'p) t = ('a, 'p) V1.t = { data : 'a; proof : 'p }
