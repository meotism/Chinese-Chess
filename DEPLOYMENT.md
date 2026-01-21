# Deployment Guide

This document provides comprehensive deployment instructions for the Chinese Chess application.

## Table of Contents

1. [Render Deployment (Recommended)](#render-deployment-recommended)
2. [Backend Deployment](#backend-deployment)
3. [iOS Deployment (TestFlight)](#ios-deployment-testflight)
4. [Infrastructure Setup](#infrastructure-setup)
5. [Monitoring and Maintenance](#monitoring-and-maintenance)

---

## Render Deployment (Recommended)

Deploy the Chinese Chess backend to [Render](https://render.com) using a public Git repository.

### Prerequisites

- A [Render](https://render.com) account
- Public Git repository (GitHub, GitLab, or Bitbucket)

### Step 1: Push to Public Repository

Ensure your code is pushed to a public Git repository:

```bash
# Initialize git if not already done
git init

# Add remote (replace with your repository URL)
git remote add origin https://github.com/YOUR_USERNAME/Chinese-chess.git

# Push to repository
git add .
git commit -m "Initial commit"
git push -u origin main
```

### Step 2: Create PostgreSQL Database on Render

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click **New** → **PostgreSQL**
3. Configure the database:
   - **Name**: `xiangqi-db`
   - **Database**: `xiangqi`
   - **User**: `xiangqi`
   - **Region**: Choose closest to your users
   - **Plan**: Free (for testing) or paid for production
4. Click **Create Database**
5. Copy the **Internal Database URL** for later use

### Step 3: Create Redis Instance on Render

1. Click **New** → **Redis**
2. Configure Redis:
   - **Name**: `xiangqi-redis`
   - **Region**: Same as PostgreSQL
   - **Plan**: Free (for testing) or paid for production
3. Click **Create Redis**
4. Copy the **Internal Redis URL** for later use

### Step 4: Deploy Backend Web Service

1. Click **New** → **Web Service**
2. Select **Public Git repository**
3. Enter your repository URL: `https://github.com/YOUR_USERNAME/Chinese-chess`
4. Configure the service:

| Setting | Value |
|---------|-------|
| **Name** | `xiangqi-backend` |
| **Region** | Same as database |
| **Branch** | `main` |
| **Root Directory** | `backend` |
| **Runtime** | `Docker` |
| **Instance Type** | Free (testing) or Starter+ (production) |

5. Add **Environment Variables**:

| Variable | Value |
|----------|-------|
| `XIANGQI_ENVIRONMENT` | `production` |
| `XIANGQI_SERVER_PORT` | `8080` |
| `XIANGQI_SERVER_HOST` | `0.0.0.0` |
| `XIANGQI_DATABASE_HOST` | (from PostgreSQL Internal URL) |
| `XIANGQI_DATABASE_PORT` | `5432` |
| `XIANGQI_DATABASE_USER` | `xiangqi` |
| `XIANGQI_DATABASE_PASSWORD` | (from PostgreSQL) |
| `XIANGQI_DATABASE_DBNAME` | `xiangqi` |
| `XIANGQI_DATABASE_SSLMODE` | `require` |
| `XIANGQI_REDIS_HOST` | (from Redis Internal URL) |
| `XIANGQI_REDIS_PORT` | `6379` |
| `XIANGQI_REDIS_PASSWORD` | (from Redis) |

6. Click **Create Web Service**

### Step 5: Configure Auto-Deploy

Render automatically deploys when you push to your repository. To configure:

1. Go to your Web Service → **Settings**
2. Under **Build & Deploy**, ensure **Auto-Deploy** is set to `Yes`

### Step 6: Run Database Migrations

After the first deployment, run migrations:

1. Go to your Web Service → **Shell**
2. Run:
   ```bash
   ./server migrate up
   ```

Or use Render's **Jobs** feature for one-time tasks.

### render.yaml (Infrastructure as Code)

Alternatively, create a `render.yaml` file in your repository root for automated setup:

```yaml
# render.yaml
databases:
  - name: xiangqi-db
    databaseName: xiangqi
    user: xiangqi
    plan: free # or starter, standard, pro
    region: singapore # or oregon, frankfurt, ohio

services:
  - type: redis
    name: xiangqi-redis
    plan: free # or starter, standard
    region: singapore
    maxmemoryPolicy: allkeys-lru

  - type: web
    name: xiangqi-backend
    runtime: docker
    repo: https://github.com/YOUR_USERNAME/Chinese-chess
    branch: main
    rootDir: backend
    plan: free # or starter, standard
    region: singapore
    healthCheckPath: /health
    envVars:
      - key: XIANGQI_ENVIRONMENT
        value: production
      - key: XIANGQI_SERVER_PORT
        value: "8080"
      - key: XIANGQI_SERVER_HOST
        value: "0.0.0.0"
      - key: XIANGQI_DATABASE_HOST
        fromDatabase:
          name: xiangqi-db
          property: host
      - key: XIANGQI_DATABASE_PORT
        fromDatabase:
          name: xiangqi-db
          property: port
      - key: XIANGQI_DATABASE_USER
        fromDatabase:
          name: xiangqi-db
          property: user
      - key: XIANGQI_DATABASE_PASSWORD
        fromDatabase:
          name: xiangqi-db
          property: password
      - key: XIANGQI_DATABASE_DBNAME
        fromDatabase:
          name: xiangqi-db
          property: database
      - key: XIANGQI_DATABASE_SSLMODE
        value: require
      - key: XIANGQI_REDIS_HOST
        fromService:
          name: xiangqi-redis
          type: redis
          property: host
      - key: XIANGQI_REDIS_PORT
        fromService:
          name: xiangqi-redis
          type: redis
          property: port
      - key: XIANGQI_REDIS_PASSWORD
        fromService:
          name: xiangqi-redis
          type: redis
          property: password
```

To deploy using `render.yaml`:
1. Push `render.yaml` to your repository
2. Go to Render Dashboard → **Blueprints**
3. Click **New Blueprint Instance**
4. Select your repository
5. Render will automatically create all resources

### Custom Domain (Optional)

1. Go to your Web Service → **Settings** → **Custom Domains**
2. Add your domain (e.g., `api.yourdomain.com`)
3. Update DNS records as instructed
4. Render automatically provisions SSL certificates

### WebSocket Support

Render supports WebSocket connections out of the box. No additional configuration needed for the Chinese Chess real-time game features.

### Monitoring on Render

- **Logs**: Web Service → **Logs** (real-time streaming)
- **Metrics**: Web Service → **Metrics** (CPU, Memory, Bandwidth)
- **Health**: Automatic health checks via `/health` endpoint

### Cost Estimation (Render)

| Resource | Free Tier | Starter | Production |
|----------|-----------|---------|------------|
| Web Service | $0/month (spins down after inactivity) | $7/month | $25+/month |
| PostgreSQL | $0/month (90 days, then expires) | $7/month | $20+/month |
| Redis | $0/month (limited) | $10/month | $25+/month |

**Note**: Free tier services spin down after 15 minutes of inactivity and may take ~30 seconds to restart on the next request.

---

## Backend Deployment

### Prerequisites

- Docker and Docker Compose
- PostgreSQL 16+
- Redis 7+
- Go 1.21+ (for building locally)
- Access to a cloud provider (AWS, GCP, DigitalOcean, etc.)

### Option 1: Docker Deployment

#### 1. Build Production Image

```bash
cd backend

# Build optimized Docker image
make docker-build-prod

# Tag with version
docker tag xiangqi-backend:latest xiangqi-backend:v1.0.0
```

#### 2. Push to Registry

```bash
# Login to your registry
docker login your-registry.com

# Push image
docker push your-registry.com/xiangqi-backend:v1.0.0
docker push your-registry.com/xiangqi-backend:latest
```

#### 3. Deploy with Docker Compose

Create a production docker-compose file:

```yaml
# docker-compose.production.yml
version: '3.8'

services:
  backend:
    image: your-registry.com/xiangqi-backend:latest
    ports:
      - "8080:8080"
    environment:
      - XIANGQI_ENVIRONMENT=production
      - XIANGQI_DATABASE_HOST=postgres
      - XIANGQI_DATABASE_PASSWORD=${DB_PASSWORD}
      - XIANGQI_REDIS_HOST=redis
    depends_on:
      - postgres
      - redis
    restart: always
    healthcheck:
      test: ["CMD", "wget", "-q", "-O", "/dev/null", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  postgres:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=xiangqi
      - POSTGRES_USER=xiangqi
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    restart: always

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes
    restart: always

volumes:
  postgres_data:
  redis_data:
```

Deploy:
```bash
# Set environment variables
export DB_PASSWORD=your-secure-password

# Deploy
docker-compose -f docker-compose.production.yml up -d

# Run migrations
docker-compose exec backend ./xiangqi-server migrate up
```

### Option 2: Kubernetes Deployment

#### 1. Create Kubernetes Resources

**Deployment:**
```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: xiangqi-backend
  namespace: xiangqi
spec:
  replicas: 3
  selector:
    matchLabels:
      app: xiangqi-backend
  template:
    metadata:
      labels:
        app: xiangqi-backend
    spec:
      containers:
      - name: backend
        image: your-registry.com/xiangqi-backend:latest
        ports:
        - containerPort: 8080
        env:
        - name: XIANGQI_ENVIRONMENT
          value: "production"
        - name: XIANGQI_DATABASE_HOST
          valueFrom:
            secretKeyRef:
              name: xiangqi-secrets
              key: db-host
        - name: XIANGQI_DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: xiangqi-secrets
              key: db-password
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
```

**Service:**
```yaml
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: xiangqi-backend
  namespace: xiangqi
spec:
  selector:
    app: xiangqi-backend
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

**Ingress:**
```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: xiangqi-ingress
  namespace: xiangqi
  annotations:
    nginx.ingress.kubernetes.io/websocket-services: "xiangqi-backend"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.yourdomain.com
    secretName: xiangqi-tls
  rules:
  - host: api.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: xiangqi-backend
            port:
              number: 80
```

#### 2. Deploy to Kubernetes

```bash
# Create namespace
kubectl create namespace xiangqi

# Create secrets
kubectl create secret generic xiangqi-secrets \
  --from-literal=db-host=your-db-host \
  --from-literal=db-password=your-password \
  -n xiangqi

# Apply resources
kubectl apply -f k8s/

# Check deployment
kubectl get pods -n xiangqi
kubectl get services -n xiangqi
```

### Option 3: Cloud Platform Deployment

#### AWS ECS

1. Create ECR repository
2. Push Docker image
3. Create ECS cluster
4. Create task definition
5. Create ECS service with ALB

#### Google Cloud Run

```bash
# Build and push to GCR
gcloud builds submit --tag gcr.io/YOUR_PROJECT/xiangqi-backend

# Deploy to Cloud Run
gcloud run deploy xiangqi-backend \
  --image gcr.io/YOUR_PROJECT/xiangqi-backend \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="XIANGQI_ENVIRONMENT=production"
```

#### DigitalOcean App Platform

1. Connect your repository
2. Configure environment variables
3. Set up managed database
4. Deploy

### Database Migrations

Always run migrations before deploying new versions:

```bash
# Local
cd backend
make migrate-up

# Docker
docker-compose exec backend ./xiangqi-server migrate up

# Kubernetes
kubectl exec -it deployment/xiangqi-backend -n xiangqi -- ./xiangqi-server migrate up
```

### SSL/TLS Configuration

For production, always use HTTPS:

1. **Using Let's Encrypt with certbot:**
   ```bash
   sudo certbot --nginx -d api.yourdomain.com
   ```

2. **Using cloud provider's certificate manager**

3. **Using Kubernetes cert-manager:**
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: Certificate
   metadata:
     name: xiangqi-tls
     namespace: xiangqi
   spec:
     secretName: xiangqi-tls
     issuerRef:
       name: letsencrypt-prod
       kind: ClusterIssuer
     dnsNames:
     - api.yourdomain.com
   ```

---

## iOS Deployment (TestFlight)

See [ios/TESTFLIGHT.md](ios/TESTFLIGHT.md) for detailed TestFlight deployment instructions.

### Quick Reference

```bash
cd ios/ChineseChess

# Generate project
xcodegen generate

# Run tests
xcodebuild test -scheme ChineseChess -destination 'platform=iOS Simulator,name=iPhone 15'

# Create archive
xcodebuild archive \
  -scheme ChineseChess \
  -configuration Release \
  -archivePath ./build/ChineseChess.xcarchive \
  -destination "generic/platform=iOS"

# Export IPA
xcodebuild -exportArchive \
  -archivePath ./build/ChineseChess.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath ./build

# Upload to App Store Connect
xcrun altool --upload-app -f ./build/ChineseChess.ipa -t ios -u "email" -p "password"
```

---

## Infrastructure Setup

### Recommended Production Architecture

```
                    ┌─────────────────┐
                    │   CloudFlare    │
                    │   (CDN + WAF)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Load Balancer  │
                    │   (nginx/ALB)   │
                    └────────┬────────┘
                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
    ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
    │   Backend   │  │   Backend   │  │   Backend   │
    │  Instance 1 │  │  Instance 2 │  │  Instance 3 │
    └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
           │                 │                 │
           └─────────────────┼─────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
       ┌──────▼──────┐              ┌──────▼──────┐
       │  PostgreSQL │              │    Redis    │
       │  (Primary)  │              │  (Primary)  │
       └──────┬──────┘              └──────┬──────┘
              │                             │
       ┌──────▼──────┐              ┌──────▼──────┐
       │  PostgreSQL │              │    Redis    │
       │  (Replica)  │              │  (Replica)  │
       └─────────────┘              └─────────────┘
```

### Minimum Requirements

| Component | Development | Production |
|-----------|-------------|------------|
| Backend Instances | 1 | 2+ |
| PostgreSQL | 1GB RAM | 4GB+ RAM |
| Redis | 512MB RAM | 2GB+ RAM |
| Storage | 10GB | 50GB+ |

### Security Checklist

- [ ] Use HTTPS/TLS everywhere
- [ ] Secure database credentials with secrets manager
- [ ] Enable database encryption at rest
- [ ] Configure firewall rules
- [ ] Enable rate limiting
- [ ] Set up DDoS protection
- [ ] Regular security updates
- [ ] Enable audit logging
- [ ] Configure backup retention

---

## Monitoring and Maintenance

### Health Checks

Backend health endpoint: `GET /health`

```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "database": "connected",
  "redis": "connected"
}
```

### Logging

Configure structured logging:

```yaml
# Kubernetes logging with Fluentd
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/xiangqi-*.log
      pos_file /var/log/fluentd/xiangqi.pos
      tag xiangqi.*
      <parse>
        @type json
      </parse>
    </source>
```

### Metrics

Expose Prometheus metrics:

```yaml
# Prometheus scrape config
- job_name: 'xiangqi-backend'
  static_configs:
    - targets: ['xiangqi-backend:8080']
  metrics_path: '/metrics'
```

### Alerts

Example alert rules:

```yaml
groups:
- name: xiangqi
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: High error rate detected

  - alert: HighLatency
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High latency detected
```

### Backup Strategy

**Database Backups:**
```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d)
pg_dump -h $DB_HOST -U xiangqi xiangqi | gzip > backup_$DATE.sql.gz

# Upload to S3
aws s3 cp backup_$DATE.sql.gz s3://your-bucket/backups/
```

**Retention Policy:**
- Daily backups: Keep 7 days
- Weekly backups: Keep 4 weeks
- Monthly backups: Keep 12 months

### Rollback Procedure

```bash
# Kubernetes rollback
kubectl rollout undo deployment/xiangqi-backend -n xiangqi

# Docker Compose rollback
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d --force-recreate

# Database rollback
make migrate-down
```

---

## Troubleshooting

### Common Issues

**Connection refused to database:**
- Check database host and port
- Verify firewall rules
- Check database credentials

**WebSocket connections failing:**
- Ensure load balancer supports WebSocket
- Check timeout settings
- Verify nginx configuration includes websocket headers

**High memory usage:**
- Monitor goroutine count
- Check for memory leaks
- Adjust container limits

**Slow response times:**
- Check database query performance
- Monitor Redis connection pool
- Review application logs

### Debug Commands

```bash
# Check pod logs
kubectl logs -f deployment/xiangqi-backend -n xiangqi

# Connect to pod
kubectl exec -it deployment/xiangqi-backend -n xiangqi -- /bin/sh

# Check database connection
kubectl exec -it deployment/xiangqi-backend -n xiangqi -- \
  wget -q -O - http://localhost:8080/health

# Monitor real-time metrics
kubectl top pods -n xiangqi
```

---

## Support

For deployment issues:
- Check logs first
- Review this documentation
- Open a GitHub issue with details
- Contact: devops@example.com
