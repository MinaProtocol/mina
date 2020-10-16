module Styles = {
  open Css;
  let sectionBackgroundImage = backgroundImg =>
    style([
      height(`percent(100.)),
      width(`percent(100.)),
      paddingBottom(`rem(9.)),
      important(backgroundSize(`cover)),
      backgroundImage(`url(backgroundImg)),
    ]);
};

module Section = {
  module SectionStyles = {
    open Css;
    let rowContainer = (~reverse=false, ()) =>
      style([
        display(`flex),
        flexDirection(`column),
        justifyContent(`spaceBetween),
        width(`percent(100.)),
        alignItems(`center),
        marginTop(`rem(2.)),
        media(
          Theme.MediaQuery.tablet,
          [reverse ? flexDirection(`rowReverse) : flexDirection(`row)],
        ),
        media(
          Theme.MediaQuery.desktop,
          [reverse ? flexDirection(`rowReverse) : flexDirection(`row)],
        ),
      ]);

    let textContainer =
      style([
        width(`percent(100.)),
        media(Theme.MediaQuery.tablet, [maxWidth(`rem(29.))]),
      ]);

    let title = merge([Theme.Type.h2, style([marginTop(`rem(1.5))])]);

    let paragraphText =
      merge([Theme.Type.paragraph, style([marginTop(`rem(1.5))])]);

    let icon =
      style([
        display(`flex),
        alignItems(`center),
        justifyContent(`center),
        marginLeft(`rem(0.3)),
        marginTop(`rem(0.2)),
      ]);

    let image =
      style([
        width(`percent(100.)),
        maxWidth(`rem(23.)),
        height(`auto),
        marginTop(`rem(2.)),
        media(Theme.MediaQuery.desktop, [maxWidth(`rem(35.))]),
      ]);
  };
  module SimpleRow = {
    type t = {
      title: string,
      description: string,
      buttonCopy: string,
      buttonUrl: [ | `External(string) | `Internal(string)],
      image: string,
    };

    module Styles = {
      open Css;

      let rowContainer = (~reverse=false, ()) =>
        merge([
          SectionStyles.rowContainer(~reverse, ()),
          style([borderTop(`px(1), `solid, Theme.Colors.digitalBlack)]),
        ]);

      let button = style([marginTop(`rem(2.))]);

      let image =
        merge([SectionStyles.image, style([marginTop(`rem(2.))])]);
    };

    [@react.component]
    let make = (~rows) => {
      rows
      |> Array.mapi((idx, row) => {
           <div
             key={row.title}
             className={Styles.rowContainer(
               ~reverse={
                 idx mod 2 != 0;
               },
               (),
             )}>
             <div className=SectionStyles.textContainer>
               <h2 className=SectionStyles.title>
                 {React.string(row.title)}
               </h2>
               <p className=SectionStyles.paragraphText>
                 {React.string(row.description)}
               </p>
               <div className=Styles.button>
                 <Button href={row.buttonUrl} bgColor=Theme.Colors.white>
                   {React.string(row.buttonCopy)}
                   <span className=SectionStyles.icon>
                     <Icon kind=Icon.ArrowRightMedium />
                   </span>
                 </Button>
               </div>
             </div>
             <img src={row.image} className=Styles.image />
           </div>
         })
      |> React.array;
    };
  };

  module FeaturedRow = {
    type t = {
      title: string,
      description: string,
      linkCopy: string,
      linkUrl: string,
      image: string,
    };

    module Styles = {
      open Css;

      let seperator = seperatorNumber =>
        style([
          display(`flex),
          alignItems(`center),
          borderBottom(`px(1), `solid, Theme.Colors.digitalBlack),
          before([
            contentRule(seperatorNumber),
            Theme.Typeface.monumentGroteskMono,
            color(Theme.Colors.digitalBlack),
            lineHeight(`rem(1.5)),
            letterSpacing(`px(-1)),
          ]),
        ]);
    };

    [@react.component]
    let make = (~rows) => {
      rows
      |> Array.mapi((idx, row) => {
           <div
             key={row.title}
             className={SectionStyles.rowContainer(
               ~reverse={
                 idx mod 2 != 0;
               },
               (),
             )}>
             <div className=SectionStyles.textContainer>
               <div
                 className={Styles.seperator("0" ++ string_of_int(idx + 1))}
               />
               <h2 className=SectionStyles.title>
                 {React.string(row.title)}
               </h2>
               <p className=SectionStyles.paragraphText>
                 {React.string(row.description)}
               </p>
               <Next.Link href={row.linkUrl}>
                 <span>
                   <Spacer height=1. />
                   <span className=Theme.Type.buttonLink>
                     <span> {React.string(row.linkCopy)} </span>
                     <span className=SectionStyles.icon>
                       <Icon kind=Icon.ArrowRightSmall />
                     </span>
                   </span>
                 </span>
               </Next.Link>
             </div>
             <img src={row.image} className=SectionStyles.image />
           </div>
         })
      |> React.array;
    };
  };

  type t =
    | SimpleRow(array(SimpleRow.t))
    | FeaturedRow(array(FeaturedRow.t));
};

[@react.component]
let make = (~backgroundImg, ~sections) => {
  <div className={Styles.sectionBackgroundImage(backgroundImg)}>
    <Wrapped>
      {switch (sections) {
       | Section.FeaturedRow(rows) => <Section.FeaturedRow rows />
       | Section.SimpleRow(rows) => <Section.SimpleRow rows />
       }}
    </Wrapped>
  </div>;
};
