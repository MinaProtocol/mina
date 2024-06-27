module V1 = struct
  type ('a, 'h) t = { data : 'a; hash : 'h }
end

type ('a, 'h) t = ('a, 'h) V1.t = { data : 'a; hash : 'h }
