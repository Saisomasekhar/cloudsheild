###############################################################################
# Security Group
###############################################################################
resource "aws_security_group" "devops_sg" {
  name   = "devops-sg"
  vpc_id = aws_vpc.devops_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###############################################################################
# VPC
###############################################################################
resource "aws_vpc" "devops_vpc" {
  cidr_block = "192.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "DevOps-VPC"
  }
}

#################################
# PUBLIC SUBNET 1
#################################

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = "192.0.7.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "DevOps-Public-Subnet-1"
  }
}

#################################
# PUBLIC SUBNET 2
#################################

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = "192.0.8.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "DevOps-Public-Subnet-2"
  }
}

#################################
# INTERNET GATEWAY
#################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devops_vpc.id

  tags = {
    Name = "DevOps-IGW"
  }
}

#################################
# ROUTE TABLE
#################################

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.devops_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "DevOps-RouteTable"
  }
}

#################################
# ROUTE TABLE ASSOCIATION 1
#################################

resource "aws_route_table_association" "rt_association_1" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

#################################
# ROUTE TABLE ASSOCIATION 2
#################################

resource "aws_route_table_association" "rt_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

###############################################################################
# S3 Bucket
###############################################################################


resource "aws_s3_bucket" "tf_state" {
  bucket = "devops-terraform-state-saisomasekhar"

  tags = {
    Name = "Terraform State Bucket"
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

###############################################################################
# EC2 Instance
###############################################################################

resource "aws_instance" "devops_vm" {
  ami           = "ami-0d97d7f07b25dd693" # Ubuntu 22.04 LTS
  instance_type = "m7i-flex.large"
  key_name      = "sai-virginia"

  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.devops_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.devops_vm.name

  depends_on = [
    aws_eks_access_policy_association.devops_vm_admin
  ]

  associate_public_ip_address = true

  tags = {
    Name = "DevOps-Agent"
  }

  #############################################
  # WAIT FOR SSH (VERY IMPORTANT)
  #############################################
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for instance to be ready...'",
      "sleep 60"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("sai-virginia.pem")
      host        = self.public_ip
      timeout     = "5m"
    }
  }

  #############################################
  # COPY SCRIPT
  #############################################
  provisioner "file" {
    source      = "install.sh"
    destination = "/home/ubuntu/install.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("sai-virginia.pem")
      host        = self.public_ip
    }
  }

  #############################################
  # EXECUTE SCRIPT
  #############################################
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/\\r$//' /home/ubuntu/install.sh",
      "chmod +x /home/ubuntu/install.sh",
      "sudo /home/ubuntu/install.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("sai-virginia.pem")
      host        = self.public_ip
      timeout     = "10m"
    }
  }

}

###############################################################################
# ECR Repository
###############################################################################

resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.ecr_repository_name
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

###############################################################################
# EKS 
###############################################################################
############################
# EKS CLUSTER ROLE
############################

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "ips-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

############################
# NODE ROLE
############################

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "ips-cluster-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_readonly" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

############################
# EC2 DEVOPS ROLE
############################

data "aws_iam_policy_document" "devops_vm_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "devops_vm" {
  name               = "ips-devops-vm-role"
  assume_role_policy = data.aws_iam_policy_document.devops_vm_assume_role.json
}

resource "aws_iam_policy" "devops_vm_eks_describe" {
  name = "ips-devops-vm-eks-describe"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = aws_eks_cluster.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "devops_vm_ecr_readonly" {
  role       = aws_iam_role.devops_vm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "devops_vm_eks_describe" {
  role       = aws_iam_role.devops_vm.name
  policy_arn = aws_iam_policy.devops_vm_eks_describe.arn
}

resource "aws_iam_instance_profile" "devops_vm" {
  name = "ips-devops-vm-profile"
  role = aws_iam_role.devops_vm.name
}

############################
# EKS CLUSTER
############################

resource "aws_eks_cluster" "main" {
  name     = "ips-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.public_subnet.id,
      aws_subnet.public_subnet_2.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

############################
# NODE GROUP
############################

resource "aws_eks_node_group" "main" {

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "ips-cluster-nodegroup"
  node_role_arn   = aws_iam_role.eks_node.arn

  subnet_ids = [
    aws_subnet.public_subnet.id,
    aws_subnet.public_subnet_2.id
  ]

  instance_types = ["m7i-flex.large"]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly
  ]
}

resource "aws_eks_access_entry" "devops_vm" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.devops_vm.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "devops_vm_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.devops_vm.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}