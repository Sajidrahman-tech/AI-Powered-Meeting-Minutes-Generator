provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "meeting_minutes_bucket" {
  bucket        = "meeting-minutes-input"  # ✅ Use a globally unique bucket name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.meeting_minutes_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "cors" {
  bucket = aws_s3_bucket.meeting_minutes_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = ["*"]  # ⚠️ Replace with your actual frontend domain in production
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_lambda_function" "text_extractor" {
  filename         = "./lambda.zip"                      # ✅ Zip your code and node_modules
  function_name    = "TextExtractorLambda"
  role             = "arn:aws:iam::509738039515:role/LabRole"  # ✅ Already configured IAM role
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("./lambda.zip")    # Ensures updates on zip change
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.meeting_minutes_bucket.bucket
    }
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.text_extractor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.meeting_minutes_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.meeting_minutes_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.text_extractor.arn
    events              = ["s3:ObjectCreated:Put"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
