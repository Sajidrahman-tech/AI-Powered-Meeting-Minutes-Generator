////////////////////////////////////////////////////////////////////////////////////////////////////


# Random ID to ensure bucket uniqueness
resource "random_id" "frontend_suffix" {
  byte_length = 4
}

# S3 Bucket for static site hosting
resource "aws_s3_bucket" "frontend_site" {
  bucket        = "meeting-frontend-4321"
  force_destroy = true
  tags = {
    Name = "frontend-hosting-bucket"
  }
}

# ✅ Allow public access (required to attach bucket policy)
resource "aws_s3_bucket_public_access_block" "frontend_access_block" {
  bucket = aws_s3_bucket.frontend_site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Static website configuration
resource "aws_s3_bucket_website_configuration" "frontend_site" {
  bucket = aws_s3_bucket.frontend_site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Public access policy (required for static hosting)
resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.frontend_site.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend_site.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend_access_block]
}

# Outputs
output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend_site.bucket
}


output "frontend_website_url" {
  value       = aws_s3_bucket_website_configuration.frontend_site.website_endpoint
  description = "Your hosted React app URL"
}

