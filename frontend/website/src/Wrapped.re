let component = ReasonReact.statelessComponent("Page.Wrapped");
let make = (~overflowHidden=false, children) => {
  ...component,
  render: _ => {
    <div
      className=Css.(
        style(
          (overflowHidden ? [overflow(`hidden)] : [])
          @ [
            margin(`auto),
            media(
              Style.MediaQuery.full,
              [
                maxWidth(`rem(84.0)),
                margin(`auto),
                ...Style.paddingX(`rem(3.0)),
              ],
            ),
            ...Style.paddingX(`rem(1.25)),
          ],
        )
      )>
      ...children
    </div>;
  },
};
