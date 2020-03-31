module Styles = {
  open Css;

  let container =
    merge([
      Theme.Body.basic_semibold,
      style([
        position(`relative),
        width(`percent(100.)),
        fontWeight(`normal),
        media(Theme.MediaQuery.notMobile, [width(`auto)]),
      ]),
    ]);

  let successMessage =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(`center),
      position(`absolute),
      bottom(`zero),
      left(`zero),
      height(px(40)),
      width(px(400)),
      background(white),
      border(px(1), `solid, Theme.Colors.jungle),
      color(Theme.Colors.jungle),
      borderRadius(px(4)),
      transition("all", ~duration=150),
    ]);

  let textField =
    style([
      display(`inlineFlex),
      alignItems(`center),
      height(px(40)),
      borderRadius(px(4)),
      width(`percent(100.)),
      fontSize(rem(1.)),
      color(Theme.Colors.teal),
      padding(px(12)),
      border(px(1), `solid, Theme.Colors.hyperlinkAlpha(0.3)),
      active([
        outline(px(0), `solid, `transparent),
        padding(px(11)),
        borderWidth(px(2)),
        borderColor(Theme.Colors.hyperlinkAlpha(1.)),
      ]),
      focus([
        outline(px(0), `solid, `transparent),
        padding(px(11)),
        borderWidth(px(2)),
        borderColor(Theme.Colors.hyperlinkAlpha(1.)),
      ]),
      hover([borderColor(Theme.Colors.hyperlinkAlpha(1.))]),
      media(Theme.MediaQuery.notMobile, [width(px(272))]),
    ]);

  let submit =
    style([
      display(`inlineFlex),
      alignItems(`center),
      justifyContent(`center),
      color(white),
      backgroundColor(Theme.Colors.clover),
      border(px(0), `solid, `transparent),
      marginTop(`rem(0.5)),
      marginLeft(`zero),
      height(px(40)),
      width(px(120)),
      fontWeight(`semiBold),
      fontSize(`percent(100.)),
      borderRadius(px(4)),
      cursor(`pointer),
      unsafe("WebkitAppearance", "none"),
      active([outline(px(0), `solid, `transparent)]),
      focus([outline(px(0), `solid, `transparent)]),
      hover([backgroundColor(Theme.Colors.jungle)]),
      disabled([backgroundColor(Theme.Colors.slateAlpha(0.3))]),
      media(
        Theme.MediaQuery.notMobile,
        [marginLeft(`rem(0.5)), marginTop(`zero)],
      ),
    ]);
};

[@bs.new]
external urlSearchParams: Js.t('a) => Fetch.urlSearchParams =
  "URLSearchParams";

[@react.component]
let make = (~center as centerText=false) => {
  <div
    className=Css.(
      style([marginBottom(px(8)), textAlign(centerText ? `center : `left)])
    )>
    <p className=Theme.Body.basic>
      {React.string(
         "Get started on Coda by applying for the Genesis Token Program.",
       )}
    </p>
    <Button
      link="https://codaprotocol.com/genesis"
      label="Join Genesis"
      bgColor=Theme.Colors.hyperlink
      bgColorHover={Theme.Colors.hyperlinkAlpha(1.)}
    />
  </div>;
};
