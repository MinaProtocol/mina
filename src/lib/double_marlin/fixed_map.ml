open Core_kernel

module Make(M : Map.S)(Keys : sig val keys : M.Key.t list end) = struct
  let order =`Increasing_key

  let keys : M.Key.t list =
    M.of_alist_exn (List.map Keys.keys ~f:(fun k -> (k, ())))
    |> M.to_sequence ~order
    |> Sequence.map ~f:fst
    |> Sequence.to_list

  type 'a t = 'a M.t [@@deriving sexp]

  include Binable.Of_binable1(List)(struct
    type 'a t = 'a M.t
    let to_binable t =
      M.to_sequence t ~order
      |> Sequence.map ~f:snd
      |> Sequence.to_list

    let of_binable xs = M.of_alist_exn (List.zip_exn keys xs)
  end)
end

