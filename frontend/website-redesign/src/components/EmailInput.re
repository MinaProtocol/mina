open Css;
module Styles = {
  let textField =
    style([
      display(`inlineFlex),
      alignItems(`center),
      height(px(40)),
      borderRadius(px(4)),
      width(`rem(21.)),
      fontSize(rem(1.)),
      padding(px(12)),
      border(px(1), `solid, Theme.Colors.white),
      active([
        outline(px(0), `solid, `transparent),
        padding(px(11)),
        borderWidth(px(2)),
        borderColor(Theme.Colors.purple),
      ]),
      focus([
        boxShadow(~x=px(0), ~y=px(2), ~blur=px(4), `rgba((0, 0, 0, 0.2))),
        outline(px(0), `solid, `transparent),
        padding(px(11)),
        borderWidth(px(2)),
        borderColor(Theme.Colors.purple),
      ]),
      hover([borderColor(Theme.Colors.purple)]),
    ]);
  let submitButton =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(center),
      width(`rem(4.68)),
    ]);

  let successText = merge([Theme.Type.paragraph, style([color(white)])]);
  let successState =
    style([
      width(`rem(8.)),
      height(`rem(1.5)),
      padding2(~v=`rem(0.875), ~h=`rem(1.)),
      border(px(1), `solid, Theme.Colors.orange),
    ]);
};

[@bs.new]
external urlSearchParams: Js.t('a) => Fetch.urlSearchParams =
  "URLSearchParams";

[@react.component]
let make = () => {
  let (successState, showSuccess) = React.useState(() => false);
  let (email, setEmail) = React.useState(() => "");
  let submitForm = e => {
    ReactEvent.Mouse.preventDefault(e);
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
    ();
  };
  <>
    {successState
       ? <div className=Styles.successState>
           <span className=Styles.successText>
             {React.string({js|Check your email!|js})}
           </span>
         </div>
       : <div>
           <input
             type_="email"
             value=email
             placeholder="Enter Email:"
             onChange={e => {
               let value = ReactEvent.Form.target(e)##value;
               setEmail(_ => value);
             }}
             className=Styles.textField
           />
           <Spacer height=1. />
           <Button
             height={`rem(3.25)}
             width={`rem(7.93)}
             onClick={e => submitForm(e)}
             dark=true>
             <span className=Styles.submitButton>
               {React.string("Submit")}
               <Icon kind=Icon.ArrowRightMedium />
             </span>
           </Button>
         </div>}
  </>;
};
