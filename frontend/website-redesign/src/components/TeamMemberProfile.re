module Styles = {
  open Css;
  let outerBox = style([padding2(~v=`rem(2.5), ~h=`rem(0.))]);
  let container =
    style([
      display(`flex),
      flexDirection(`column),
      paddingBottom(`rem(3.)),
      width(`percent(100.)),
      height(`percent(100.)),
      background(`hex("F5F5F5")),
      padding2(~h=`rem(2.), ~v=`rem(1.5)),
    ]);

  let memberName = merge([Theme.Type.h3, style([fontWeight(`light)])]);

  let profilePicture =
    style([
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

  let memberTitle =
    merge([
      Theme.Type.label,
      style([
        fontSize(`rem(0.875)),
        marginBottom(`rem(1.)),
        media(
          Theme.MediaQuery.tablet,
          [fontSize(`px(12)), lineHeight(`px(16))],
        ),
      ]),
    ]);

  let quoteSection =
    merge([Theme.Type.paragraphSmall, style([width(`rem(18.))])]);

  let quote = style([marginTop(`rem(1.5)), marginBottom(`rem(1.5))]);

  let socials =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      flexDirection(`row),
      width(`rem(18.)),
      marginTop(`rem(1.)),
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

  let profileRow =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      width(`percent(100.)),
    ]);

  let buttons =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(`spaceBetween),
      marginTop(`rem(1.)),
      selector(">:first-child", [marginRight(`rem(1.))]),
      media(Theme.MediaQuery.notMobile, [marginTop(`zero)]),
    ]);

  let button =
    merge([
      Button.Styles.button(
        Theme.Colors.digitalBlack,
        Theme.Colors.white,
        Some(Theme.Colors.white),
        true,
        `rem(2.5),
        Some(`rem(2.5)),
        0.5,
        0.,
      ),
      style([cursor(`pointer)]),
    ]);

  let icon = style([cursor(`pointer)]);
};
[@react.component]
let make =
    (
      ~member: ContentType.TeamProfile.t,
      ~switchModalState,
      ~onNextMemberPress,
      ~onPrevMemberPress,
    ) => {
  <div className=Styles.outerBox>
    <div className=Styles.container>
      <div className=Styles.profileRow>
        <img
          src={member.image.fields.file.url}
          alt={member.name}
          className=Styles.profilePicture
        />
        <div className=Styles.icon onClick={_ => switchModalState()}>
          <Icon kind=Icon.CloseMenu />
        </div>
      </div>
      <h4 className=Styles.memberName> {React.string(member.name)} </h4>
      <p className=Styles.memberTitle> {React.string(member.title)} </p>
      <div className=Styles.quoteSection>
        <Rule />
        <p className=Styles.quote> {React.string(member.bio)} </p>
        <Rule />
      </div>
      <div className=Styles.socials>
        <div className=Styles.socialTags>
          {switch (member.twitter) {
           | Some(twitter) =>
             <a
               target="_blank"
               href={"https://twitter.com/" ++ twitter}
               className=Styles.iconLink>
               <Icon kind=Icon.Twitter />
             </a>
           | _ => React.null
           }}
          {switch (member.github) {
           | Some(github) =>
             <a
               target="_blank"
               href={"https://github.com/" ++ github}
               className=Styles.iconLink>
               <Icon kind=Icon.Github />
             </a>
           | _ => React.null
           }}
          {switch (member.linkedIn) {
           | Some(linkedIn) =>
             <a
               target="_blank"
               href={"https://linkedin.com/in/" ++ linkedIn}
               className=Styles.iconLink>
               <Icon kind=Icon.Twitter />
             </a>
           | _ => React.null
           }}
        </div>
        <div className=Styles.buttons>
          <div className=Styles.button onClick={_ => onPrevMemberPress()}>
            <Icon kind=Icon.ArrowLeftLarge />
          </div>
          <div className=Styles.button onClick={_ => onNextMemberPress()}>
            <Icon kind=Icon.ArrowRightLarge />
          </div>
        </div>
      </div>
    </div>
  </div>;
};
