module CareerApplyItem = {
  let component = ReasonReact.statelessComponent("Career");
  let make = (~filename, ~name, _) => {
    ...component,
    render: _self =>
      <li className="list lh-copy">
        <a
          href={"/jobs/" ++ filename ++ ".html"}
          className="f5 dodgerblue fw5 no-underline hover-link">
          {ReasonReact.string(name)}
        </a>
      </li>,
  };
};

let str = ReasonReact.string;

let dot = {
  str({js|·|js});
};

let extraHeaders =
  <>
    <link rel="stylesheet" type_="text/css" href="/static/css/careers.css" />
    <link
      rel="stylesheet"
      type_="text/css"
      href="https://use.typekit.net/mta7mwm.css"
    />
  </>;

let component = ReasonReact.statelessComponent("Career");
let make = (~jobOpenings, _) => {
  ...component,
  render: _self => {
    let jobItems =
      Array.map(
        ((filename, name)) => <CareerApplyItem filename name />,
        jobOpenings,
      );

    <div>
      <div className="mw960 pv3 center ph3 ibmplex oceanblack">
        <h1
          className="fadedblue aktivgroteskex careers-double-line-header ttu f5 fw5 tracked-more mb4">
          {str("Work with us!")}
        </h1>
        <div>
          <div className="dn db-ns">
            <div>
              <div className="careers-gallery-row1">
                <img src="/static/img/careers/group-outside.jpg" />
                <img src="/static/img/careers/group-in-house.jpg" />
              </div>
              <div className="careers-gallery-row2">
                <img src="/static/img/careers/nacera-outside.jpg" />
                <img src="/static/img/careers/john-cooking.jpg" />
                <img src="/static/img/careers/vanishree-talking.jpg" />
              </div>
            </div>
          </div>
          <div className="db dn-ns">
            <img className="" src="/static/img/careers/group-outside.jpg" />
          </div>
        </div>
        <div className="mw800 center">
          <p className="lh-copy f3 ocean f2-ns tracked-tightly">
            {str(
               "We're using cryptography and cryptocurrency to build computing systems that put people back in control of their digital lives.",
             )}
          </p>
          <div className="mt45">
            <hr className="mt45 ml0 mr0 mt0 mb0 b0 h2px bg-extradarksnow" />
            <div className="mt45">
              <div>
                <div className="dn db-ns">
                  <div className="flex justify-between mt45">
                    <h2
                      className="pr2 fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                      {str("Open Source")}
                    </h2>
                    <p className="w-65 mt0 mb0 lh-copy">
                      {str(
                         "We passionately believe in the open-source philosophy, and make our software free for the entire world to use.",
                       )}
                      <a
                        href="/static/code.html"
                        className="dodgerblue fw5 no-underline hover-link">
                        {str("Take a look →")}
                      </a>
                    </p>
                  </div>
                </div>
                <div className="db dn-ns">
                  <div className="mt45">
                    <h2
                      className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                      {str("Open Source")}
                    </h2>
                    <p className="mt3 mb0 ml15 lh-copy">
                      {str(
                         "We passionately believe in the open-source philosophy, and make our software free for the entire world to use.",
                       )}
                      <a
                        href="/static/code.html"
                        className="dodgerblue fw5 no-underline hover-link">
                        {str("Take a look →")}
                      </a>
                    </p>
                  </div>
                </div>
              </div>
              <div>
                <div className="dn db-ns">
                  <div className="flex justify-between mt45">
                    <h2
                      className="pr2 fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                      {str("Collaboration")}
                    </h2>
                    <p className="w-65 mt0 mb0 lh-copy">
                      {str(
                         "The problems we face are novel and challenging and we take them on as a team.",
                       )}
                    </p>
                  </div>
                </div>
                <div className="db dn-ns">
                  <div className="mt45">
                    <h2
                      className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                      {str("Collaboration")}
                    </h2>
                    <p className="mt3 mb0 ml15 lh-copy">
                      {str(
                         "The problems we face are novel and challenging and we take them on as a team.",
                       )}
                    </p>
                  </div>
                </div>
              </div>
              <div>
                <div className="dn db-ns">
                  <div className="flex justify-between mt45">
                    <h2
                      className="pr2 fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                      {str("Inclusion")}
                    </h2>
                    <p className="w-65 mt0 mb0 lh-copy">
                      {str(
                         "We're working on technologies with the potential to reimagine social structures. We believe it's important to incorporate diverse perspectives from conception through realization.",
                       )}
                    </p>
                  </div>
                </div>
                <div className="db dn-ns">
                  <div className="mt45">
                    <h2
                      className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                      {str("Inclusion")}
                    </h2>
                    <p className="mt3 mb0 ml15 lh-copy">
                      {str(
                         "We're working on technologies with the potential to reimagine social structures. We believe it's important to incorporate diverse perspectives from conception through realization.",
                       )}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div>
            <hr className="mt45 ml0 mr0 mt0 mb0 b0 h2px bg-extradarksnow" />
            <div>
              <div className="dn db-ns">
                <div className="flex justify-between mt45">
                  <h2
                    className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                    {str("Benefits")}
                  </h2>
                  <div className="w-70 mt3">
                    <div className="flex justify-between ">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Healthcare")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "We cover 100% of employee premiums for platinum healthcare plans with zero deductible, and 99% of vision and dental premiums",
                           )}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("401k")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "401k contribution matching up to 3% of salary",
                           )}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Education")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "$750 annual budget for conferences of your choice (we cover company-related conferences)",
                           )}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str("Office library")}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str("Twice-a-week learning lunches")}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Equipment")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "Top-of-the-line laptop, $500 monitor budget and $500 peripheral budget",
                           )}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Time off")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "Unlimited vacation, with encouragement for employees to take off",
                           )}
                          <span className="i"> {str("at least")} </span>
                          {str("14 days annually")}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Meals")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "Healthy snacks and provided lunch twice a week",
                           )}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Other")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str("Parental leave")}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str("Commuting benefits")}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str("Bike-friendly culture")}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "Take up to 1 day of PTO per year to volunteer",
                           )}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "We match nonprofit donations up to $500 per year",
                           )}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str("...and many others!")}
                        </li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
              <div className="db dn-ns">
                <div className="mt45">
                  <h2
                    className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                    {str("Benefits")}
                  </h2>
                  <div className="mt4 ml15 mt3">
                    <div className="flex justify-between ">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Healthcare")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "We cover 100% of employee premiums for platinum healthcare plans with zero deductible, and 99% of vision and dental premiums",
                           )}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("401k")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "401k contribution matching up to 3% of salary",
                           )}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Education")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "$750 annual budget for conferences of your choice (we cover company-related conferences)",
                           )}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str("Office library")}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str("Twice-a-week learning lunches")}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Equipment")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "Top-of-the-line laptop, $500 monitor budget and $500 peripheral budget",
                           )}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Time off")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "Unlimited vacation, with encouragement for employees to take off",
                           )}
                          <span className="i"> {str("at least")} </span>
                          {str("14 days annually")}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Meals")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "Healthy snacks and provided lunch twice a week",
                           )}
                        </li>
                      </ul>
                    </div>
                    <div className="flex justify-between mt4">
                      <div className="flex justify-end w-30">
                        <h3 className="fw6 f5 ph4 mt0 mb0">
                          {str("Other")}
                        </h3>
                      </div>
                      <ul className="mt0 mb0 ph0 w-70">
                        <li className="lh-copy list mb0 mt0">
                          {str("Parental leave")}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str("Commuting benefits")}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str("Bike-friendly culture")}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "Take up to 1 day of PTO per year to volunteer",
                           )}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str(
                             "We match nonprofit donations up to $500 per year",
                           )}
                        </li>
                        <li className="lh-copy list mb0 mt0">
                          {str("...and many others!")}
                        </li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div>
            <hr className="mt45 ml0 mr0 mt0 mb0 b0 h2px bg-extradarksnow" />
            <div>
              <div className="dn db-ns">
                <div className="flex justify-between mt45">
                  <div className="w-50">
                    <h2
                      className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                      {str("Apply")}
                    </h2>
                  </div>
                  <div className="w-50">
                    <ul className="mt0 mb0 ph0"> ...jobItems </ul>
                  </div>
                </div>
              </div>
              <div className="db dn-ns">
                <div className="mt45">
                  <h2
                    className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                    {str("Apply")}
                  </h2>
                  <ul className="mt4 ml15 mb0 ph0"> ...jobItems </ul>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>;
  },
};
