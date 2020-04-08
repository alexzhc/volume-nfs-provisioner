
provisioner:	
	docker build . --build-arg http_proxy=$(PROXY)  --build-arg https_proxy=$(PROXY) -f Dockerfile.provisioner -t daocloud.io/piraeus/volume-nfs-provisioner

exporter:
	docker build . --build-arg http_proxy=$(PROXY)  --build-arg https_proxy=$(PROXY) -f Dockerfile.exporter -t daocloud.io/piraeus/volume-nfs-exporter

upload:
	docker push daocloud.io/piraeus/volume-nfs-provisioner
	docker push daocloud.io/piraeus/volume-nfs-exporter

all: provisioner exporter upload test

test:
	kubectl delete -f pvc.yaml || true
	kubectl delete ns volume-nfs || true
	kubectl delete -f provisioner.yaml || true
	kubectl apply -f provisioner.yaml && \
	watch kubectl get -l app=volume-nfs-provisoner pod