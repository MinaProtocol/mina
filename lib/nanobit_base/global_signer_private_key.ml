open Core_kernel

let t =
  "KgAAAAAAAAABKOg4N37Pm4VJevdeUWm/Lc7uPb7ZGWdTfngcSstK/2OsBQAAAAAAAAA="
  |> B64.decode |> Bigstring.of_string |> Private_key.of_bigstring
  |> Or_error.ok_exn
