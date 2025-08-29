# Assignment Submission: IaC & Container Orchestration Solutions

## 1. Overview

This repository serves as an assignment submission, containing two primary solutions focused on **Infrastructure as Code (IaC)** and **Container Orchestration**. Each solution addresses specific technical challenges and demonstrates adherence to industry best practices in security, scalability, and code structure.

## 2. Repository Structure

This repository is organized into distinct folders, with each folder representing a complete solution. To ensure clarity, maintainability, and reusability, **each solution folder contains its own dedicated `README.md`**. This approach provides comprehensive documentation, including:

* **Problem Statement:** A clear description of the challenge being addressed.

* **Requirements:** Detailed criteria that the solution fulfills.

* **Assumptions:** Any underlying assumptions made during the design and implementation.

* **Approach:** An explanation of the chosen methodology and design decisions.

* **Steps to Deploy/Test:** Instructions for setting up, deploying, and verifying the solution.

## 3. Solutions

### a. IaC Solution: Static Content CDN Infrastructure

**Folder:** `1 IAC/`

This solution focuses on deploying a robust and scalable static content delivery infrastructure using Infrastructure as Code. It leverages **AWS S3** for secure object storage and **AWS CloudFront** for global content distribution, implemented via **Terraform**. The setup caters to **development, staging, and production** environments, ensuring environmental isolation and least privilege access.

**Key Features:**

* Secure S3 buckets with versioning and server-side encryption.

* CloudFront distributions with Origin Access Control (OAC).

* Path-based routing for different content types (`/auth`, `/info`, `/customers`).

* Modular Terraform code for reusability.

👉 **For detailed information, deployment steps, and architectural diagrams, please refer to the `README.md` located within the `1 IAC/` directory.**

### b. Container Orchestration Solution

**Folder:** `2 Container Orchestration/` *(To be implemented)*

This section will contain a solution demonstrating effective container orchestration practices. This could involve deploying containerized applications using tools like Kubernetes, Amazon ECS, or similar platforms, focusing on aspects such as scalability, high availability, and service discovery.

👉 **Please refer to the `README.md` within the `2 Container Orchestration/` directory for specifics on this solution once it is available.**

## 4. General Instructions

To properly understand and interact with each solution, navigate into its respective folder and consult the `README.md` file located there. Each `README.md` is self-contained and provides all the necessary information to get started.