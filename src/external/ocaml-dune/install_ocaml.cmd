REM Download and install OCaml and flexlink (unless it was already done).
REM Prepare the environment variables,... to use it.  OCaml is installed
REM at %OCAMLROOT%
REM
REM If you are using Cygwin, install it in C:\cygwin first and then
REM execute this script.  Execute bash with the option "-l".

REM set OCAMLROOT=%PROGRAMFILES%/OCaml
set OCAMLROOT=C:/PROGRA~1/OCaml

set OCAMLURL=https://github.com/Chris00/ocaml-appveyor/releases/download/0.2/ocaml-4.06.zip

REM Cygwin is always installed on AppVeyor.  Its path must come
REM before the one of Git but after those of MSCV and OCaml.
set Path=C:\cygwin\bin;%Path%

call "C:\Program Files\Microsoft SDKs\Windows\v7.1\Bin\SetEnv.cmd" /x64

set Path=%OCAMLROOT%\bin;%OCAMLROOT%\bin\flexdll;%Path%
set CAML_LD_LIBRARY_PATH=%OCAMLROOT%/lib/stublibs

set CYGWINBASH=C:\cygwin\bin\bash.exe

if not exist "%OCAMLROOT%/bin/ocaml.exe" (
  echo Downloading OCaml...
  appveyor DownloadFile "%OCAMLURL%" -FileName "C:\PROGRA~1\ocaml.zip"
  %CYGWINBASH% -lc "cd /cygdrive/c/Program\ Files && unzip -q ocaml.zip"
  del C:\PROGRA~1\ocaml.zip
)

if exist %CYGWINBASH% (
  REM Make sure that "link" is the MSVC one and not the Cynwin one.
  %CYGWINBASH% -lc "eval $(/cygdrive/c/Program\ Files/OCaml/tools/msvs-promote-path)"> ~/.bash_profile"
)

set <NUL /p=Ready to use OCaml & ocamlc -version
