type t;

let empty: t;
let fromJsonString: string => t;
let toJsonString: t => string;
let lookup: (t, PublicKey.t) => option(string);
let set: (t, ~key: PublicKey.t, ~name: string) => t;
let getAccountName: (t, PublicKey.t) => string;
