set -e

cd container
jbuilder build
docker build -t testbridge .
docker tag testbridge localhost:5000/testbridge
docker push localhost:5000/testbridge
