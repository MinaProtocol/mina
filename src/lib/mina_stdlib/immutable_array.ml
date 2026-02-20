type 'a t = 'a array

let of_array arr = arr

let get arr i = arr.(i)

let to_list = Array.to_list
