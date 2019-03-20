let component = ReasonReact.statelessComponent("Page.Wrapped");
let make = children => {
  ...component,
  render: _ => {
    <div
      className=Css.(
        style([
          margin(`auto),
          media(
            Style.MediaQuery.full,
            [maxWidth(`rem(84.0)), margin(`auto)],
          ),
        ])
      )>
      ...children
    </div>;
  },
};
