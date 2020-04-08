package main

import (
	// "errors"
	"flag"
	"os/exec"
	"strconv"
	"strings"
	"bufio"
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

var _ controller.Provisioner = &volumeNfsProvisioner{}

// Provision creates a storage asset and returns a PV object representing it.
func (p *volumeNfsProvisioner) Provision(options controller.ProvisionOptions) (*v1.PersistentVolume, error) {

	nfsPvName	:= options.PVName
	nfsStsName	:= nfsPvName
	nfsSvcName	:= nfsStsName

	// create NFS SVC
	nfsIp, err := exec.Command( "create-nfs-svc.sh", nfsSvcName ).Output()
	if err != nil {
		klog.Info(err)
	}
	klog.Infof("NFS export IP is \"%s\"", nfsIp )

	// create Data PVC
	capacity := options.PVC.Spec.Resources.Requests[v1.ResourceName(v1.ResourceStorage)]
	size := strconv.FormatInt( capacity.Value(), 10 )
	klog.Infof( "Data backend PVC size is \"%s\"", size )

	dataScName := options.StorageClass.Parameters[ "dataBackendStorageClass" ]
	klog.Infof( "Data backend SC is \"%s\"", dataScName )

	dataPvcName := strings.Replace(nfsPvName, "pvc-", "data-", 1) + "-0"
	
	dataPvcUid, err := exec.Command( "create-data-pvc.sh", dataPvcName, dataScName, size ).Output()
	if err != nil {
		klog.Info(err)
	}
	klog.Infof("Data backend PVC uid is \"%s\"", dataPvcUid )

	// create NFS StatefulSet to bridge NFS SVC with Data PVC
	nfsNs := options.PVC.Namespace
	nfsPvcName := options.PVC.Name
	dataPvName := "pvc-" + BytesToString(dataPvcUid)

	klog.Infof("Creating NFS export pod by statefulset \"%s\":", nfsStsName )
	cmd := exec.Command( "create-nfs-sts.sh", nfsNs, nfsStsName, nfsPvcName, nfsPvName, dataPvcName, dataPvName )
	stderr, err :=cmd.StderrPipe()
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
					Server:   BytesToString(nfsIp),
					Path:     "/var/lib/nfs/volume/pvc-" + BytesToString(dataPvcUid),
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
	klog.Infof("PV is %s", nfsPvName )

	nfsStsName := nfsPvName
	nfsSvcName	:= nfsStsName
	dataPvcName := strings.Replace(nfsPvName, "pvc-", "data-", 1) + "-0"

	stdoutStderr, err := exec.Command( "kubectl", "-n", "volume-nfs", "delete", "sts", nfsStsName ).CombinedOutput()
	if err != nil {
		klog.Info(err)
	}
	klog.Infof("%s", stdoutStderr)

	stdoutStderr, err = exec.Command( "kubectl", "-n", "volume-nfs", "delete", "svc", nfsSvcName ).CombinedOutput()
	if err != nil {
		klog.Info(err)
	}
	klog.Infof("%s", stdoutStderr)

	stdoutStderr, err = exec.Command( "kubectl", "-n", "volume-nfs", "delete", "pvc", dataPvcName ).CombinedOutput()
	if err != nil {
		klog.Info(err)
	}
	klog.Infof("%s", stdoutStderr)

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