# 📝 AI-Powered Meeting Minutes Generator

The **AI-Powered Meeting Minutes Generator** is a cloud-native application that automates the process of extracting, summarizing, and retrieving actionable insights from meeting transcripts. Combining serverless architecture, vector search, and advanced language models, this system provides accurate, context-rich summaries to help teams stay aligned.

---

## ✨ Key Features

- **Automatic Text Extraction:** Parse and process meeting transcripts in PDF and other formats.
- **Chunking & Embedding:** Generate vector embeddings using state-of-the-art SentenceTransformer models.
- **Semantic Search:** Retrieve the most relevant content using FAISS vector similarity.
- **Summarization:** Generate concise meeting summaries with Retrieval-Augmented Generation (RAG) workflows.
- **Secure Storage:** Store files and metadata securely in AWS S3 and DynamoDB.
- **API-Driven Architecture:** Expose functionality via RESTful APIs powered by AWS Lambda and API Gateway.
- **Modern Frontend:** Intuitive React-based user interface.

---

## 🛠️ Tech Stack

- **Frontend:** React, Axios
- **Backend:**
  - AWS Lambda (Python)
  - Flask server on EC2 (embedding & FAISS)
  - API Gateway
  - DynamoDB (metadata storage)
  - S3 (file storage)
- **Machine Learning:**
  - SentenceTransformers (embedding generation)
  - FAISS (vector similarity search)
  - Google Gemini 1.5 Flash (LLM summarization)
- **Infrastructure as Code:** Terraform

---

## ⚙️ Architecture Overview

1. **File Upload:**
   - Users upload a transcript file via the frontend.
   - A pre-signed S3 URL is generated for secure storage.

2. **Text Extraction:**
   - A Lambda function processes the file to extract and chunk the text.

3. **Embedding:**
   - The chunked text is sent to a Flask server hosted on EC2.
   - SentenceTransformer embeddings are generated and indexed in FAISS.

4. **Retrieval & Summarization:**
   - On query, relevant chunks are retrieved via vector similarity.
   - The context is passed to the Gemini model for summarization.

5. **Storage:**
   - Summaries and metadata are stored in DynamoDB and S3.

---

## 🚀 Getting Started

> **Note:** You must have AWS credentials configured and access to required resources (S3 buckets, DynamoDB tables, EC2 instance, etc.)

---

### 1️⃣ Clone the repository

```bash
git clone https://github.com/your-username/AI-Powered-Meeting-Minutes-Generator.git
cd AI-Powered-Meeting-Minutes-Generator
```

### 2️⃣ Deploy Infrastructure with Terraform

```bash
cd terraform
terraform init
terraform apply
```

### 3️⃣ Start the Flask Embedding Server on EC2

1. **SSH into your EC2 instance:**

```bash
ssh -i your-key.pem ec2-user@your-ec2-public-dns
```

2. **Clone the repository (or copy server code):**

```bash
git clone https://github.com/your-username/AI-Powered-Meeting-Minutes-Generator.git
cd AI-Powered-Meeting-Minutes-Generator/server
```

3. **Create a virtual environment:**

```bash
python3 -m venv venv
source venv/bin/activate
```

4. **Install Python dependencies:**

```bash
pip install -r requirements.txt
```

5. **Start the Flask server:**

```bash
python3 app.py
```

The server will run on `http://0.0.0.0:5000`

### 4️⃣ Keep the Server Running in the Background

**Option A – nohup:**

```bash
nohup python3 app.py &
```

**Option B – screen:**

```bash
screen -S embedding-server
python3 app.py
```

*(Detach screen: Ctrl + A, then D)*

### 5️⃣ Start the Frontend Locally

1. **Navigate to the frontend directory:**

```bash
cd frontend
```

2. **Install frontend dependencies:**

```bash
npm install
```

3. **Start the development server:**

```bash
npm start
```

4. **Access the app:**
   - Open `http://localhost:3000` in your browser.

### 6️⃣ Deploy Lambda Functions

**Option A – Using AWS Console:**

1. Go to the AWS Lambda Console.
2. Create each function:
   - `TextExtractorLambda`
   - `EmbeddingLambda`
   - `RetrieverLambda`
   - `SummarizerLambda`
3. Upload the deployment ZIP files.
4. Set environment variables:
   - S3 bucket names
   - DynamoDB table names
   - Other configurations
5. Attach appropriate IAM roles.
6. Create API Gateway triggers for each Lambda.

**Option B – Using AWS CLI:**

Example for creating `TextExtractorLambda`:

```bash
aws lambda create-function \
  --function-name TextExtractorLambda \
  --zip-file fileb://text_extractor.zip \
  --handler lambda_function.lambda_handler \
  --runtime python3.9 \
  --role arn:aws:iam::your-account-id:role/your-lambda-role
```

---

## 📋 Prerequisites

- **AWS Account** with appropriate permissions
- **Python 3.9+** installed locally
- **Node.js 16+** and npm
- **Terraform** installed
- **AWS CLI** configured with your credentials
- **Google Gemini API Key** for LLM summarization

---

## 🔧 Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# AWS Configuration
AWS_REGION=us-east-1
S3_BUCKET_NAME=your-meeting-minutes-bucket
DYNAMODB_TABLE_NAME=meeting-minutes-metadata

# Google Gemini API
GEMINI_API_KEY=your-gemini-api-key

# EC2 Flask Server
FLASK_SERVER_URL=http://your-ec2-public-ip:5000

# Frontend Configuration
REACT_APP_API_GATEWAY_URL=https://your-api-gateway-url.amazonaws.com/prod
```

### AWS Resources Required

- **S3 Bucket:** For storing uploaded files and generated summaries
- **DynamoDB Table:** For metadata storage
- **EC2 Instance:** For running the Flask embedding server
- **Lambda Functions:** For serverless processing
- **API Gateway:** For REST API endpoints
- **IAM Roles:** With appropriate permissions for Lambda functions

---

## 🏗️ Project Structure

```
AI-Powered-Meeting-Minutes-Generator/
├── frontend/                 # React frontend application
│   ├── src/
│   ├── public/
│   └── package.json
├── server/                   # Flask embedding server
│   ├── app.py
│   ├── requirements.txt
│   └── models/
├── lambda/                   # AWS Lambda functions
│   ├── text_extractor/
│   ├── embedding_processor/
│   ├── retriever/
│   └── summarizer/
├── terraform/                # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── docs/                     # Documentation
├── scripts/                  # Deployment scripts
└── README.md
```

---

## 🔄 API Endpoints

### File Upload
- **POST** `/api/upload`
- **Description:** Generate pre-signed S3 URL for file upload

### Text Extraction
- **POST** `/api/extract`
- **Description:** Extract and chunk text from uploaded files

### Embedding Generation
- **POST** `/api/embed`
- **Description:** Generate vector embeddings for text chunks

### Query Processing
- **POST** `/api/query`
- **Description:** Retrieve relevant chunks and generate summary

### Summary Retrieval
- **GET** `/api/summaries/{id}`
- **Description:** Retrieve stored meeting summaries

---

## 🧪 Testing

### Unit Tests

```bash
# Backend tests
cd server
python -m pytest tests/

# Frontend tests
cd frontend
npm test
```

### Integration Tests

```bash
# Test the complete workflow
python scripts/test_integration.py
```

---

## 📊 Monitoring & Logging

- **CloudWatch Logs:** Monitor Lambda function execution
- **CloudWatch Metrics:** Track API Gateway and Lambda performance
- **Application Logs:** Flask server logs on EC2
- **Error Tracking:** Centralized error logging and alerting

---

## 🔒 Security Considerations

- **IAM Roles:** Principle of least privilege for all AWS resources
- **S3 Bucket Policy:** Restrict access to authorized users only
- **API Gateway:** Rate limiting and authentication
- **Environment Variables:** Secure storage of sensitive information
- **VPC Configuration:** Network isolation for EC2 instances

---

## 🚀 Production Deployment

### Auto Scaling Configuration

```bash
# Configure auto-scaling for EC2 instances
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name meeting-minutes-asg \
  --min-size 1 \
  --max-size 3 \
  --desired-capacity 2
```

### Load Balancer Setup

```bash
# Create Application Load Balancer
aws elbv2 create-load-balancer \
  --name meeting-minutes-alb \
  --subnets subnet-12345 subnet-67890 \
  --security-groups sg-12345
```

---

## 🐛 Troubleshooting

### Common Issues

1. **Lambda Timeout Errors:**
   - Increase timeout limits in Lambda configuration
   - Optimize code for better performance

2. **FAISS Index Errors:**
   - Ensure proper FAISS installation on EC2
   - Check vector dimensions compatibility

3. **S3 Permission Errors:**
   - Verify IAM roles have S3 access
   - Check bucket policies

4. **API Gateway CORS Issues:**
   - Configure CORS properly in API Gateway
   - Update frontend API calls

### Debug Commands

```bash
# Check Lambda logs
aws logs tail /aws/lambda/TextExtractorLambda --follow

# Test Flask server
curl -X POST http://your-ec2-ip:5000/health

# Validate Terraform configuration
terraform validate
terraform plan
```

---

## 📈 Performance Optimization

- **Caching:** Implement Redis for frequently accessed embeddings
- **CDN:** Use CloudFront for static asset delivery
- **Database Optimization:** Optimize DynamoDB queries and indexing
- **Batch Processing:** Process multiple files concurrently

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 🙏 Acknowledgments

- [SentenceTransformers](https://www.sbert.net/) for embedding generation
- [FAISS](https://github.com/facebookresearch/faiss) for vector similarity search
- [Google Gemini](https://deepmind.google/technologies/gemini/) for LLM capabilities
- [AWS](https://aws.amazon.com/) for cloud infrastructure

---

## 📞 Support

For support and questions:
- 📧 Email: sajidrahman@dal.ca
