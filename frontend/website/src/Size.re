// pixels (width, height)
type t = (int, int);

let remX = ((x, _)) => Js.Int.toFloat(x) /. 16.0;
let remY = ((_, y)) => Js.Int.toFloat(y) /. 16.0;

let pixelsX = fst;
let pixelsY = snd;
