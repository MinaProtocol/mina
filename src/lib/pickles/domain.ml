type t = Pow_2_roots_of_unity of int [@@deriving eq]

let log2_size (Pow_2_roots_of_unity k) = k

let size t = 1 lsl log2_size t
