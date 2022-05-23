module Address = [%derive_graphql
  type t = {
    dummy : unit;
  }
  type 'a final_option_modifier = 'a

  module Fields = struct
    let dummy [@field: unit] = {
      obj = "Address";
      typ = ();
      args = [];
      resolve = ()
    }
  end
]

module Contact = [%derive_graphql
  type t = {
    id: int;
    name: string;
    address: Address.t;
  }
  type 'a final_option_modifier = 'a

  module Fields = struct
    let id [@field: int] = {
      obj = "Contact"; (* this should be factorized *)
      typ = ();
      args = [];
      resolve = ()
    }
    let name [@field: string] = {
      obj = "Contact";
      typ = ();
      args = [];
      resolve = ()
    }
    let address [@field: Address.t] = {
      obj = "Contact";
      typ = ();
      args = [];
      resolve = ()
    }
  end
]
