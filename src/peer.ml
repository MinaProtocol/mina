open Core_kernel

module Event = struct
  type t =
    | Connect of Host_and_port.t list
    | Disconnect of Host_and_port.t list
end
