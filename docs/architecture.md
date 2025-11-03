# Architecture Documentation

This document provides detailed architecture diagrams and explanations for the Open WebUI deployment.

## High-Level Architecture

```mermaid
graph TB
    subgraph "User Access"
        User[User Browser]
    end
    
    subgraph "AWS Cloud"
        subgraph "Public Subnets - Multi-AZ"
            ALB[Application Load Balancer<br/>HTTPS:443]
            NAT1[NAT Gateway AZ1]
            NAT2[NAT Gateway AZ2]
        end
        
        subgraph "Private Subnets - Multi-AZ"
            ECS1[ECS Task AZ1<br/>Open WebUI Container]
            ECS2[ECS Task AZ2<br/>Open WebUI Container]
            EFS1[EFS Mount Target AZ1]
            EFS2[EFS Mount Target AZ2]
        end
        
        subgraph "Storage"
            EFS[EFS File System<br/>Encrypted]
        end
        
        subgraph "Authentication"
            Cognito[Cognito User Pool<br/>OAuth2/OIDC]
        end
        
        subgraph "Secrets"
            Secrets[Secrets Manager<br/>Client Secret, Keys]
        end
        
        subgraph "Monitoring"
            CW[CloudWatch<br/>Logs, Metrics, Alarms]
        end
    end
    
    User -->|HTTPS| ALB
    ALB -->|HTTP:8080| ECS1
    ALB -->|HTTP:8080| ECS2
    ECS1 -->|NFS| EFS1
    ECS2 -->|NFS| EFS2
    EFS1 --> EFS
    EFS2 --> EFS
    ECS1 -.->|Auth| Cognito
    ECS2 -.->|Auth| Cognito
    User -.->|Login| Cognito
    ECS1 -.->|Read| Secrets
    ECS2 -.->|Read| Secrets
    ECS1 -->|Logs| CW
    ECS2 -->|Logs| CW
    ECS1 -->|Internet| NAT1
    ECS2 -->|Internet| NAT2
    
    style User fill:#e1f5ff
    style ALB fill:#ff9900
    style ECS1 fill:#ff9900
    style ECS2 fill:#ff9900
    style EFS fill:#7aa116
    style Cognito fill:#dd344c
    style Secrets fill:#dd344c
    style CW fill:#ff9900
```

## Network Architecture

```mermaid
graph TB
    subgraph "VPC - 10.0.0.0/16"
        subgraph "Availability Zone 1"
            PubSub1[Public Subnet<br/>10.0.1.0/24]
            PrivSub1[Private Subnet<br/>10.0.11.0/24]
            NAT1[NAT Gateway]
            ECS1[ECS Tasks]
            EFS1[EFS Mount]
        end
        
        subgraph "Availability Zone 2"
            PubSub2[Public Subnet<br/>10.0.2.0/24]
            PrivSub2[Private Subnet<br/>10.0.12.0/24]
            NAT2[NAT Gateway]
            ECS2[ECS Tasks]
            EFS2[EFS Mount]
        end
        
        IGW[Internet Gateway]
        ALB[Application Load Balancer]
    end
    
    Internet[Internet] --> IGW
    IGW --> PubSub1
    IGW --> PubSub2
    PubSub1 --> NAT1
    PubSub2 --> NAT2
    PubSub1 --> ALB
    PubSub2 --> ALB
    ALB --> PrivSub1
    ALB --> PrivSub2
    PrivSub1 --> ECS1
    PrivSub2 --> ECS2
    PrivSub1 --> EFS1
    PrivSub2 --> EFS2
    ECS1 -.->|Outbound| NAT1
    ECS2 -.->|Outbound| NAT2
    
    style Internet fill:#e1f5ff
    style IGW fill:#7aa116
    style NAT1 fill:#7aa116
    style NAT2 fill:#7aa116
    style ALB fill:#ff9900
    style ECS1 fill:#ff9900
    style ECS2 fill:#ff9900
```

## Security Groups Architecture

```mermaid
graph LR
    subgraph "Security Groups"
        ALBSG[ALB Security Group<br/>Ingress: 0.0.0.0/0:443,80]
        ECSSG[ECS Security Group<br/>Ingress: ALB:8080]
        EFSSG[EFS Security Group<br/>Ingress: ECS:2049]
    end
    
    Internet[Internet<br/>0.0.0.0/0] -->|HTTPS:443<br/>HTTP:80| ALBSG
    ALBSG -->|HTTP:8080| ECSSG
    ECSSG -->|NFS:2049| EFSSG
    ECSSG -.->|Outbound<br/>All Traffic| Internet
    
    style Internet fill:#e1f5ff
    style ALBSG fill:#dd344c
    style ECSSG fill:#dd344c
    style EFSSG fill:#dd344c
```

## Authentication Flow

```mermaid
sequenceDiagram
    participant User
    participant ALB
    participant OpenWebUI
    participant Cognito
    participant SecretsManager
    
    User->>ALB: 1. Access https://app.example.com
    ALB->>OpenWebUI: 2. Forward request
    OpenWebUI->>OpenWebUI: 3. Check session/token
    
    alt No valid session
        OpenWebUI->>User: 4. Redirect to Cognito
        User->>Cognito: 5. Login with credentials
        Cognito->>Cognito: 6. Validate credentials
        Cognito->>User: 7. Return authorization code
        User->>OpenWebUI: 8. Callback with auth code
        OpenWebUI->>SecretsManager: 9. Get client secret
        SecretsManager->>OpenWebUI: 10. Return secret
        OpenWebUI->>Cognito: 11. Exchange code for tokens
        Cognito->>OpenWebUI: 12. Return JWT tokens
        OpenWebUI->>OpenWebUI: 13. Create session
    end
    
    OpenWebUI->>User: 14. Serve application
    User->>OpenWebUI: 15. Subsequent requests with session
```

## Data Flow Architecture

```mermaid
graph TB
    subgraph "User Interaction"
        Browser[User Browser]
    end
    
    subgraph "Request Processing"
        ALB[Load Balancer<br/>SSL Termination]
        ECS[ECS Task<br/>Open WebUI]
    end
    
    subgraph "Data Storage"
        EFS[EFS<br/>Persistent Data]
        Memory[Container Memory<br/>Temporary Data]
    end
    
    subgraph "External Services"
        Cognito[Cognito<br/>User Auth]
        LLM[LLM Backend<br/>Ollama/OpenAI]
    end
    
    Browser -->|1. HTTPS Request| ALB
    ALB -->|2. HTTP Request| ECS
    ECS -->|3. Auth Check| Cognito
    ECS -->|4. Read/Write Data| EFS
    ECS -->|5. Cache in Memory| Memory
    ECS -->|6. LLM Requests| LLM
    LLM -->|7. LLM Response| ECS
    ECS -->|8. HTTP Response| ALB
    ALB -->|9. HTTPS Response| Browser
    
    style Browser fill:#e1f5ff
    style ALB fill:#ff9900
    style ECS fill:#ff9900
    style EFS fill:#7aa116
    style Cognito fill:#dd344c
    style LLM fill:#146eb4
```

## Deployment Architecture

```mermaid
graph TB
    subgraph "CloudFormation Stacks"
        Main[Main Stack<br/>Orchestrator]
        
        Main --> Network[Network Stack<br/>VPC, Subnets, NAT]
        Main --> SG[Security Groups Stack<br/>ALB, ECS, EFS SGs]
        Main --> Cognito[Cognito Stack<br/>User Pool, Client]
        Main --> Storage[Storage Stack<br/>EFS, KMS]
        Main --> LB[Load Balancer Stack<br/>ALB, Target Group]
        Main --> Compute[Compute Stack<br/>ECS, Tasks, Service]
        Main --> Monitor[Monitoring Stack<br/>Logs, Alarms, Dashboard]
    end
    
    subgraph "Dependencies"
        Network -.-> SG
        Network -.-> Storage
        Network -.-> LB
        SG -.-> Storage
        SG -.-> LB
        SG -.-> Compute
        Storage -.-> Compute
        LB -.-> Compute
        LB -.-> Cognito
        Cognito -.-> Compute
        Compute -.-> Monitor
        LB -.-> Monitor
    end
    
    style Main fill:#146eb4
    style Network fill:#7aa116
    style SG fill:#dd344c
    style Cognito fill:#dd344c
    style Storage fill:#7aa116
    style LB fill:#ff9900
    style Compute fill:#ff9900
    style Monitor fill:#ff9900
```

## Monitoring Architecture

```mermaid
graph TB
    subgraph "Application Layer"
        ECS[ECS Tasks]
        ALB[Load Balancer]
    end
    
    subgraph "CloudWatch"
        Logs[Log Groups<br/>Application & Error Logs]
        Metrics[Metrics<br/>CPU, Memory, Response Time]
        Alarms[Alarms<br/>Thresholds & Alerts]
        Dashboard[Dashboard<br/>Visualization]
    end
    
    subgraph "Notifications"
        SNS[SNS Topic]
        Email[Email Alerts]
    end
    
    ECS -->|Container Logs| Logs
    ALB -->|Access Logs| Logs
    ECS -->|Metrics| Metrics
    ALB -->|Metrics| Metrics
    Metrics --> Dashboard
    Logs -->|Metric Filters| Metrics
    Metrics -->|Threshold Breach| Alarms
    Alarms --> SNS
    SNS --> Email
    
    style ECS fill:#ff9900
    style ALB fill:#ff9900
    style Logs fill:#ff9900
    style Metrics fill:#ff9900
    style Alarms fill:#dd344c
    style Dashboard fill:#146eb4
    style SNS fill:#dd344c
    style Email fill:#e1f5ff
```

## Auto-Scaling Architecture

```mermaid
graph TB
    subgraph "ECS Service"
        Task1[Task 1]
        Task2[Task 2]
        Task3[Task 3]
        TaskN[Task N]
    end
    
    subgraph "Auto Scaling"
        Target[Scaling Target<br/>Min: 1, Max: 4]
        PolicyCPU[CPU Policy<br/>Target: 70%]
        PolicyMem[Memory Policy<br/>Target: 80%]
    end
    
    subgraph "CloudWatch Metrics"
        CPU[CPU Utilization]
        Memory[Memory Utilization]
    end
    
    Task1 --> CPU
    Task2 --> CPU
    Task3 --> CPU
    TaskN --> CPU
    Task1 --> Memory
    Task2 --> Memory
    Task3 --> Memory
    TaskN --> Memory
    
    CPU --> PolicyCPU
    Memory --> PolicyMem
    PolicyCPU --> Target
    PolicyMem --> Target
    Target -.->|Scale Out| TaskN
    Target -.->|Scale In| Task3
    
    style Task1 fill:#ff9900
    style Task2 fill:#ff9900
    style Task3 fill:#7aa116
    style TaskN fill:#7aa116
    style Target fill:#146eb4
    style PolicyCPU fill:#146eb4
    style PolicyMem fill:#146eb4
```

## Disaster Recovery Architecture

```mermaid
graph TB
    subgraph "Primary Region"
        VPC1[VPC]
        ECS1[ECS Service]
        EFS1[EFS<br/>Automatic Backups]
        Cognito1[Cognito User Pool]
    end
    
    subgraph "Backup & Recovery"
        Backup[AWS Backup<br/>35-day retention]
        Secrets[Secrets Manager<br/>Replicated]
        CFN[CloudFormation<br/>Infrastructure as Code]
    end
    
    subgraph "Secondary Region (Optional)"
        VPC2[VPC]
        ECS2[ECS Service]
        EFS2[EFS]
        Cognito2[Cognito User Pool]
    end
    
    EFS1 -->|Daily Backup| Backup
    Backup -.->|Restore| EFS1
    Backup -.->|Cross-Region Copy| EFS2
    Secrets -.->|Replicate| Secrets
    CFN -.->|Deploy| VPC1
    CFN -.->|Deploy| VPC2
    
    style EFS1 fill:#7aa116
    style Backup fill:#146eb4
    style CFN fill:#146eb4
    style VPC2 fill:#cccccc
    style ECS2 fill:#cccccc
    style EFS2 fill:#cccccc
    style Cognito2 fill:#cccccc
```

## Key Architecture Decisions

### Multi-AZ Deployment
- **Why**: High availability and fault tolerance
- **Components**: ALB, NAT Gateways, ECS tasks, EFS mount targets
- **Benefit**: Automatic failover if one AZ fails

### Private Subnets for Compute
- **Why**: Security best practice
- **Components**: ECS tasks, EFS mount targets
- **Benefit**: No direct internet access, reduced attack surface

### EFS for Persistent Storage
- **Why**: Shared file system across multiple containers
- **Components**: User data, models, chat history
- **Benefit**: Data persists across container restarts and scaling

### Fargate Launch Type
- **Why**: Serverless, no EC2 management
- **Components**: ECS tasks
- **Benefit**: Automatic scaling, pay-per-use, no server maintenance

### Application Load Balancer
- **Why**: Layer 7 routing, SSL termination, health checks
- **Components**: HTTPS listener, target group
- **Benefit**: Automatic SSL/TLS, path-based routing, WebSocket support

### Cognito for Authentication
- **Why**: Managed authentication service
- **Components**: User pool, app client, hosted UI
- **Benefit**: OAuth2/OIDC support, MFA, user management

### Secrets Manager
- **Why**: Secure credential storage
- **Components**: Client secret, session keys
- **Benefit**: Automatic rotation, encryption, audit logging

### CloudWatch for Monitoring
- **Why**: Integrated AWS monitoring
- **Components**: Logs, metrics, alarms, dashboards
- **Benefit**: Real-time visibility, alerting, troubleshooting

## Scalability Considerations

### Horizontal Scaling
- ECS auto-scaling based on CPU/memory
- ALB distributes traffic across tasks
- EFS scales automatically with usage

### Vertical Scaling
- Adjustable task CPU and memory
- Configurable via CloudFormation parameters
- No downtime for scaling up

### Performance Optimization
- EFS provisioned throughput mode available
- ALB connection draining for graceful shutdowns
- CloudWatch Container Insights for detailed metrics

## Security Layers

1. **Network Security**: VPC, private subnets, security groups
2. **Transport Security**: HTTPS only, TLS 1.3
3. **Authentication**: Cognito OAuth2/OIDC
4. **Authorization**: Cognito groups (Admins, Users)
5. **Data Encryption**: EFS at rest (KMS), TLS in transit
6. **Secrets Management**: Secrets Manager with encryption
7. **Monitoring**: CloudWatch logs, VPC Flow Logs, CloudTrail
8. **IAM**: Least-privilege roles for ECS tasks

## Cost Optimization Strategies

1. **EFS Lifecycle Policies**: Move infrequently accessed data to IA storage
2. **Auto-Scaling**: Scale down during low usage
3. **Fargate Spot**: Use Spot pricing for non-production (up to 70% savings)
4. **Single NAT Gateway**: Reduce to one NAT for dev environments
5. **Log Retention**: Shorter retention for non-critical logs
6. **Reserved Capacity**: Consider Savings Plans for predictable workloads

## References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [VPC Design Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-design-best-practices.html)
