variable "config_file" {
  description = "config_file."
  type        = list(string)
  default     = ["/home/nanda/.aws/config"]
}

variable "creds_file" {
  description = "creds_file."
  type        = list(string)
  default     = ["/home/nanda/.aws/credentials"]
}

variable "aws_profile" {
  description = "this is aws profile"
  type        = string
  default     = "grit-cloudnanda"
}

variable "aws_region" {
  description = "this is aws region to provision your infrasture with terraform"
  type        = string
  default     = "ap-southeast-1"
}

variable "stage_name" {
  description = "this is your stage name"
  type        = string
  default     = "dev"
}

variable "cognito_pool_name" {
  description = "amazon cognito pool name"
  type        = string
  default     = "secure-api-pool"
}

variable "cognito_app_client_name" {
  description = "amazon cognito app client name"
  type        = string
  default     = "secure-api-pool-app-client"
}

variable "cognito_domain_name" {
  description = "amazon cognito domain name"
  type        = string
  default     = "secure-api-pool-domain"
}
