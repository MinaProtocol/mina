@echo off
echo [[compile BN254Test.java]]
%JAVA_DIR%\bin\javac BN254Test.java

echo [[run BN254Test]]
pushd ..\bin
%JAVA_DIR%\bin\java -classpath ..\java BN254Test %1 %2 %3 %4 %5 %6
popd
