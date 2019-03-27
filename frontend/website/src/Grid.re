let enabled = true;

let bgColorStr = "rgba(204, 80, 72, 0.25)";

let columns = 12;

module GridInfo = {
  type t = {
    left: Css.rule,
    width: string,
    backgroundWidth: string,
    backgroundImage: string,
  };
};

// backgroundWidth , backgroundImage
let bg = (~row, ~col, ~gutter, ~offset) => {
  let repeatingWidth = Js.Float.toString(col +. gutter) ++ "rem";
  let columnWidth = Js.Float.toString(col) ++ "rem";
  let rowHeight = Js.Float.toString(row) ++ "rem";
  let doubleOffset = offset *. 2.0;
  GridInfo.{
    left: Css.left(`rem(offset)),
    width: {j|calc(100% - $doubleOffset|j} ++ "rem)",
    backgroundWidth: {j|calc(100% + $gutter|j} ++ "rem)",
    backgroundImage: {j|repeating-linear-gradient(to right,
                            $bgColorStr,
                            $bgColorStr $columnWidth,
                            transparent $columnWidth,
                            transparent $repeatingWidth),
         repeating-linear-gradient(to bottom,
                            $bgColorStr,
                            $bgColorStr $rowHeight,
                            transparent $rowHeight,
                            transparent calc($rowHeight + $rowHeight))
      |j},
  };
};

let overlay = {
  let mobileInfo = bg(~row=0.5, ~col=1.375, ~gutter=0.5, ~offset=1.25);
  let mobileWidth = mobileInfo.backgroundWidth;

  let fullInfo = bg(~row=0.5, ~col=6.0, ~gutter=1.0, ~offset=0.5);
  let fullWidth = fullInfo.backgroundWidth;
  Css.[
    unsafe("content", ""),
    position(`absolute),
    height(`percent(100.0)),
    top(`px(0)),
    zIndex(1000),
    mobileInfo.left,
    pointerEvents(`none),
    unsafe("width", mobileInfo.width),
    unsafe("background-image", mobileInfo.backgroundImage),
    unsafe("background-size", {j|$mobileWidth 100%|j}),
    media(
      Style.MediaQuery.full,
      [
        fullInfo.left,
        unsafe("width", fullInfo.width),
        unsafe("background-image", fullInfo.backgroundImage),
        unsafe("background-size", {j|$fullWidth 100%|j}),
      ],
    ),
  ];
};
