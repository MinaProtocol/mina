module Styles = {
  open Css;
  let outerBox =
    style([
      display(`flex),
      justifyContent(`center),
      alignContent(`center),
    ]);
  let container =
    style([
      position(`relative),
      display(`flex),
      paddingBottom(`rem(3.)),
      justifyContent(`center),
      alignContent(`center),
      width(`rem(21.25)),
      height(`rem(31.5)),
      borderRadius(`px(6)),
      background(`hex("F5F5F5")),
      border(`px(1), `solid, Theme.Colors.teal),
    ]);
  let innerFlex = style([display(`flex), flexDirection(`column)]);
  let info =
    style([
      display(`flex),
      height(`rem(29.375)),
      justifyContent(`spaceBetween),
      flexDirection(`column),
    ]);
  let profilePic =
    style([
      position(`absolute),
      borderRadius(`percent(50.)),
      background(white),
      marginTop(`rem(-3.)),
      border(`px(1), `solid, Theme.Colors.saville),
      padding(`px(5)),
      height(`rem(6.25)),
      width(`rem(6.25)),
    ]);
  let memberName =
    style([
      height(`px(32)),
      marginTop(`px(62)),
      display(`flex),
      alignItems(`center),
      margin3(~top=`rem(4.6), ~h=`auto, ~bottom=`zero),
    ]);
  let icon =
    style([paddingTop(`px(2)), height(`auto), alignSelf(`center)]);
  let genesisLabel =
    style([
      margin2(~v=`rem(0.6875), ~h=`auto),
      borderRadius(`px(4)),
      background(`hex("757575")),
      Theme.Typeface.ibmplexsans,
      fontSize(`rem(0.68)),
      textTransform(`uppercase),
      letterSpacing(`px(1)),
      lineHeight(`rem(1.)),
      color(white),
      height(`rem(1.)),
      width(`rem(12.0)),
      padding2(~h=`rem(0.5), ~v=`zero),
    ]);
  let quote =
    merge([
      Theme.Body.basic,
      style([margin2(~v=`zero, ~h=`rem(1.5)), alignSelf(`center)]),
    ]);
  let socials =
    style([
      display(`flex),
      justifyContent(`spaceAround),
      flexDirection(`column),
      margin2(~v=`zero, ~h=`auto),
      selector("> :last-child", [marginBottom(`zero)]),
    ]);
  let socialTag =
    style([
      display(`flex),
      alignItems(`center),
      marginBottom(`rem(0.5)),
      selector("p", [marginTop(`zero), marginBottom(`zero)]),
    ]);

  let ctaButton =
    merge([
      Theme.Body.basic_semibold,
      style([
        width(`rem(14.)),
        height(`rem(3.)),
        backgroundColor(Theme.Colors.hyperlink),
        borderRadius(`px(6)),
        textDecoration(`none),
        color(white),
        padding2(~v=`px(12), ~h=`px(24)),
        textAlign(`center),
        alignSelf(`center),
        hover([backgroundColor(Theme.Colors.hyperlinkHover)]),
      ]),
    ]);

  let link =
    merge([
      Theme.Body.basic_small,
      style([
        textDecoration(`none),
        hover([color(Theme.Colors.hyperlinkHover)]),
      ]),
    ]);
};
[@react.component]
let make = (~name, ~photo, ~quote, ~location, ~twitter, ~github, ~blogPost) => {
  <div className=Styles.outerBox>
    <div className=Styles.container>
      <img src=photo alt=name className=Styles.profilePic />
      <div className=Styles.innerFlex>
        <span className=Styles.memberName>
          <img src="/static/img/Icon.Discord.svg" className=Styles.icon />
          <Spacer width=0.31 />
          <h4 className=Theme.H4.header> {React.string(name)} </h4>
        </span>
        <p className=Styles.genesisLabel>
          {React.string("Genesis Founding Member")}
        </p>
        <span className=Styles.info>
          <p className=Styles.quote> {React.string(quote)} </p>
          <div className=Styles.socials>
            <div className=Styles.socialTag>
              <img src="/static/img/Location.svg" />
              <Spacer width=0.34 />
              <p className=Theme.Body.basic_small>
                {React.string(location)}
              </p>
            </div>
            <div className=Styles.socialTag>
              <img src="/static/img/Icon.Twitter.svg" />
              <Spacer width=0.34 />
              <a
                href={"https://twitter.com/" ++ twitter} className=Styles.link>
                {React.string(twitter)}
              </a>
            </div>
            {switch (github) {
             | Some(github) =>
               <div className=Styles.socialTag>
                 <img src="/static/img/Icon.Git.svg" />
                 <Spacer width=0.34 />
                 <a
                   href={"https://github.com/" ++ github}
                   className=Styles.link>
                   {React.string(github)}
                 </a>
               </div>
             | _ => React.null
             }}
          </div>
          <Next.Link href="/blog/[slug]" _as={"/blog/" ++ blogPost}>
            <a className=Styles.ctaButton>
              {React.string({js|Learn More|js})}
            </a>
          </Next.Link>
        </span>
      </div>
    </div>
  </div>;
};
