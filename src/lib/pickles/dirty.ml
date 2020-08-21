type t = [`Cache_hit | `Generated_something | `Locally_generated]

let ( + ) x y =
  match (x, y) with
  | `Generated_something, _ | _, `Generated_something ->
      `Generated_something
  | `Locally_generated, _ | _, `Locally_generated ->
      `Locally_generated
  | `Cache_hit, `Cache_hit ->
      `Cache_hit
