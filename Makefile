dep:
	go mod tidy

build:
	CGO_ENABLED=0 go build -a -ldflags '-extldflags "-static"' -o volume-nfs-provisioner .

image:	
	docker build . -f Dockerfile.provisioner -t daocloud.io/piraeus/volume-nfs-provisioner

upload:
	docker push daocloud.io/piraeus/volume-nfs-provisioner

all: dep build image upload

clean: 
	rm -vf volume-nfs-provisioner