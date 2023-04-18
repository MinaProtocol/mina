rm -rf wrk2 && \
git clone https://github.com/giltene/wrk2.git && \
cd wrk2 && \
make && \
./wrk -t1 -c1 -d120s -R1 --latency --timeout 2s -s /tmp/version-post.lua http://127.0.0.1:3085/graphql > /tmp/wrk_output.txt