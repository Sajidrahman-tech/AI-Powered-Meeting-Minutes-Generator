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

### 1️⃣ Clone the repository

```bash
git clone https://github.com/your-username/AI-Powered-Meeting-Minutes-Generator.git
cd AI-Powered-Meeting-Minutes-Generator
