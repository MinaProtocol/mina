open Core_kernel

module Incoming = struct
  type 'a t = {data: 'a; sender: Host_and_port.t}

  let sender {sender; _} = sender

  let data {data; _} = data

  let wrap ~data ~sender = {data; sender}

  let map ~f t = {t with data= f t.data}
end

module Outgoing = struct
  type 'a t = {data: 'a; destination: Host_and_port.t}

  let destination {destination; _} = destination

  let data {data; _} = data

  let wrap ~data ~destination = {data; destination}

  let map ~f t = {t with data= f t.data}
end
