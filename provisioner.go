package main

import (
	// "errors"
	"flag"
	"os/exec"
	"strconv"
	"strings"
	"bufio"
	"bytes"
	// "path"
	"syscall"
	
	"sigs.k8s.io/sig-storage-lib-external-provisioner/controller"

	"k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/klog"
)

func BytesToString(data []byte) string {
	return string(data[:])
}

type volumeNfsProvisioner struct {
}

// NewVolumeNfsProvisioner creates a new provisioner
func NewVolumeNfsProvisioner() controller.Provisioner {
	return &volumeNfsProvisioner{}
}

func RunExtCmd(name string, args ...string ) string {
	cmd := exec.Command(name, args...)
	stderr, err :=cmd.StderrPipe()
	if err != nil {
		klog.Info(err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		klog.Info(err)
	}
	if err := cmd.Start(); err != nil {
		klog.Info(err)
	}
	sc := bufio.NewScanner(stderr)
	for sc.Scan() {
		klog.Info(sc.Text())
	}
	buf := new(bytes.Buffer)
	buf.ReadFrom(stdout)
	output := buf.String()
	return output
}

var _ controller.Provisioner = &volumeNfsProvisioner{}

// Provision creates a storage asset and returns a PV object representing it.
func (p *volumeNfsProvisioner) Provision(options controller.ProvisionOptions) (*v1.PersistentVolume, error) {

	nfsPvcNs := options.PVC.Namespace
	nfsPvcName := options.PVC.Name
	nfsPvName	:= options.PVName
	nfsStsName	:= nfsPvName
	nfsSvcName	:= nfsStsName

	dataScName := options.StorageClass.Parameters[ "dataBackendStorageClass" ]
	klog.Infof( "Data backend SC is \"%s\"", dataScName )

	dataPvcName := strings.Replace(nfsPvName, "pvc-", "data-", 1) + "-0"

	// create Data PVC
	capacity := options.PVC.Spec.Resources.Requests[v1.ResourceName(v1.ResourceStorage)]
	size := strconv.FormatInt( capacity.Value(), 10 )
	klog.Infof( "Data backend PVC size is \"%s\"", size )

	dataPvcUid := RunExtCmd( "create-data-pvc.sh", dataPvcName, dataScName, size )
	klog.Infof("Data backend PVC uid is \"%s\"", dataPvcUid )

	dataPvName := "pvc-" + dataPvcUid

	// create NFS SVC
	nfsIp := RunExtCmd( "create-nfs-svc.sh", nfsSvcName )
	klog.Infof("NFS export IP is \"%s\"", nfsIp )

	// create NFS StatefulSet to bridge NFS SVC with Data PVC
	klog.Infof("Creating NFS export pod by statefulset: \"%s\"", nfsStsName )
	RunExtCmd( "create-nfs-sts.sh", nfsPvcNs, nfsStsName, nfsPvcName, nfsPvName, dataPvcName, dataPvName )

	// if options.PVC.Spec.AccessModes[0] == "ReadWriteOnce" {
	// 	RunExtCmd( "rebound-data-pv.sh", nfsPvcNs, nfsPvcName, nfsStsName, dataPvcName, dataPvName )
	// } 

	pv := &v1.PersistentVolume{
		ObjectMeta: metav1.ObjectMeta{
			Name: options.PVName,
		},
		Spec: v1.PersistentVolumeSpec{
			PersistentVolumeReclaimPolicy: *options.StorageClass.ReclaimPolicy,
			AccessModes:                   options.PVC.Spec.AccessModes,
			Capacity: v1.ResourceList{
				v1.ResourceName(v1.ResourceStorage): options.PVC.Spec.Resources.Requests[v1.ResourceName(v1.ResourceStorage)],
			},
			PersistentVolumeSource: v1.PersistentVolumeSource{
				NFS: &v1.NFSVolumeSource{
					Server:   nfsIp,
					Path:     "/var/lib/nfs/volume/" + dataPvName,
					ReadOnly: false,
				},
			},
		},
	}
	return pv, nil
}

// Delete removes the storage asset that was created by Provision represented
// by the given PV.
func (p *volumeNfsProvisioner) Delete(volume *v1.PersistentVolume) error {
	nfsPvName := volume.ObjectMeta.Name
	RunExtCmd( "delete-data-pvc.sh", nfsPvName )
	return nil
}

func main() {
	syscall.Umask(0)

	// Provisoner name
	provisionerName := flag.String("name", "nfs.volume.io", "a string")

	flag.Parse()
	flag.Set("logtostderr", "true")

	// Create an InClusterConfig and use it to create a client for the controller
	// to use to communicate with Kubernetes
	config, err := rest.InClusterConfig()
	if err != nil {
		klog.Fatalf("Failed to create config: %v", err)
	}
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		klog.Fatalf("Failed to create client: %v", err)
	}

	// The controller needs to know what the server version is because out-of-tree
	// provisioners aren't officially supported until 1.5
	serverVersion, err := clientset.Discovery().ServerVersion()
	if err != nil {
		klog.Fatalf("Error getting server version: %v", err)
	}

	// Create the provisioner: it implements the Provisioner interface expected by
	// the controller
	volumeNfsProvisioner := NewVolumeNfsProvisioner()

	// Start the provision controller
	// PVs
	pc := controller.NewProvisionController(clientset, *provisionerName, volumeNfsProvisioner, serverVersion.GitVersion)
	pc.Run(wait.NeverStop)
}