include Pedersen.Digest

let to_bytes t = Fold_lib.Fold.bool_t_to_string (fold_bits t)
