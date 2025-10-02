# Useful Links and Resources

This document contains a curated list of useful links and resources for mastering Kubernetes, along with descriptions of what each resource covers.

## Comprehensive Learning Series

### Kubernetes: From Zero to Production Ready

- **[Kubernetes Learning Series - Techiescamp](https://blog.techiescamp.com/kubernetes-learning-series/)**
  - **Description**: Complete "Kubernetes: From Zero to Production Ready" learning series covering all aspects of Kubernetes from fundamentals to production deployment
  - **What it covers**:
    - **Kubernetes Core Basics**: Fundamental concepts and architecture
    - **Beyond YAML**: Core IT concepts essential for Kubernetes
    - **Kubernetes Architecture**: Overall system design and components
    - **API Server**: Central hub and Kubernetes API exposure
    - **etcd**: Kubernetes distributed key-value store
    - **Scheduler**: Pod placement and resource allocation strategies
    - **Custom Schedulers**: Building and implementing custom scheduling logic
    - **Bin Packing Strategies**: Resource optimization techniques
    - **Controller Manager**: Control loop implementations
    - **Cloud Controller Manager (CCM)**: Cloud provider integrations
    - **Kubelet**: Node agent deep dive
  - **Learning approach**: Daily exploration of new concepts with detailed explanations, reference links, real-world use cases, and case studies
  - **Audience**: Both experienced Kubernetes professionals seeking knowledge refresh and newcomers building expertise from scratch
  - **Goal**: Skills and insights needed to take Kubernetes deployments from zero to fully production-ready

## Hands-on Tutorials and Labs

### Container Fundamentals

- **[How Container Filesystem Works: Building a Docker-like Container From Scratch - iximiuz Labs](https://labs.iximiuz.com/tutorials/container-filesystem-from-scratch)**
  - **Description**: Interactive hands-on tutorial that teaches container filesystem isolation by building a Docker-like container using only stock Linux tools
  - **What it covers**:
    - **Mount Namespace**: Understanding the bedrock of container isolation and mount table separation
    - **Mount Propagation**: Critical concepts for understanding how mounts behave across namespaces
    - **Container Rootfs Preparation**: Step-by-step process of creating isolated container environments
    - **Linux Tools**: Practical use of `unshare`, `mount`, `pivot_root`, and other native Linux utilities
    - **Namespace Integration**: How PID, cgroup, UTS, and network namespaces complement mount namespaces
    - **Filesystem Hierarchy**: Creating proper `/proc`, `/sys`, `/dev`, and other essential directories
    - **Bind Mounts and Volumes**: Understanding Docker-style file sharing between host and container
    - **Security Considerations**: Masking sensitive paths and proper isolation techniques
  - **Learning approach**: Hands-on exercises with real terminal commands and immediate feedback
  - **Prerequisites**: Basic Docker familiarity, Linux knowledge, filesystem fundamentals
  - **Outcome**: Comprehensive mental model of container internals and ability to create containers from scratch

## Additional Resources

<!-- Add more useful links here as you discover them -->

---

*This document is regularly updated with new resources. Feel free to contribute by adding more useful links and descriptions.*
