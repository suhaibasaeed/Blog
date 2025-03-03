variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-west-2b", "us-west-2c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# Create the VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "demo-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "demo-igw"
  }
}

# Create Public Subnets for NAT-GWs
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = {
    Name = "nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Create NAT Gateways
resource "aws_nat_gateway" "nat" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "demo-nat-gw-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Create Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create Route Tables for Private Subnets (one per AZ to use the NAT Gateway in that AZ)
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "private-route-table-${count.index + 1}"
  }
}

# Associate Private Route Tables with Private Subnets
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security group for EC2 instances
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Example inbound rule - SSH from within VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Name = "ec2-security-group"
  }
}

# Create EC2 instances in private subnets (one per AZ)
resource "aws_instance" "private_instances" {
  count         = length(var.availability_zones)
  ami           = "ami-09b3e59052c3e621c"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private[count.index].id
  
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "private-instance-${var.availability_zones[count.index]}"
  }
}

resource "aws_s3_bucket" "vpc_flow_logs_bucket" {
  bucket = "demo-vpc-flow-logs-030325"
}

# Prevents our VPC flow logs from being accidentally exposed to the internet
resource "aws_s3_bucket_public_access_block" "vpc_flow_logs_bucket_public_access_block" {
  bucket = aws_s3_bucket.vpc_flow_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_flow_log" "us_prod_vpc_flow_log" {
  # Send the logs to S3 bucket created above
  log_destination = aws_s3_bucket.vpc_flow_logs_bucket.arn
  # We can filter flow logs at the ENI and subnet level. Here we want the whole VPC
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  log_destination_type = "s3"

  destination_options {
    file_format = "parquet"
    # Organise directories by time allowing for more efficient queries
    hive_compatible_partitions = true
    # Enable per hour partitions for faster/granular queries
    per_hour_partition = true
  }
}
# Define values in locals block to avoid repition in Terraform code
locals {
  prefix                   = "demo030325"
  flow_logs_table_name     = "vpc_flow_logs_parquet"
  flow_logs_s3_bucket_name = aws_s3_bucket.vpc_flow_logs_bucket.id
}

resource "aws_s3_bucket" "query_location_bucket" {
  bucket        = replace("${local.prefix}-athena-query-location", "_", "-")
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
}
resource "aws_s3_bucket_public_access_block" "vpc_athena_query_bucket_public_access_block" {
  bucket = aws_s3_bucket.query_location_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_athena_workgroup" "vpc_flow_logs" {
  name = "${local.prefix}_vpc_flow_logs"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.query_location_bucket.bucket}/"
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
  force_destroy = true
}

resource "aws_athena_database" "vpc_flow_logs" {
  name          = replace("${local.prefix}-vpc-flow-logs", "-", "_")
  bucket        = aws_s3_bucket.query_location_bucket.bucket
  force_destroy = true
}