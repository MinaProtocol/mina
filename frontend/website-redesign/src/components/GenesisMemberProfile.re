module Styles = {
  open Css;
  let outerBox = style([padding2(~v=`rem(2.5), ~h=`rem(0.))]);
  let container =
    style([
      position(`relative),
      display(`flex),
      paddingBottom(`rem(3.)),
      width(`rem(23.)),
      height(`rem(33.)),
      background(`hex("F5F5F5")),
    ]);
  let memberName =
    merge([
      Theme.Type.h3,
      style([
        position(`absolute),
        fontWeight(`light),
        top(`rem(6.3)),
        left(`rem(2.5)),
      ]),
    ]);
  let profilePicture =
    style([
      position(`absolute),
      left(`rem(2.5)),
      background(white),
      marginTop(`rem(-3.)),
      height(`rem(7.75)),
      width(`rem(8.125)),
    ]);
  let link =
    merge([
      Theme.Type.metadata,
      style([
        textDecoration(`none),
        color(Theme.Colors.black),
        hover([color(Theme.Colors.orange)]),
      ]),
    ]);
  let genesisLabel =
    merge([
      Theme.Type.paragraphMono,
      style([position(`absolute), top(`rem(9.25)), left(`rem(2.5))]),
    ]);
  let quoteSection =
    merge([
      Theme.Type.paragraphMono,
      style([
        position(`absolute),
        top(`rem(12.)),
        left(`rem(2.5)),
        width(`rem(18.)),
      ]),
    ]);
  let quote = style([marginTop(`rem(1.5)), marginBottom(`rem(1.5))]);
  let socials =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      flexDirection(`row),
      position(`absolute),
      top(`rem(29.)),
      left(`rem(2.5)),
      width(`rem(18.)),
    ]);
  let location =
    style([
      display(`flex),
      alignItems(`center),
      marginBottom(`rem(0.5)),
      selector("p", [marginTop(`zero), marginBottom(`zero)]),
    ]);
  let socialTags =
    style([
      display(`flex),
      flexDirection(`row),
      justifyContent(`spaceBetween),
      maxWidth(`rem(15.)),
      selector("> :first-child", [marginLeft(`zero)]),
    ]);
  let iconLink = style([color(black), marginLeft(`rem(1.))]);
  let button =
    style([position(`absolute), left(`rem(2.5)), bottom(`rem(2.4))]);
  let buttonLink = style([textDecoration(none), color(black)]);
};
[@react.component]
let make = (~name, ~photo, ~quote, ~location, ~twitter, ~github, ~blogPost) => {
  <div className=Styles.outerBox>
    <div className=Styles.container>
      <img src=photo alt=name className=Styles.profilePicture />
      <h4 className=Styles.memberName> {React.string(name)} </h4>
      <p className=Styles.genesisLabel>
        {React.string("Genesis Founding Member")}
      </p>
      <div className=Styles.quoteSection>
        <Rule />
        <p className=Styles.quote> {React.string(quote)} </p>
        <Rule />
      </div>
      <div className=Styles.socials>
        <>
          <div className=Styles.location>
            <Icon kind=Icon.Location />
            <Spacer width=0.3 />
            <p className=Theme.Type.paragraph> {React.string(location)} </p>
          </div>
        </>
        <div className=Styles.socialTags>
          <a
            href={"https://twitter.com/" ++ twitter} className=Styles.iconLink>
            <Icon kind=Icon.Twitter />
          </a>
          {switch (github) {
           | Some(github) =>
             <a
               href={"https://github.com/" ++ github}
               className=Styles.iconLink>
               <Icon kind=Icon.Github />
             </a>
           | _ => React.null
           }}
        </div>
      </div>
    </div>
  </div>;
};
