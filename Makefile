dep:
	http_proxy=$(PROXY) https_proxy=$(PROXY) go mod tidy

build:
	CGO_ENABLED=0 go build -v -a -ldflags '-extldflags "-static"' -o volume-nfs-provisioner .

image:	
	docker build . --build-arg http_proxy=$(PROXY)  --build-arg https_proxy=$(PROXY) -f Dockerfile.provisioner -t daocloud.io/piraeus/volume-nfs-provisioner

upload:
	docker push daocloud.io/piraeus/volume-nfs-provisioner

all: dep build image upload

clean: 
	rm -vf volume-nfs-provisioner

test:
	kubectl delete -f provisioner.yaml || true
	kubectl apply -f provisioner.yaml