# Lab 03: Cloud Controller Manager

**Difficulty Level:** Expert

## Overview

In this lab, you will deploy a Cloud Controller Manager (CCM) for your chosen cloud provider. This advanced exercise demonstrates how Kubernetes integrates with cloud providers to manage resources like load balancers, node lifecycle, and cloud-specific features.

## Learning Objectives

- Understand Cloud Controller Manager architecture
- Configure external cloud provider mode
- Set up mock metadata servers for testing
- Integrate Kubernetes with cloud provider APIs
- Manage cloud resources through Kubernetes

## Prerequisites

- Completed Lab 01 and Lab 02 (recommended)
- Working Kubernetes control plane
- Cloud provider account (AWS, GCP, Azure, or DigitalOcean)
- Understanding of cloud provider APIs
- Familiarity with service accounts and authentication

## Task Description

### Step 1: Deploy Control Plane

Deploy a control plane with external cloud provider configuration:

- Set `--cloud-provider=external` in kube-apiserver
- Set `--cloud-provider=external` in kube-controller-manager
- Disable internal cloud provider logic

### Step 2: Configure Metadata Server

Set up local metadata server emulation:

1. Configure 169.254.169.254/32 to localhost:

   ```bash
   sudo ip addr add 169.254.169.254/32 dev lo
   ```

2. Deploy mock metadata server based on your provider

### Step 3: Create Service Account

1. Create Kubernetes service account for CCM
2. Configure cloud provider credentials
3. Create `cloud.conf` configuration file
4. Create `sa.json` service account credentials (for GCP) or equivalent

### Step 4: Deploy Mock Metadata Server

Choose your provider:

**For AWS:**

```bash
# Use amazon-ec2-metadata-mock
docker run -d \
  --name metadata-mock \
  -p 1338:1338 \
  amazon/amazon-ec2-metadata-mock:latest
```

**For GCP:**

```bash
# Use gce_metadata_server
# See: https://github.com/salrashid123/gce_metadata_server
```

### Step 5: Run Cloud Controller Manager

Deploy the CCM for your chosen provider with proper configuration:

- AWS: aws-cloud-controller-manager
- GCP: gcp-cloud-controller-manager
- Azure: azure-cloud-controller-manager
- DigitalOcean: digitalocean-cloud-controller-manager

### Step 6: Register Node

Register your node with the cloud provider:

- Add cloud provider-specific labels
- Verify node shows cloud provider information
- Check node annotations

### Step 7: Deploy Application

Deploy an arbitrary application (e.g., nginx):

```bash
kubectl create deployment nginx --image=nginx --replicas=3
```

### Step 8: Create Load Balancer

Create a LoadBalancer service and obtain a real IP address:

```bash
kubectl expose deployment nginx --type=LoadBalancer --port=80
```

Wait for the EXTERNAL-IP to be assigned by the cloud provider.

## Directory Structure

```text
lab-03-cloud-controller-manager/
├── README.md                        # This file
├── manifests/
│   ├── control-plane/
│   │   ├── kube-apiserver.yaml     # With external cloud provider
│   │   └── kube-controller-manager.yaml
│   ├── ccm/
│   │   ├── aws-ccm.yaml
│   │   ├── gcp-ccm.yaml
│   │   ├── azure-ccm.yaml
│   │   └── digitalocean-ccm.yaml
│   ├── metadata-mock/
│   │   ├── aws-metadata-mock.yaml
│   │   └── gcp-metadata-mock.yaml
│   ├── nginx-deployment.yaml
│   └── nginx-loadbalancer.yaml
├── configs/
│   ├── cloud.conf.example
│   ├── sa.json.example
│   └── ccm-rbac.yaml
├── scripts/
│   ├── setup-metadata-route.sh
│   ├── deploy-ccm.sh
│   └── cleanup.sh
└── solutions/
    └── SOLUTION.md
```

## Provider-Specific Notes

### AWS

- Requires IAM credentials or instance profile
- Use amazon-ec2-metadata-mock for local testing
- Configure AWS credentials in cloud.conf
- Required IAM permissions: EC2, ELB, Route53

### GCP

- Requires service account JSON key
- Use gce_metadata_server for local testing
- Configure sa.json with service account credentials
- Required GCP APIs: Compute Engine, Cloud Load Balancing

### Azure

- Requires Azure credentials
- Configure azure.json with subscription details
- Required permissions: Network, Compute, Load Balancer

### DigitalOcean

- Requires API token
- Simpler setup for learning
- Configure token in secret

## Success Criteria

- [ ] Control plane running with external cloud provider mode
- [ ] Metadata server responding on 169.254.169.254
- [ ] Service account and credentials configured
- [ ] Mock metadata server deployed and running
- [ ] Cloud Controller Manager running without errors
- [ ] Node registered with cloud provider information
- [ ] Application deployment successful
- [ ] LoadBalancer service created
- [ ] External IP address assigned
- [ ] Application accessible via external IP
- [ ] Cloud resources cleaned up after lab

## Important Notes

### Cost Management

⚠️ **WARNING**: This lab creates real cloud resources that may incur costs!

- Load balancers can be expensive
- Remember to clean up all resources after completion
- Use the provided cleanup script
- Verify resource deletion in cloud console

### Cleanup Commands

```bash
# Delete Kubernetes resources
kubectl delete svc nginx
kubectl delete deployment nginx

# Run cleanup script
./scripts/cleanup.sh

# Verify in cloud console
# AWS: Check EC2, ELB
# GCP: Check Compute Engine, Load Balancing
# Azure: Check Virtual Machines, Load Balancers
```

### Security Considerations

- Never commit cloud credentials to version control
- Use secrets management for production
- Restrict service account permissions
- Monitor cloud resource creation

## Testing Without Cloud Provider

If you don't want to use a real cloud provider, you can:

1. Use mock metadata server only
2. Deploy CCM in dry-run mode
3. Use MetalLB for load balancer simulation
4. Focus on understanding the architecture

## Resources

### Documentation

- [Cloud Controller Manager](https://kubernetes.io/docs/concepts/architecture/cloud-controller/)
- [Running CCM](https://kubernetes.io/docs/tasks/administer-cluster/running-cloud-controller/)

### Mock Metadata Servers

- [AWS EC2 Metadata Mock](https://github.com/aws/amazon-ec2-metadata-mock)
- [GCE Metadata Server](https://github.com/salrashid123/gce_metadata_server)

### Cloud Provider Implementations

- [AWS Cloud Provider](https://github.com/kubernetes/cloud-provider-aws)
- [GCP Cloud Provider](https://github.com/kubernetes/cloud-provider-gcp)
- [Azure Cloud Provider](https://github.com/kubernetes-sigs/cloud-provider-azure)
- [DigitalOcean Cloud Controller Manager](https://github.com/digitalocean/digitalocean-cloud-controller-manager)

## Troubleshooting

Common issues:

- **CCM cannot reach metadata server**: Check routing to 169.254.169.254
- **Authentication failures**: Verify cloud credentials and service account
- **Load balancer not created**: Check CCM logs and cloud provider permissions
- **Node not registered**: Verify cloud provider labels and node configuration

## Challenge Questions

1. How does the CCM interact with the Kubernetes API server?
2. What happens if the CCM crashes while creating a load balancer?
3. How does node lifecycle management work with CCM?
4. What are the advantages of external cloud provider mode?
5. How would you troubleshoot load balancer creation issues?

## Optional: Register Node in Cluster

While not required, you can register your node in the cluster:

1. Configure kubelet with cloud provider
2. Add cloud provider-specific node labels
3. Start kubelet to join the cluster
4. Verify node registration with cloud metadata

## Advanced Extensions

Once you complete the basic lab, try:

1. **Multi-zone deployment**: Deploy across multiple availability zones
2. **Custom node labels**: Add custom cloud provider labels
3. **Service annotations**: Use cloud provider-specific annotations
4. **Monitoring**: Set up CCM metrics and monitoring
5. **Multiple load balancers**: Create different types of load balancers

## Completion

Congratulations! You've completed all three labs. You now have hands-on experience with:

- Kubernetes control plane internals
- Performance profiling and optimization
- Cloud provider integration

Continue exploring Kubernetes by diving deeper into each area or contributing improvements to these labs!

