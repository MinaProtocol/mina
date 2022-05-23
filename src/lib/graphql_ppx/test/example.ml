module Address = [%derive_graphql
  type t = {
    dummy : unit;
  }

  module Fields = struct
    let dummy = ()
  end
]

module Contact = [%derive_graphql
  type t = {
    id: int;
    name: string;
    address: Address.t;
  }
  module Fields = struct
    let id [@field int] = {typ = (); resolve = Fn.id}
    let name [@field string] = {typ = (); resolve = Fn.id}
    let address [@field Address.t] = {typ = (); resolve = Fn.id}
  end
]
