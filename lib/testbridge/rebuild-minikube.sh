set -e

cd container
jbuilder build
docker build -t testbridge:latest .
docker tag testbridge:latest localhost:5000/testbridge:latest
docker push localhost:5000/testbridge:latest
