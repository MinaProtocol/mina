module By_the_os = struct
  type t = bool
  let of_bool t = t
  let get t = t
end

type t = bool
let of_bool t = t
let get x y = x && y
