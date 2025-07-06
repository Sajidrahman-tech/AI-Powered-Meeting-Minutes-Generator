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

resource "random_id" "suffix" {
  byte_length = 4
} 
# -------------------- S3 Buckets --------------------
resource "aws_s3_bucket" "bucket_flask_app" {
  bucket        = "meeting-flask-bucket-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_object" "flask_app_zip" {
  bucket = aws_s3_bucket.bucket_flask_app.id
  key    = "flask-app.zip"
  source = "${path.module}/flask-app.zip"
  etag   = filemd5("${path.module}/flask-app.zip")
}

resource "aws_s3_bucket" "bucket_meeting_input" {
  bucket        = "meeting-minutes-input-${random_id.suffix.hex}"
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
  depends_on = [aws_s3_bucket.bucket_meeting_input]
}


#########
# 1. Create IAM Role
resource "aws_iam_role" "ec2_backend_role" {
  name = "meeting-minutes-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# 2. Attach IAM Policies (S3, CloudWatch, SNS)
resource "aws_iam_role_policy" "ec2_backend_policy" {
  name = "meeting-minutes-policy"
  role = aws_iam_role.ec2_backend_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # 🔹 Full access to all S3 buckets (GET, PUT, LIST)
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*"
        ]
      },
      # 🔹 CloudWatch Logs access
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      # 🔹 CloudWatch Metrics
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData"
        ],
        Resource = "*"
      },
      # 🔹 SNS Publish (to all topics — for more control, scope to specific ARNs)
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = "*"
      }
    ]
  })
}

# 3. IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "meeting-minutes-ec2-profile"
  role = aws_iam_role.ec2_backend_role.name
}
#################




# -------------------- EC2 Instance --------------------
resource "aws_instance" "ec2_embedding_server" {
  ami                         = "ami-0c2b8ca1dad447f8a"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_app_subnet_az1.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_flask_sg.id]

iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
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

              yum install -y amazon-cloudwatch-agent

              cat <<EOT > /opt/aws/amazon-cloudwatch-agent/bin/config.json
              {
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/home/ec2-user/output.log",
                          "log_group_name": "/ec2/embedding/output",
                          "log_stream_name": "{instance_id}"
                        },
                        {
                          "file_path": "/home/ec2-user/setup.log",
                          "log_group_name": "/ec2/embedding/setup",
                          "log_stream_name": "{instance_id}"
                        }
                      ]
                    }
                  }
                }
              }
              EOT

              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config \
                -m ec2 \
                -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json \
                -s

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


resource "aws_sns_topic" "ec2_alarm_topic" {
  name = "ec2-error-topic"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.ec2_alarm_topic.arn
  protocol  = "email"
  endpoint  = "sajid3krahman@gmail.com"  # Replace with your email
}
resource "aws_cloudwatch_log_group" "flask_log_group" {
  name              = "/aws/ec2/flask-app-logs"  # use the same name you're referencing in the metric filter
  retention_in_days = 7
}
resource "aws_cloudwatch_log_metric_filter" "flask_error_filter" {
  name           = "FlaskAppErrorFilter"
  log_group_name = aws_cloudwatch_log_group.flask_log_group.name

  pattern = "?ERROR ?Error ?Exception"

  metric_transformation {
    name      = "FlaskAppErrors"
    namespace = "FlaskApp"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "flask_error_alarm" {
  alarm_name          = "flask-error-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FlaskAppErrors"
  namespace           = "FlaskApp"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggered when Flask app logs an error"
  alarm_actions       = [aws_sns_topic.ec2_alarm_topic.arn]
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

resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "lambda_s3_put_policy" {
  name = "lambda-putobject-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.bucket_meeting_input.arn}/*"
      }
    ]
  })
}
# -------------------- Lambda Function --------------------
resource "aws_lambda_function" "lambda_query_handler" {
  filename         = "./retriverlambda.zip"
  function_name    = "lambda-meeting-query-handler"
  role             =  aws_iam_role.lambda_role.arn
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
  role = aws_iam_role.lambda_role.arn
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
  role = aws_iam_role.lambda_role.arn

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


resource "local_file" "config_json" {
  content  = jsonencode({
    REACT_APP_API_BASE_URL = aws_apigatewayv2_api.http_api.api_endpoint
  })
  filename = "${path.module}/config.json"
}


# Random ID to ensure bucket uniqueness
resource "random_id" "frontend_suffix" {
  byte_length = 4
}

# S3 Bucket for static site hosting
resource "aws_s3_bucket" "frontend_site" {
  bucket        = "meeting-frontend-${random_id.frontend_suffix.hex}"
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

resource "aws_s3_object" "config_json" {
  bucket = aws_s3_bucket.frontend_site.bucket
  key    = "config.json"
  source = local_file.config_json.filename
  content_type = "application/json"
  depends_on = [
  aws_s3_bucket.frontend_site,
  local_file.config_json,
  aws_s3_bucket_public_access_block.frontend_access_block
]
}

# Outputs
output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend_site.bucket
}

output "frontend_website_url" {
  value       = aws_s3_bucket_website_configuration.frontend_site.website_endpoint
  description = "Your hosted React app URL"
}

///////////////////////////////////////////////////////////////////////////////////////////////////







# -------------------- Output --------------------
output "alb_dns_name" {
  description = "Public DNS of the Application Load Balancer"
  value       = aws_lb.alb_embedding_meeting.dns_name
}
output "api_gateway_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}