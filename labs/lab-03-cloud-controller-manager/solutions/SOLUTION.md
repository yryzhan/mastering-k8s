# Lab 03 Solution Guide

## Complete Step-by-Step Solution

This guide provides a detailed walkthrough for deploying a Cloud Controller Manager. We'll use AWS as the primary example, with notes for other providers.

## Prerequisites Checklist

- [ ] Working Kubernetes control plane
- [ ] Cloud provider account with appropriate permissions
- [ ] kubectl configured
- [ ] Cloud provider CLI installed (aws-cli, gcloud, az)
- [ ] Understanding of cloud provider APIs

## Part 1: Control Plane Configuration

### Step 1: Modify Control Plane Components

Add external cloud provider flags to your control plane components:

**kube-apiserver:**

```bash
--cloud-provider=external
```

**kube-controller-manager:**

```bash
--cloud-provider=external
--configure-cloud-routes=false  # CCM will handle this
```

**kubelet (on nodes):**

```bash
--cloud-provider=external
--provider-id=<cloud-provider-specific-id>
```

### Step 2: Restart Control Plane Components

If using static pods, edit the manifests and kubelet will restart them:

```bash
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
sudo vi /etc/kubernetes/manifests/kube-controller-manager.yaml
```

## Part 2: Metadata Server Setup

### Step 3: Configure Local Routing for Metadata Server

Set up 169.254.169.254 to point to localhost:

```bash
# Add IP to loopback interface
sudo ip addr add 169.254.169.254/32 dev lo

# Verify
ip addr show lo | grep 169.254

# Make persistent (add to /etc/network/interfaces or use systemd)
```

### Step 4: Deploy Mock Metadata Server

#### For AWS (EC2 Metadata Mock)

```bash
# Run as Docker container
docker run -d \
  --name ec2-metadata-mock \
  -p 1338:1338 \
  amazon/amazon-ec2-metadata-mock:latest \
  --mock-delay-sec 0 \
  --imdsv2 true

# Test it
curl http://169.254.169.254/latest/meta-data/instance-id

# Or deploy as Kubernetes pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ec2-metadata-mock
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: metadata-mock
    image: amazon/amazon-ec2-metadata-mock:latest
    args:
    - --mock-delay-sec=0
    - --imdsv2=true
    ports:
    - containerPort: 1338
      hostPort: 1338
EOF
```

#### For GCP

```bash
# Clone the metadata server
git clone https://github.com/salrashid123/gce_metadata_server
cd gce_metadata_server

# Build and run
go build -o metadata-server
./metadata-server -port 80 -projectId your-project-id

# Test
curl http://169.254.169.254/computeMetadata/v1/instance/id -H "Metadata-Flavor: Google"
```

## Part 3: Service Account and Credentials

### Step 5: Create Cloud Provider Credentials

#### For AWS

Create IAM policy with required permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeRouteTables",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:ModifyInstanceAttribute",
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    }
  ]
}
```

Create credentials secret:

```bash
kubectl create secret generic aws-cloud-provider \
  --from-literal=aws_access_key_id=YOUR_ACCESS_KEY \
  --from-literal=aws_secret_access_key=YOUR_SECRET_KEY \
  -n kube-system
```

#### For GCP

Create service account and download key:

```bash
# Create service account
gcloud iam service-accounts create ccm-sa \
  --display-name "Cloud Controller Manager"

# Grant permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member serviceAccount:ccm-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --role roles/compute.admin

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member serviceAccount:ccm-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --role roles/compute.loadBalancerAdmin

# Download key
gcloud iam service-accounts keys create sa.json \
  --iam-account ccm-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Create secret
kubectl create secret generic gcp-cloud-provider \
  --from-file=sa.json \
  -n kube-system
```

### Step 6: Create Cloud Configuration

#### For AWS (cloud.conf)

```ini
[Global]
Zone=us-east-1a
VPC=vpc-xxxxx
SubnetID=subnet-xxxxx
RouteTableID=rtb-xxxxx
KubernetesClusterTag=your-cluster-name
KubernetesClusterID=your-cluster-id
```

#### For GCP (cloud.conf)

```ini
[Global]
project-id = your-project-id
network-name = default
subnetwork-name = default
node-tags = kubernetes
node-instance-prefix = gke-
multizone = true
```

Create ConfigMap:

```bash
kubectl create configmap cloud-config \
  --from-file=cloud.conf \
  -n kube-system
```

## Part 4: Deploy Cloud Controller Manager

### Step 7: Deploy CCM

#### For AWS

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloud-controller-manager
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:cloud-controller-manager
rules:
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch", "update"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["nodes/status"]
  verbs: ["patch"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["services/status"]
  verbs: ["patch"]
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["create", "get", "list", "watch", "update"]
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch", "update"]
- apiGroups: [""]
  resources: ["endpoints"]
  verbs: ["create", "get", "list", "watch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:cloud-controller-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:cloud-controller-manager
subjects:
- kind: ServiceAccount
  name: cloud-controller-manager
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aws-cloud-controller-manager
  namespace: kube-system
  labels:
    app: aws-cloud-controller-manager
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aws-cloud-controller-manager
  template:
    metadata:
      labels:
        app: aws-cloud-controller-manager
    spec:
      serviceAccountName: cloud-controller-manager
      containers:
      - name: aws-cloud-controller-manager
        image: k8s.gcr.io/provider-aws/cloud-controller-manager:v1.25.0
        command:
        - /bin/aws-cloud-controller-manager
        - --v=2
        - --cloud-provider=aws
        - --cloud-config=/etc/cloud/cloud.conf
        - --configure-cloud-routes=true
        - --use-service-account-credentials=true
        volumeMounts:
        - name: cloud-config
          mountPath: /etc/cloud
          readOnly: true
        env:
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-cloud-provider
              key: aws_access_key_id
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: aws-cloud-provider
              key: aws_secret_access_key
      volumes:
      - name: cloud-config
        configMap:
          name: cloud-config
      tolerations:
      - key: node.cloudprovider.kubernetes.io/uninitialized
        value: "true"
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
EOF
```

### Step 8: Verify CCM is Running

```bash
# Check pod status
kubectl get pods -n kube-system -l app=aws-cloud-controller-manager

# Check logs
kubectl logs -n kube-system -l app=aws-cloud-controller-manager --tail=50

# Should see successful connection messages
```

## Part 5: Node Registration

### Step 9: Add Cloud Provider Labels to Node

```bash
# Label your node with cloud provider information
kubectl label node <node-name> \
  failure-domain.beta.kubernetes.io/region=us-east-1 \
  failure-domain.beta.kubernetes.io/zone=us-east-1a \
  kubernetes.io/hostname=<hostname>

# Add provider ID
kubectl patch node <node-name> -p '{"spec":{"providerID":"aws:///us-east-1a/i-xxxxx"}}'

# Verify
kubectl describe node <node-name> | grep -A 10 Labels
```

## Part 6: Deploy Application and Load Balancer

### Step 10: Deploy Sample Application

```bash
# Create nginx deployment
kubectl create deployment nginx --image=nginx:latest --replicas=3

# Verify pods are running
kubectl get pods
```

### Step 11: Create LoadBalancer Service

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb
  annotations:
    # AWS-specific annotations
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF
```

### Step 12: Wait for External IP

```bash
# Watch for external IP to be assigned
kubectl get svc nginx-lb -w

# Should eventually show:
# NAME       TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)        AGE
# nginx-lb   LoadBalancer   10.96.xxx.xxx   a1234567890abcdef1234567890abcdef-1234567890.us-east-1.elb.amazonaws.com  80:32xxx/TCP   2m
```

### Step 13: Test Load Balancer

```bash
# Get the external IP/hostname
LB_ADDRESS=$(kubectl get svc nginx-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test access
curl http://$LB_ADDRESS

# Should return nginx welcome page
```

## Part 7: Cleanup

### Step 14: Delete Resources

```bash
# Delete service first (this triggers LB deletion)
kubectl delete svc nginx-lb

# Wait for load balancer to be deleted (check cloud console)
# This is important to avoid charges!

# Delete deployment
kubectl delete deployment nginx

# Delete CCM
kubectl delete deployment -n kube-system aws-cloud-controller-manager

# Delete secrets and configmaps
kubectl delete secret -n kube-system aws-cloud-provider
kubectl delete configmap -n kube-system cloud-config

# Verify in cloud provider console that all resources are deleted
```

### Step 15: Verify Cloud Resources Deleted

**AWS:**

```bash
aws elb describe-load-balancers --region us-east-1
aws elbv2 describe-load-balancers --region us-east-1
# Should not show your test load balancer
```

**GCP:**

```bash
gcloud compute forwarding-rules list
gcloud compute target-pools list
# Should not show your test resources
```

## Troubleshooting

### Issue: CCM Pod CrashLoopBackOff

**Check logs:**

```bash
kubectl logs -n kube-system -l app=aws-cloud-controller-manager
```

**Common causes:**

- Invalid credentials
- Missing IAM permissions
- Cannot reach metadata server
- Invalid cloud configuration

**Solution:**

```bash
# Verify credentials
kubectl get secret -n kube-system aws-cloud-provider -o yaml

# Check IAM permissions in cloud console
# Verify metadata server is responding
curl http://169.254.169.254/latest/meta-data/
```

### Issue: Load Balancer Not Created

**Check service events:**

```bash
kubectl describe svc nginx-lb
```

**Common causes:**

- CCM not running
- Insufficient cloud permissions
- Invalid service annotations
- Network configuration issues

**Solution:**

```bash
# Check CCM logs
kubectl logs -n kube-system -l app=aws-cloud-controller-manager --tail=100

# Verify CCM has processed the service
kubectl get events --field-selector involvedObject.name=nginx-lb
```

### Issue: Cannot Access Metadata Server

**Test connectivity:**

```bash
curl -v http://169.254.169.254/latest/meta-data/

# Check routing
ip route get 169.254.169.254

# Check if mock server is running
docker ps | grep metadata
```

**Solution:**

```bash
# Restart mock metadata server
docker restart ec2-metadata-mock

# Verify routing
sudo ip addr add 169.254.169.254/32 dev lo
```

### Issue: Node Not Recognized by Cloud Provider

**Check node status:**

```bash
kubectl get node <node-name> -o yaml | grep -A 10 providerID
```

**Solution:**

```bash
# Add correct providerID
kubectl patch node <node-name> -p '{"spec":{"providerID":"<correct-provider-id>"}}'

# For AWS: aws:///us-east-1a/i-xxxxx
# For GCP: gce://project-id/zone/instance-name
```

## Advanced Topics

### Multi-Zone Setup

Deploy load balancers across multiple availability zones:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb-multizone
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-subnets: subnet-xxx,subnet-yyy,subnet-zzz
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - port: 80
```

### Internal Load Balancer

Create an internal load balancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-internal
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
    # Or for GCP:
    # cloud.google.com/load-balancer-type: "Internal"
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - port: 80
```

### Custom Load Balancer Configuration

```yaml
metadata:
  annotations:
    # AWS: Use NLB instead of CLB
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    
    # AWS: SSL certificate
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:..."
    
    # GCP: Session affinity
    cloud.google.com/neg: '{"ingress": true}'
```

## Key Learnings

1. **CCM Architecture**: Understanding how CCM integrates with Kubernetes and cloud providers
2. **Metadata Server**: Role of metadata server in cloud provider integration
3. **RBAC**: Proper permissions needed for CCM to function
4. **Load Balancer Lifecycle**: How Kubernetes manages cloud load balancers
5. **Cost Management**: Importance of cleaning up cloud resources

## Additional Resources

- [Cloud Controller Manager Concepts](https://kubernetes.io/docs/concepts/architecture/cloud-controller/)
- [AWS CCM GitHub](https://github.com/kubernetes/cloud-provider-aws)
- [GCP CCM GitHub](https://github.com/kubernetes/cloud-provider-gcp)
- [Cloud Provider Implementations](https://kubernetes.io/docs/tasks/administer-cluster/running-cloud-controller/)

## Congratulations!

You've successfully deployed a Cloud Controller Manager and integrated Kubernetes with a cloud provider. This is an advanced topic that demonstrates deep understanding of Kubernetes architecture and cloud integration.

