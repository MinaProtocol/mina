type t = string;

// TODO: Do some sort of verification here
let ofStringExn = s => s;

let toString = s => s;

let prettyPrint = s =>
  if (String.length(s) < 17) {
    s;
  } else {
    String.sub(s, 0, 6) ++ ".." ++ String.sub(s, String.length(s) - 5, 5);
  };

let equal = (a, b) => a === b;

let uriEncode = Js.Global.encodeURIComponent;

let uriDecode = Js.Global.decodeURIComponent;
