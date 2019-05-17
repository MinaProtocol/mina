type t = string;

// TODO: Do some sort of verification here
let ofStringExn = s => s;

let toString = s => s;

let prettyPrint = s =>
  if (String.length(s) < 16) {
    s;
  } else {
    String.sub(s, 0, 10) ++ "..." ++ String.sub(s, String.length(s) - 7, 6);
  };

let equal = (a, b) => a === b;
