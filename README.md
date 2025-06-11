# DevOpsComplexDeploy
well-architected diagram for a serverless, event-driven application on AWS, deployed via Infrastructure as Code using FastAPI container inventory python

---------
Created to demonstrate my ability to launch and implemeant a good scalable , well architectured deployment based off this business scenario by Bryce Bacon.
Though it wasnt nessaisary to deploy an application for University unit. and I did not include this is my submission I wanted to show off my ability to beable pursue a career in DevOps/

Business Scenario (taken from Deakin Cloud Computing Unit )
![Screenshot 2025-06-11 at 4 22 54 PM](https://github.com/user-attachments/assets/85903352-b128-4eac-b612-81a97b106866)
===========

Intial Architecture Design
![codeDeploy](https://github.com/user-attachments/assets/07dd08ba-aa3e-4478-ad1f-481d06f5bc95)
===============

-----------------
Project Overview
===================
The diagram illustrates a highly available, scalable, and secure serverless web application architecture deployed in the ap-southeast-4 AWS region.

Key Architectural Concepts:
- Serverless Compute: The core business logic is handled by AWS Lambda functions. This includes a primary FastAPI application running as a container image and several smaller, event-driven Lambdas for background processing. This approach minimizes operational overhead and scales automatically.

- Event-Driven Architecture: The system is decoupled using Amazon EventBridge as a central event bus. The main application publishes events (e.g., "OrderCreated"), and downstream services (Order Processor, Inventory Updater, Notifications) react to these events independently. This improves resilience and scalability.

- Infrastructure as Code (IaC): The entire AWS infrastructure is defined and managed using Terraform. This ensures consistency, repeatability, and version control for the environment.
CI/CD Automation: A GitHub Actions pipeline automates the deployment process. It runs terraform plan to show proposed changes, requires a manual approval step for safety, and then terraform apply to provision the infrastructure.

-----------------------------------
High Availability & Scalability:
-----------------------------------

- The VPC is Multi-AZ.
- NAT Gateways are deployed in multiple Availability Zones (AZs) for resilient outbound internet access from private subnets.
- DynamoDB Global Tables provide a multi-region, fully managed database with fast local read/write performance and disaster recovery capabilities.
- CloudFront delivers content from a global network of edge locations, reducing latency for users worldwide.

-------------
Security:
-------------

- Defense in Depth: WAF protects against common web exploits at the edge. The application logic runs in a private subnet, inaccessible directly from the internet.
- Encryption: Encryption is enforced everywhere:
- In Transit: TLS encryption via ACM certificates on CloudFront and API Gateway.
- At Rest: AWS KMS Customer-Managed Keys (CMKs) are used to encrypt data in the S3 bucket and DynamoDB table.
