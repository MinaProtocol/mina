let component = ReasonReact.statelessComponent("Header");

let make = _children => {
  ...component,
  render: _self =>
    <div
      style={ReactDOMRe.Style.unsafeAddProp(
        ReactDOMRe.Style.make(
          ~cursor="default",
          ~userSelect="none",
          ~backgroundColor="#0d1a30",
          ~color="white",
          ~fontWeight="100",
          ~fontFamily="Sans-Serif",
          ~fontSize="150%",
          ~padding="15px",
          (),
        ),
        "-webkit-app-region",
        "drag",
      )}>
      {ReasonReact.string({j|⬜ CODA|j})}
    </div>,
};
