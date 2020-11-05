module Styles = {
  open Css;
  let grid =
    style([
      display(`grid),
      paddingTop(`rem(1.)),
      gridTemplateColumns([`rem(10.), `rem(10.)]),
      gridAutoRows(`rem(17.3)),
      gridColumnGap(`rem(1.)),
      gridRowGap(`rem(1.)),
      media(
        Theme.MediaQuery.tablet,
        [
          gridTemplateColumns([
            `rem(10.),
            `rem(10.),
            `rem(10.),
            `rem(10.),
          ]),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          gridTemplateColumns([
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
            `rem(11.),
          ]),
        ],
      ),
    ]);
};

[@react.component]
let make = (~profiles, ~switchModalState) => {
  <div className=Styles.grid>
    {React.array(
       Array.map(
         (p: ContentType.TeamProfile.t) => {
           Js.log(p);
           <div key={p.name}>
             <TeamMember
               fullName={p.name}
               title={p.title}
               switchModalState
               src={p.image.fields.file.url}
             />
           </div>;
         },
         profiles,
       ),
     )}
  </div>;
};
