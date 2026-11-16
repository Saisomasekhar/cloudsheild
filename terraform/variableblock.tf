# variable "aws_profile" {
#   description = "AWS Profile to be used"
#   type        = string
#   default     = "default"
# }
# variable "aws_region" {
#   description = "Region in which AWS Resources to be created"
#   type        = string
#   default     = "us-east-1"
# }

# variable "region" {
#   description = "AWS Region"
# }

# variable "account_id" {
#   description = "AWS Account ID"
# }

# variable "github_repo" {
#   description = "GitHub repo in format owner/repo"
# }

# # ECR
# variable "ecr_repository_name" {
#   description = "ECR repository name"
# }

# # EKS
# variable "eks_cluster_name" {
#   description = "EKS Cluster Name"
# }

# variable "eks_node_instance_types" {
#   type = list(string)
# }

# variable "eks_node_desired_size" {
#   description = "Desired node count"
# }

# variable "eks_node_min_size" {
#   description = "Minimum node count"
# }

# variable "eks_node_max_size" {
#   description = "Maximum node count"
# }


variable "aws_profile" {
  description = "AWS Profile to be used"
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "AWS Region in which resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format"
  type        = string
}

# ECR Variables
variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
}

# EKS Variables
variable "eks_cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "eks_node_instance_types" {
  description = "Instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum node count"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum node count"
  type        = number
  default     = 3
}
