type t;

let ofStringExn: string => t;
let toString: t => string;
let prettyPrint: t => string;
let equal: (t, t) => bool;
let uriEncode: t => string;
let uriDecode: string => t;
