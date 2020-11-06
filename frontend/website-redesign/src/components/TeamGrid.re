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
let make = (~profiles, ~switchModalState, ~setCurrentMember) => {
  <div className=Styles.grid>
    {React.array(
       Array.map(
         (p: ContentType.TeamProfile.t) => {
           <div key={p.name} onClick={_ => setCurrentMember(p)}>
             <TeamMember
               fullName={p.name}
               title={p.title}
               src={p.image.fields.file.url}
               switchModalState
             />
           </div>
         },
         profiles,
       ),
     )}
  </div>;
};
