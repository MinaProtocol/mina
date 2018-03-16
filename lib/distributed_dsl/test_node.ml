open Core_kernel
open Async_kernel

module I = struct
  module State = struct
    type t = int [@@deriving eq]
  end

  module Message = struct
    type t = int
  end

  module Peer = struct
    type t = int
  end

  module Timer = struct
    type tok = int [@@deriving eq]
    let cancel tok = failwith "nyi"
    let wait ts = failwith "nyi"
  end

  module Condition_label = struct
    module T = struct
      type label = Todo [@@deriving enum, hash, compare, sexp]
      type t = label [@@deriving hash, compare, sexp]
    end
    include T
    include Hashable.Make(T)
  end

  module Message_label = struct
    module T = struct
      type label = Todo [@@deriving enum, hash, compare, sexp]
      type t = label [@@deriving hash, compare, sexp]
    end
    include T
    include Hashable.Make(T)
  end

  module Timer_label = struct
    module T = struct
      type label = Todo [@@deriving enum, hash, compare, sexp]
      type t = label [@@deriving hash, compare, sexp]
    end
    include T
    include Hashable.Make(T)
  end

  module type Transport_intf = sig
    type t
    type message
    type peer

    val send : t -> recipient:peer -> message -> unit Or_error.t Deferred.t
    val listen : t -> message Linear_pipe.Reader.t
  end

  module Transport = struct
    type t = unit
    type message = Message.t
    type peer = Peer.t

    let send t ~recipient message = return (Ok ())
    let listen t = 
      let r, w = Linear_pipe.create () in
      r

  end
end

include Node.Make(I.State)(I.Message)(I.Peer)(I.Timer)(I.Message_label)(I.Timer_label)(I.Condition_label)(I.Transport)
