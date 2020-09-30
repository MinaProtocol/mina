module Styles = {
  open Css;

  let container =
    style([
      Theme.Typeface.monumentGrotesk,
      color(Css_Colors.white),
      display(`flex),
      position(`relative),
      width(`percent(100.)),
      fontWeight(`normal),
      media(Theme.MediaQuery.notMobile, [width(`auto)]),
    ]);

  let successMessage =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      transition("all", ~duration=150),
      marginTop(`rem(1.25)),
      media(Theme.MediaQuery.notMobile, [marginLeft(`rem(1.25))]),
      selector(
        "img",
        [
          display(`none),
          media(Theme.MediaQuery.notMobile, [display(`block)]),
        ],
      ),
    ]);

  let successText =
    style([
      marginRight(`rem(5.)),
      media(Theme.MediaQuery.notMobile, [marginLeft(`rem(1.25))]),
    ]);

  let textField =
    style([
      display(`inlineFlex),
      alignItems(`center),
      height(`rem(3.25)),
      borderRadius(`px(2)),
      width(`percent(100.)),
      fontSize(`rem(1.)),
      color(Theme.Colors.digitalBlack),
      padding2(~h=`rem(1.), ~v=`rem(0.875)),
      marginTop(`px(20)),
      marginRight(`rem(0.45)),
      border(px(1), `solid, Theme.Colors.gray),
      boxShadow(~y=`px(2), ~blur=`px(2), rgba(0, 0, 0, 0.15)),
      active([
        outline(px(0), `solid, `transparent),
        borderColor(Theme.Colors.gray),
      ]),
      focus([
        outline(px(0), `solid, `transparent),
        borderColor(Theme.Colors.gray),
      ]),
      hover([borderColor(Theme.Colors.gray)]),
      media(Theme.MediaQuery.notMobile, [width(px(272))]),
    ]);

  let button =
    merge([
      Button.Styles.button(
        Theme.Colors.orange,
        Theme.Colors.digitalBlack,
        true,
        `rem(3.25),
        `rem(7.7),
        1.5,
        1.,
      ),
      style([cursor(`pointer)]),
    ]);
};

[@bs.new]
external urlSearchParams: Js.t('a) => Fetch.urlSearchParams =
  "URLSearchParams";

[@react.component]
let make = (~buttonText="Submit") => {
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
           ignore @@ Js.Global.setTimeout(() => showSuccess(_ => true), 5000);
         });
    }}>
    {successState
       ? <div>
           <h2> {React.string("Thanks for signing up!")} </h2>
           <div className=Styles.successMessage>
             <img src="/static/img/TestWorldConfirmation.png" />
             <span className=Styles.successText>
               {React.string("Good to go!")}
             </span>
             <span>
               <Next.Link href="/genesis">
                 <button className=Styles.button type_="submit">
                   {React.string("Continue ")}
                   <Icon kind=Icon.ArrowRightMedium />
                 </button>
               </Next.Link>
             </span>
           </div>
         </div>
       : <div>
           <h2> {React.string("Sign Up to Receive Updates")} </h2>
           <div
             className=Css.(style([display(`flex), alignItems(`center)]))>
             <input
               type_="email"
               value=email
               placeholder="Enter Email"
               onChange={e => {
                 let value = ReactEvent.Form.target(e)##value;
                 setEmail(_ => value);
               }}
               className=Styles.textField
             />
             <span className=Css.(style([paddingTop(`px(16))]))>
               <button className=Styles.button>
                 {React.string("Submit")}
                 <Icon kind=Icon.ArrowRightMedium />
               </button>
             </span>
           </div>
         </div>}
  </form>;
};
