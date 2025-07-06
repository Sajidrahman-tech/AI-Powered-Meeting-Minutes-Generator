provider "aws" {
  region = "us-east-1"
}

# -------------------- VPC & Subnets --------------------
resource "aws_vpc" "meeting_minutes_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-meeting-minutes"
  }
}

resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.meeting_minutes_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-az1"
  }
}

resource "aws_subnet" "public_subnet_az2" {
  vpc_id                  = aws_vpc.meeting_minutes_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-az2"
  }
}

resource "aws_subnet" "private_app_subnet_az1" {
  vpc_id            = aws_vpc.meeting_minutes_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "private-app-subnet-az1"
  }
}

# -------------------- Internet Gateway & NAT --------------------
resource "aws_internet_gateway" "igw_meeting_minutes" {
  vpc_id = aws_vpc.meeting_minutes_vpc.id
  tags = {
    Name = "igw-meeting-minutes"
  }
}

resource "aws_eip" "nat_eip_meeting_minutes" {
  domain = "vpc"
  tags = {
    Name = "eip-nat-meeting-minutes"
  }
}

resource "aws_nat_gateway" "nat_gw_meeting_minutes" {
  allocation_id = aws_eip.nat_eip_meeting_minutes.id
  subnet_id     = aws_subnet.public_subnet_az1.id
  depends_on    = [aws_internet_gateway.igw_meeting_minutes]
  tags = {
    Name = "natgw-meeting-minutes"
  }
}

# -------------------- Route Tables --------------------
resource "aws_route_table" "rt_public_meeting_minutes" {
  vpc_id = aws_vpc.meeting_minutes_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_meeting_minutes.id
  }

  tags = {
    Name = "rt-public-meeting-minutes"
  }
}

resource "aws_route_table_association" "rta_public_az1" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.rt_public_meeting_minutes.id
}

resource "aws_route_table_association" "rta_public_az2" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.rt_public_meeting_minutes.id
}

resource "aws_route_table" "rt_private_meeting_minutes" {
  vpc_id = aws_vpc.meeting_minutes_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_meeting_minutes.id
  }

  tags = {
    Name = "rt-private-meeting-minutes"
  }
}

resource "aws_route_table_association" "rta_private_az1" {
  subnet_id      = aws_subnet.private_app_subnet_az1.id
  route_table_id = aws_route_table.rt_public_meeting_minutes.id
}

# -------------------- Security Groups --------------------
resource "aws_security_group" "alb_http_sg" {
  name        = "meeting-minutes-alb-http"
  description = "Allow HTTP from public"
  vpc_id      = aws_vpc.meeting_minutes_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "meeting-minutes-alb-http"
  }
}

resource "aws_security_group" "ec2_flask_sg" {
  name        = "meeting-minutes-ec2-flask"
  description = "Allow traffic from ALB to Flask and SSH access"
  vpc_id      = aws_vpc.meeting_minutes_vpc.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_http_sg.id]
    description     = "Allow ALB to reach Flask app"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access from developer IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "meeting-minutes-ec2-flask"
  }
}


# -------------------- S3 Buckets --------------------
resource "aws_s3_bucket" "bucket_flask_app" {
  bucket        = "meeting-flask-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_object" "flask_app_zip" {
  bucket = aws_s3_bucket.bucket_flask_app.id
  key    = "flask-app.zip"
  source = "${path.module}/flask-app.zip"
  etag   = filemd5("${path.module}/flask-app.zip")
}

resource "aws_s3_bucket" "bucket_meeting_input" {
  bucket        = "meeting-minutes-input"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "block_meeting_input" {
  bucket = aws_s3_bucket.bucket_meeting_input.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "cors_meeting_input" {
  bucket = aws_s3_bucket.bucket_meeting_input.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
# -------------------- Data Source for IAM Instance Profile --------------------
data "aws_iam_instance_profile" "lab_instance_profile" {
  name = "LabInstanceProfile"  # This must match exactly what's shown in the EC2 metadata
}
# -------------------- EC2 Instance --------------------
resource "aws_instance" "ec2_embedding_server" {
  ami                         = "ami-0c2b8ca1dad447f8a"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_app_subnet_az1.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_flask_sg.id]

  iam_instance_profile        = data.aws_iam_instance_profile.lab_instance_profile.name
user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 unzip -y
              cd /home/ec2-user

              echo "Checking internet..." >> setup.log
              ping -c 3 google.com > internet_test.log 2>&1
              aws s3 cp internet_test.log s3://${aws_s3_bucket.bucket_flask_app.bucket}/internet_test.log

              echo "Downloading Flask app zip..." >> setup.log
              aws s3 cp s3://${aws_s3_bucket.bucket_flask_app.bucket}/flask-app.zip . >> setup.log 2>&1
              unzip flask-app.zip >> setup.log 2>&1

              echo "Upgrading pip..." >> setup.log
              sudo python3 -m pip install --upgrade pip --break-system-packages >> setup.log 2>&1

              echo "Installing dependencies..." >> setup.log
              sudo python3 -m pip install flask  >> setup.log 2>&1
              sudo python3 -m pip install urllib3==1.26.18 >> setup.log 2>&1
              sudo python3 -m pip install requests==2.31.0  >> setup.log 2>&1
              sudo python3 -m pip install transformers==4.29.2  >> setup.log 2>&1
              sudo python3 -m pip install safetensors==0.3.1  >> setup.log 2>&1
              sudo python3 -m pip install torch==1.13.1+cpu --extra-index-url https://download.pytorch.org/whl/cpu  >> setup.log 2>&1
              sudo python3 -m pip install torchvision==0.14.1+cpu --extra-index-url https://download.pytorch.org/whl/cpu  >> setup.log 2>&1
              sudo python3 -m pip install sentence-transformers==2.2.2  >> setup.log 2>&1
              pip3 install faiss-cpu

                sleep 40
              echo "Starting Flask app..." >> setup.log
              nohup python3 app.py > output.log 2>&1 &
              sleep 10

              echo "Uploading logs..." >> setup.log
              aws s3 cp output.log s3://${aws_s3_bucket.bucket_flask_app.bucket}/output.log
              aws s3 cp setup.log s3://${aws_s3_bucket.bucket_flask_app.bucket}/setup.log
EOF


  tags = {
    Name = "ec2-meeting-minutes-flask"
  }
}

# -------------------- Load Balancer --------------------
resource "aws_lb" "alb_embedding_meeting" {
  name               = "alb-meeting-minutes"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
  security_groups    = [aws_security_group.alb_http_sg.id]
}

resource "aws_lb_target_group" "tg_embedding_meeting" {
  name     = "tg-meeting-minutes"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.meeting_minutes_vpc.id
}

resource "aws_lb_target_group_attachment" "tga_ec2_embedding" {
  target_group_arn = aws_lb_target_group.tg_embedding_meeting.arn
  target_id        = aws_instance.ec2_embedding_server.id
  port             = 5000
}

resource "aws_lb_listener" "listener_http" {
  load_balancer_arn = aws_lb.alb_embedding_meeting.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_embedding_meeting.arn
  }
}
# -------------------- HTTP API with CORS --------------------
resource "aws_apigatewayv2_api" "http_api" {
  name          = "meeting-query-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins     = ["*"]                         # Allow all origins
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"] # Allow all methods
    allow_headers     = ["*"]                         # Allow all headers
    expose_headers    = ["*"]                         # Expose all headers
    max_age           = 3600                          # Cache CORS for 1 hour
  }
}

# -------------------- Lambda Function --------------------
resource "aws_lambda_function" "lambda_query_handler" {
  filename         = "./retriverlambda.zip"
  function_name    = "lambda-meeting-query-handler"
  role             = "arn:aws:iam::509738039515:role/LabRole"
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("./retriverlambda.zip")
  timeout          = 15
  memory_size      = 256

  environment {
    variables = {
      EMBEDDING_SERVER_URL = "http://${aws_lb.alb_embedding_meeting.dns_name}"
      # OPENAI_API_KEY       = var.openai_api_key (optional)
    }
  }

  depends_on = [aws_lb.alb_embedding_meeting]
}

# -------------------- Lambda Permission for API Gateway --------------------
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_query_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# -------------------- Integration with Lambda --------------------
resource "aws_apigatewayv2_integration" "lambda_query_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lambda_query_handler.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# -------------------- Route for POST /query --------------------
resource "aws_apigatewayv2_route" "lambda_query_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /query"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_query_integration.id}"
}

# -------------------- Stage --------------------
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# -------------------- Output API URL --------------------
output "query_api_url" {
  description = "API Gateway URL for React frontend"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}

//////////////////////////////////////////////////////////
# -------------------- Lambda for Upload URL --------------------
resource "aws_lambda_function" "lambda_upload_url" {
  filename         = "./signedUrlLambda.zip"
  function_name    = "lambda-generate-upload-url"
  role             = "arn:aws:iam::509738039515:role/LabRole"
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("./signedUrlLambda.zip")
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.bucket_meeting_input.bucket

    }
  }
}

# -------------------- Lambda Permission --------------------
resource "aws_lambda_permission" "allow_api_gateway_upload_url" {
  statement_id  = "AllowExecutionFromAPIGatewayUploadUrl"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_upload_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# -------------------- Integration --------------------
resource "aws_apigatewayv2_integration" "lambda_upload_url_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lambda_upload_url.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# -------------------- Route: POST /generate-upload-url --------------------
resource "aws_apigatewayv2_route" "lambda_upload_url_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /generate-upload-url"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_upload_url_integration.id}"
}

/////////////////////////////////////////////////////////
# -------------------- Lambda Function --------------------
resource "aws_lambda_function" "lambda_text_extractor" {
  filename         = "./lambda.zip"
  function_name    = "lambda-meeting-text-extractor"
  role             = "arn:aws:iam::509738039515:role/LabRole"
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  source_code_hash = filebase64sha256("./lambda.zip")
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      BUCKET_NAME           = aws_s3_bucket.bucket_meeting_input.bucket
      EMBEDDING_SERVER_URL  = "http://${aws_lb.alb_embedding_meeting.dns_name}"

    }
  }

  depends_on = [aws_lb.alb_embedding_meeting]
}

resource "aws_lambda_permission" "lambda_permission_s3" {
  statement_id  = "AllowS3ToInvokeTextExtractor"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_text_extractor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket_meeting_input.arn
}

resource "aws_s3_bucket_notification" "notification_meeting_input" {
  bucket = aws_s3_bucket.bucket_meeting_input.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_text_extractor.arn
    events              = ["s3:ObjectCreated:Put"]
  }

  depends_on = [aws_lambda_permission.lambda_permission_s3]
}

////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////







# -------------------- Output --------------------
output "alb_dns_name" {
  description = "Public DNS of the Application Load Balancer"
  value       = aws_lb.alb_embedding_meeting.dns_name
}
output "api_gateway_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}