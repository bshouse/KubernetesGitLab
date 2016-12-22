#Prerequesites
Python 2.7
Google Cloud SDK v138.0.0 - https://cloud.google.com/sdk/

#References
#https://github.com/lwolf/kubernetes-gitlab
#http://blog.lwolf.org/post/how-to-easily-deploy-gitlab-on-kubernetes/

#Settings
#gcloud alpha billing accounts list
#gcloud config set compute/zone $ZONE
#ZONE=
BILLINGID=XXXXXX-XXXXXX-XXXXXX
PROJECT=XXXX
CLUSTER=XXX
GITLABHOST=XXXX
GITLABDOMAIN=XXXX

#Create a Project
#TODO check if project already exists
gcloud alpha projects create $PROJECT
gcloud projects describe $PROJECT
gcloud config set project $PROJECT

#Enable Billing
gcloud alpha billing accounts projects link $PROJECT --account-id=$BILLINGID

#Login (TODO: Replace with non-interactive login service account)
gcloud auth application-default login

#Wait for Continer Engine to get ready


#Create persistant disk (TODO: update yml)
#gcloud compute disks create PD1 --zone "us-west1-b" --size=200GB

#Create a Container Cluster
gcloud container --project $PROJECT clusters create $CLUSTER --zone "us-west1-b" --machine-type "n1-standard-2" --image-type "GCI" --disk-size "100" --scopes "https://www.googleapis.com/auth/compute","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "1" --network "default" --enable-cloud-logging --no-enable-cloud-monitoring --no-async
gcloud container --project $PROJECT clusters describe $CLUSTER

#Fetch Cluster Credentials
gcloud container clusters get-credentials $CLUSTER --zone us-west1-b --project $PROJECT

#Start the Dashboard proxy
#kubectl proxy

#Set Kubernetes context
kubectl config set-context `kubectl get nodes | tail -1 | awk -F' ' '{print $1}'`

#Create global namspace and deploy PostgreSQL & Redis
kubectl create -f gitlab-ns.yml
kubectl create -f gitlab/redis-svc.yml
kubectl create -f gitlab/redis-deployment.yml
kubectl create -f gitlab/postgresql-svc.yml
kubectl create -f gitlab/postgresql-deployment.yml

#Wait for ready
while [ `kubectl get pods --namespace=gitlab | grep "1/1" | wc -l`  != 2 ]; do   sleep 10; done

#Deploy gitlab Service
kubectl create -f gitlab/gitlab-svc.yml

#Wait for GitLab public IP
GITLABIP=""
while [ "$GITLABIP" == "" ]; do sleep 10; GITLABIP=`kubectl describe svc gitlab --namespace=gitlab | grep "LoadBalancer Ingress:" | awk -F' ' '{print $3}'`; done

#Configure GitLab IP
sed 's/          value: git.example.com/          value: '$GITLABIP'/' gitlab/gitlab-deployment.yml | sed 's/          value: "ssh-git.example.com"/          value: "'$GITLABIP'"/' > gitlab-deployment.yml

#Deploy gitlab
kubectl create -f gitlab-deployment.yml
rm gitlab-deployment.yml
while [ `kubectl get pods --namespace=gitlab | grep "1/1" | wc -l`  != 3 ]; do   sleep 10; done


#DNS-Domain (TODO: Test for existance and skip as necessary)
#gcloud dns managed-zones create gitlabdns --dns-name $GITLABDOMAIN. --description=$PROJECT-DNS
#DNS-Host (TODO: Test for existance)
#gcloud dns record-sets transaction start -z=gitlabdns
#gcloud dns record-sets transaction add -z=gitlabdns --name="$GITLABHOST.$GITLABDOMAIN." --type=A --ttl=300 "$GITLABIP"
#gcloud dns record-sets transaction describe -z=gitlabdns
#gcloud dns record-sets transaction execute -z=gitlabdns


#Ingress Filters
#kubectl create -f ingress/default-backend.yml
#kubectl create -f ingress/configmap.yml
#kubectl create -f ingress/nginx-ingress-lb.yml
#kubectl create -f ingress/gitlab-ingress.yml

#Deploy Minio cache server
kubectl create -f minio/minio-svc.yml
kubectl create -f minio/minio-deployment.yml
while [ `kubectl get pods --namespace=gitlab | grep "1/1" | wc -l`  != 4 ]; do   sleep 10; done

#Grab Access/Secret key from logfile
MINIOPOD=`kubectl get pods --namespace=gitlab | grep minio | awk -F' ' '{print $1}'`
ACCESSKEY=`kubectl logs $MINIOPOD  --namespace=gitlab | grep AccessKey: | awk -F ' ' '{print$2}'`
SECRETKEY=`kubectl logs $MINIOPOD  --namespace=gitlab | grep SecretKey: | awk -F ' ' '{print$2}'`

#TODO: Make sure ACCESSKEY and SERCRETKEY are not blank (my not be in log file when checked)

#Minio Working Dir
#kubectl exec -it $MINIOPOD --namespace=gitlab -- bash -c 'mkdir /export/runner'

#
#
#TODO: Automate with web scrape
echo Point your browser at: http://$GITLABIP/
echo Login 
echo Navigate to: Admin -> Overview -> Runners
echo Capture the registration token and paste here
read GITLABREG


#Register GitLab Runner (TODO: pipe answers in)
echo Starting GitLab Runner Registration
echo gitlab-ci: http://gitlab.gitlab/ci
echo token: $GITLABREG
echo gitlab-ci description: python-docker-runner
echo gitlab-ci tags: shared,specific
echo executor: docker
echo Docker image: python:3.5.1
kubectl run -it runner-registrator --image=gitlab/gitlab-runner:v1.5.2 --restart=Never -- register

#Clean up runner-registrator
kubectl delete pod runner-registrator

#Configure docker-runner
echo Back in the web broswer, refresh the Runners page
echo Click on the new Runner
echo Copy the token
read GITRUNTOK

#Populate YML with Token and Keys
sed 's/      token = ".*$/      token = "'$GITRUNTOK'"/' gitlab-runner/gitlab-runner-docker-configmap.yml | sed 's/        AccessKey = ".*$/        AccessKey = "'$ACCESSKEY'"/'  | sed 's/        SecretKey = ".*$/        SecretKey = "'$SECRETKEY'"/' > gitlab-runner-docker-configmap.yml

#Create GitLab Runner
kubectl create -f gitlab-runner-docker-configmap.yml
kubectl create -f gitlab-runner/gitlab-runner-docker-deployment.yml
rm gitlab-runner-docker-configmap.yml
while [ `kubectl get pods --namespace=gitlab | grep "1/1" | wc -l`  != 5 ]; do   sleep 10; done



#
#End of setup
#


#
#Misc Commands
#

#Check Service Port
#kubectl describe svc gitlab --namespace=gitlab

#List Kubernetes' nodes
#kubectl get nodes

#Check what is deployed
#kubectl get deployments

#Remove it
#kubectl delete -f gitlab-runner/gitlab-runner-docker-deployment.yml
#kubectl delete -f gitlab-runner/gitlab-runner-docker-configmap.yml
#kubectl delete -f minio/minio-deployment.yml
#kubectl delete -f minio/minio-svc.yml
#kubectl delete -f gitlab/gitlab-deployment.yml
#kubectl delete -f gitlab/gitlab-svc.yml
#kubectl delete -f gitlab/redis-deployment.yml
#kubectl delete -f gitlab/redis-svc.yml
#kubectl delete -f gitlab/postgresql-deployment.yml
#kubectl delete -f gitlab/postgresql-svc.yml
#gcloud compute disks delete PD1
#kubectl delete pods --all --namespace=gitlab
#gcloud container --project $PROJECT clusters delete $CLUSTER
#gcloud alpha projects delete $PROJECT