open Css; 
  
  let ocrastud = 
    fontFace(
        ~fontFamily="OCR A Std",
        ~src=[`url("/static/fonts/OCRAStdRegular.otf")],
        ~fontStyle=`normal,
        ~fontWeight=`normal,
        (),
      );
      
 let ibmplexsans =
    fontFace(
      ~fontFamily="IBM Plex Sans",
      ~src=[url("/static/fonts/IBMPlexSans-SemiBold-Latin1.woff2")],
      ~fontStyle=`normal,
      ~fontWeight=`semiBold,
      (),
    );
