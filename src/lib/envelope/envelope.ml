open Core_kernel

module Incoming = struct
  type 'a t = {data: 'a; sender: Host_and_port.t}

  let sender {sender; _} = sender

  let data {data; _} = data

  let wrap ~data ~sender = {data; sender}

  let map ~f t = {t with data= f t.data}

  let local data = {data; sender= Host_and_port.of_string "127.0.0.1:0"}
end