// Siplified from https://gist.github.com/joshuacerbito/ea318a6a7ca4336e9fadb9ae5bbb87f4
[@bs.val][@bs.scope("window")] external scrollY: int = "scrollY";

[@bs.val]
external addScrollListener: ([@bs.as "scroll"] _, Dom.event => unit) => unit =
  "addEventListener";
[@bs.val]
external removeScrollListener: ([@bs.as "scroll"] _, Dom.event => unit) => unit =
  "removeEventListener";

let useScroll = () => {
  let (bodyOffset, setBodyOffset) = React.useState(() => 0);

  let listener = _ => setBodyOffset(_ => scrollY);

  React.useEffect0(() => {
    addScrollListener(listener);
    Some(() => {removeScrollListener(listener)});
  });

  bodyOffset;
};
