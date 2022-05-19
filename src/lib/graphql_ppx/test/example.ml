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
    address: Address.t; [@subquery "Address.Gql"]
  }
  module Fields = struct
    let id = ()
    let name = ()
    let address = ()
  end
  module Mutations = struct
    let set_name = ()
  end
]
