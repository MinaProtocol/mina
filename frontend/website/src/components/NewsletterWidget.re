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
  let (successState, showSuccess) = React.useState(() => false);
  let (email, setEmail) = React.useState(() => "");

  <form
    className=Styles.container
    onSubmit={e => {
      ReactEvent.Form.preventDefault(e);
      ReFetch.fetch(
        "https://jfs501bgik.execute-api.us-east-2.amazonaws.com/dev/subscribe",
        ~method_=Post,
        ~body=
          Fetch.BodyInit.makeWithUrlSearchParams(
            urlSearchParams({"email": email}),
          ),
        ~mode=NoCORS,
      )
      |> Promise.iter(_ => {
           showSuccess(_ => true);
           ignore @@ Js.Global.setTimeout(() => showSuccess(_ => false), 5000);
         });
    }}>
    <div
      className=Css.(
        style([
          marginBottom(px(8)),
          textAlign(centerText ? `center : `left),
        ])
      )>
      {React.string("Subscribe to our newsletter for updates")}
    </div>
    {successState
       ? <div className=Styles.successMessage>
           {React.string({js|✓ Check your email|js})}
         </div>
       : <>
           <input
             type_="email"
             value=email
             placeholder="janedoe@example.com"
             onChange={e => {
               let value = ReactEvent.Form.target(e)##value;
               setEmail(_ => value);
             }}
             className=Styles.textField
           />
           <input type_="submit" value="Subscribe" className=Styles.submit />
         </>}
  </form>;
};
