for exe in $(find _build/default -type f -name run.exe)
do
  module=$(echo "$exe" | sed -e 's/^.\+\.\(.\+\)\.inline-tests\/run\.exe/\1/')
  "$exe" inline-test-runner "$module" -verbose
done
