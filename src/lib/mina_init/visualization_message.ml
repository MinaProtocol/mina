open Core_kernel

let success visualization_type filepath =
  sprintf
    !"Successfully wrote the visualization of the %s at location: %s."
    visualization_type filepath

let bootstrap visualization_type =
  sprintf
    !"Could not visualize %s since daemon is currently bootstrapping"
    visualization_type
