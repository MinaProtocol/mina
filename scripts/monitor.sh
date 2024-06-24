while true; do
    checkpoint=$(find . -name "replayer-checkpoint*" -print0 | xargs -r -0 ls -1 -t | head -1)
    timeout 21600 _build/default/src/app/replayer/replayer.exe --migration-mode --archive-uri $1 --checkpoint-interval 100 --input-file $checkpoint
    sleep 10
done
