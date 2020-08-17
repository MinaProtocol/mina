module Colors = {
  let orange = `hex("ff603b");
  let mint = `hex("9fe4c9");
  let gray = `hex("d9d9d9");
  let white = Css.white;
  let black = Css.black;
};

module Typeface = {
  open Css;
  let monumentGrotesk = fontFamily("Monument Grotesk, serif");
  let monumentGroteskMono = fontFamily("Monument Grotesk mono, serif");
  let ibmplexsans =
    fontFamily("IBM Plex Sans, Helvetica Neue, Arial, sans-serif");
  let ibmplexmono = fontFamily("IBM Plex Mono, Menlo, monospace");
};

module MediaQuery = {
  let tablet = "(min-width:48rem)";
  let desktop = "(min-width:90rem)";
  
  /** to add a style to tablet and desktop, but not mobile */
  let notMobile = "(min-width:23.5rem)";
  
  /** to add a style just to mobile  */
  let mobile= "(max-width:48rem)";
};

// module Type = {
//   let h1jumbo = ...;
//   let h1 = ...;
//   let h2 = ...;
//   let h3 = ...;
//   let h4 = ...;
//   let h5 = ...;
//   let h6 = ...;
//   let pageLabel = ...;
//   let label = ...;
//   let buttonLabel = ...;
//   let navLink = ...;
//   let sidebarLink = ...;
//   let tooltip = ...;
//   let creditName = ...;
//   let metadata = ...;
//   let announcement = ...;
//   let pageSubhead = ...;
//   let sectionSubhead = ...;
//   let paragraph = ...;
//   let paragraphSmall = ...;
//   let paragraphMono = ...;
//   let quote = ...;
// };

/** sets both paddingLeft and paddingRight, or paddingTop and paddingBottom as one should */
let paddingX = m => Css.[paddingLeft(m), paddingRight(m)];
let paddingY = m => Css.[paddingTop(m), paddingBottom(m)];

let generateStyles = rules => (Css.style(rules), rules);