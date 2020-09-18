module Styles = {
  open Css;
  let page =
    style([display(`block), justifyContent(`center), overflowX(`hidden)]);

  let flexCenter =
    style([
      display(`flex),
      flexDirection(`column),
      alignItems(`flexStart),
    ]);

  let container =
    style([
      Theme.Typeface.monumentGrotesk,
      color(Css_Colors.white),
      display(`flex),
      flexDirection(`column),
      overflowX(`hidden),
      alignItems(`center),
      width(`percent(100.)),
      height(`percent(100.)),
      margin(`auto),
      padding2(~h=`rem(3.), ~v=`zero),
      paddingBottom(`rem(3.)),
    ]);

  let textContainer =
    merge([
      flexCenter,
      style([
        width(`percent(100.)),
        maxWidth(`rem(34.)),
        marginTop(`rem(6.25)),
        selector(
          "p,li,span",
          [fontSize(`rem(1.125)), lineHeight(`rem(1.75))],
        ),
        selector(
          "h1",
          [
            fontWeight(`num(540)),
            fontSize(`rem(3.)),
            lineHeight(`rem(3.625)),
          ],
        ),
        selector(
          "h2",
          [
            fontWeight(`num(530)),
            fontSize(`rem(2.5)),
            lineHeight(`rem(3.)),
          ],
        ),
      ]),
    ]);

  let background =
    style([
      width(`percent(100.)),
      height(`rem(180.)),
      backgroundColor(Theme.Colors.minaBlack),
      backgroundSize(`cover),
      backgroundImage(`url("/static/img/LeadGenBackground.jpg")),
    ]);

  let logo =
    style([width(`percent(100.)), height(`auto), marginTop(`rem(6.))]);

  let link = style([color(Theme.Colors.minaOrange), cursor(`pointer)]);

  let seperator =
    style([
      textTransform(`uppercase),
      display(`flex),
      alignItems(`center),
      textAlign(`center),
      width(`percent(100.)),
      marginBottom(`rem(1.)),
      letterSpacing(`rem(0.05)),
      fontSize(`rem(0.875)),
      selector(
        "::before,::after",
        [
          contentRule(""),
          flex(`num(1.)),
          borderBottom(`px(1), `solid, white),
          marginLeft(`rem(1.)),
          marginRight(`rem(1.)),
        ],
      ),
    ]);

  let dashedSeperator =
    style([
      position(`relative),
      display(`flex),
      alignItems(`center),
      width(`percent(100.)),
      borderBottom(`px(1), `dashed, Theme.Colors.white),
      color(Theme.Colors.white),
      marginTop(`rem(0.7)),
      marginBottom(`rem(0.25)),
      before([
        contentRule("\\25CF"),
        position(`absolute),
        display(`flex),
        alignItems(`center),
        margin(`auto),
        left(`px(-2)),
      ]),
      after([
        contentRule("\\25CF"),
        position(`absolute),
        display(`flex),
        alignItems(`center),
        margin(`auto),
        right(`px(-2)),
      ]),
    ]);

  let releaseContainer =
    style([
      display(`flex),
      flexDirection(`column),
      justifyContent(`spaceBetween),
      alignItems(`center),
      width(`percent(100.)),
      marginTop(`rem(1.125)),
      letterSpacing(`rem(0.01)),
      selector("> div:last-child", [marginTop(`rem(2.))]),
      media(
        Theme.MediaQuery.notMobile,
        [
          flexDirection(`row),
          selector("> div:last-child", [marginTop(`zero)]),
        ],
      ),
    ]);

  let release =
    style([
      textTransform(`uppercase),
      display(`flex),
      flexDirection(`column),
      justifyContent(`center),
      alignItems(`center),
      width(`percent(100.)),
      media(Theme.MediaQuery.notMobile, [width(`percent(40.))]),
      selector("div,span", [fontSize(`rem(0.875))]),
    ]);

  let releaseDates =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      width(`percent(100.)),
    ]);
};

// TODO: Move this into it's own file when moved over to new website
module SignupWidget = {
  module Styles = {
    open Css;

    let container =
      merge([
        Theme.Body.basic_semibold,
        style([
          Theme.Typeface.monumentGrotesk,
          color(Css_Colors.white),
          display(`flex),
          position(`relative),
          width(`percent(100.)),
          fontWeight(`normal),
          media(Theme.MediaQuery.notMobile, [width(`auto)]),
        ]),
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
        color(Theme.Colors.minaBlack),
        padding2(~h=`rem(1.), ~v=`rem(0.875)),
        marginTop(`px(20)),
        marginRight(`rem(0.45)),
        border(px(1), `solid, Theme.Colors.minaGrey),
        boxShadow(~y=`px(2), ~blur=`px(2), rgba(0, 0, 0, 0.15)),
        active([
          outline(px(0), `solid, `transparent),
          borderColor(Theme.Colors.minaGrey),
        ]),
        focus([
          outline(px(0), `solid, `transparent),
          borderColor(Theme.Colors.minaGrey),
        ]),
        hover([borderColor(Theme.Colors.minaGrey)]),
        media(Theme.MediaQuery.notMobile, [width(px(272))]),
      ]);

    let button =
      merge([
        MinaButton.Styles.button(
          Theme.Colors.minaOrange,
          Theme.Colors.minaBlack,
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
             ignore @@
             Js.Global.setTimeout(() => showSuccess(_ => true), 5000);
           });
      }}>
      {successState
         ? <div>
             <h2> {React.string("Thanks for signing up!")} </h2>
             <div className=Styles.successMessage>
               <img src="/static/img/testworld_confirmation.png" />
               <span className=Styles.successText>
                 {React.string("Good to go!")}
               </span>
               <span>
                 <Next.Link href="/genesis">
                   <button className=Styles.button type_="submit">
                     {React.string("Continue ")}
                     <MinaIcon kind=MinaIcon.ArrowRightMedium />
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
                   <MinaIcon kind=MinaIcon.ArrowRightMedium />
                 </button>
               </span>
             </div>
           </div>}
    </form>;
  };
};

[@react.component]
let make = () => {
  let renderTimeline = () => {
    <div className=Styles.textContainer>
      <div className=Styles.seperator>
        {React.string("Testworld timeline")}
      </div>
      <div className=Styles.releaseContainer>
        <div className=Styles.release>
          <div> {React.string("Level 1")} </div>
          <div className=Styles.dashedSeperator />
          <div className=Styles.releaseDates>
            <span> {React.string("Oct 13")} </span>
            <span> {React.string("Oct 23")} </span>
          </div>
        </div>
        <div className=Styles.release>
          <div> {React.string("Level 2")} </div>
          <div className=Styles.dashedSeperator />
          <div className=Styles.releaseDates>
            <span> {React.string("Oct 27")} </span>
            <span> {React.string("Nov 6")} </span>
          </div>
        </div>
      </div>
    </div>;
  };

  <Page title="Testworld" showFooter=false>
    <div className=Styles.page>
      <div className=Styles.background>
        <div className=Styles.container>
          <div>
            <img className=Styles.logo src="/static/img/testworld_logo.png" />
          </div>
          <div className=Styles.textContainer> <SignupWidget /> </div>
          <div className=Styles.textContainer>
            <h1> {React.string("Welcome to Testworld")} </h1>
            <p>
              {React.string(
                 "Get ready to join Coda's adversarial testnet, Testworld, starting later this year. In contrast to Coda's regular testnet, Testworld is where you will compete with others to maximize the amount of tokens earned, find critical bugs, and push the boundaries of the network in order to make Coda as secure as possible for mainnet.",
               )}
            </p>
          </div>
          <div className=Styles.textContainer>
            <h2> {React.string("How Testworld works")} </h2>
            <p>
              {React.string(
                 "To ensure the security of the protocol prior to mainnet, Coda is offering 1% of the total token supply as well as USD in rewards, which you can win by:",
               )}
            </p>
            <ul className=Css.(style([marginLeft(`rem(1.))]))>
              <li> {React.string("Uncovering vulnerabilities")} </li>
              <li> {React.string("Accruing testnet tokens")} </li>
              <li>
                {React.string(
                   "Scoring high points on the testnet leaderboard",
                 )}
              </li>
            </ul>
            <p className=Css.(style([marginTop(`rem(3.))]))>
              {React.string(
                 "In addition, the Coda Foundation will be delegating tokens reserved for future grants to participants who score top points for reliability and block production once mainnet is live.",
               )}
            </p>
          </div>
          <div className=Styles.textContainer>
            <h2> {React.string("Genesis Token Grant")} </h2>
            <span className=Css.(style([marginTop(`rem(1.))]))>
              {React.string(
                 "Testworld will be the last phase of Coda's testnet for community members to qualify for the ",
               )}
              <Next.Link href="/genesis">
                <span className=Styles.link>
                  {React.string("Genesis token grant ")}
                </span>
              </Next.Link>
              {React.string(
                 "before mainnet launches in Q4 of this year. There are up to 800 Genesis grants still available, and Genesis grant recipients, otherwise known as Genesis Founding Members (GFMs), will each receive 66,000 tokens. ",
               )}
              <Next.Link href="/genesis">
                <span className=Styles.link>
                  {React.string("Apply for Genesis now. ")}
                </span>
              </Next.Link>
            </span>
            <span className=Css.(style([marginTop(`rem(2.))]))>
              {React.string(
                 "Prepare to engage in Testworld and we'll see you in October.",
               )}
            </span>
          </div>
          <div className=Styles.textContainer> <SignupWidget /> </div>
        </div>
      </div>
    </div>
  </Page>;
};
