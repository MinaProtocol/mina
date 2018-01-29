set -e

img=testbridge:latest
project=$(gcloud config get-value project)

cd container
jbuilder build
docker build -t $img .
docker tag $img gcr.io/$project/$img
gcloud docker -- push gcr.io/$project/$img


