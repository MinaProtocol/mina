module Styles = {
  open Css;
  let announcementBanner = dark =>
    merge([
      Theme.Type.announcement,
      style([
        color(dark ? white : Theme.Colors.digitalBlack),
        display(`flex),
        justifyContent(`spaceBetween),
        alignItems(`center),
        width(`percent(100.)),
        important(backgroundSize(`cover)),
        dark
          ? backgroundColor(black)
          : backgroundImage(`url("/static/img/AnnouncementBanner.png")),
        padding2(~v=`rem(0.5), ~h=`rem(0.5)),
      ]),
    ]);

  let flexCenter = style([display(`flex), alignItems(`center)]);

  let hideIfMobileElseShow =
    style([
      display(`none),
      media(Theme.MediaQuery.notMobile, [display(`flex)]),
    ]);

  let orangeText =
    style([
      color(Theme.Colors.orange),
      lineHeight(`rem(1.)),
      fontWeight(`num(550)),
    ]);

  let changeRegionSection =
    merge([flexCenter, style([paddingRight(`rem(1.))])]);

  let announcementText = style([paddingLeft(`rem(2.))]);

  let link =
    merge([
      flexCenter,
      style([cursor(`pointer), color(Theme.Colors.orange)]),
    ]);

  let learnMoreText =
    merge([
      orangeText,
      style([
        marginLeft(`rem(0.4)),
        marginRight(`rem(0.2)),
        cursor(`pointer),
        hover([borderBottom(`px(1), `solid, Theme.Colors.orange)]),
      ]),
    ]);

  let changeRegionText =
    merge([
      orangeText,
      hideIfMobileElseShow,
      style([paddingLeft(`rem(0.5)), paddingRight(`rem(0.5))]),
    ]);

  let linkAnchor = merge([orangeText, style([textDecoration(`none)])]);
};

[@react.component]
let make = (~children, ~dark=false) => {
  <div className={Styles.announcementBanner(dark)}>

      <div className=Styles.flexCenter>
        <span className=Styles.announcementText> children </span>
        <a
          className=Styles.linkAnchor
          href="https://share.hsforms.com/1olz9N8_zTHW-RKQus2o3Kw4xuul">
          <div className=Styles.link>
            <span className=Styles.learnMoreText>
              {React.string("Subscribe to stay updated")}
            </span>
            <Icon kind=Icon.ArrowRightMedium />
          </div>
        </a>
      </div>
    </div>;
    //<div className=Styles.changeRegionSection>
    //  <Icon kind=Icon.World />
    //  <span
    //    className=Css.(
    //      merge([Styles.flexCenter, Styles.hideIfMobileElseShow])
    //    )>
    //    <span className=Styles.changeRegionText>
    //      {React.string("Change Region")}
    //    </span>
    //    <Icon kind=Icon.ChevronDown />
    //  </span>
    // </div>
};
