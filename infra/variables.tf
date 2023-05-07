variable "region" {
  default = "eu-central-1"
  type    = string
}

variable "prefix" {
  description = "The prefix to use for all names"
  type        = string
  default     = "ericcbonet-blog"
}

variable "frontend_bucket_name" {
  description = "The name of the s3 bucket used to store hugo app"
  type        = string
  default     = "frontend"
}

variable "domain_name" {
  description = "The domain name where the frontend will be hosted"
  type        = string
  default     = "ericcbonet.com"
}

variable "cdn_bucket_name" {
  description = "The name of the s3 bucket used for our cdn"
  type        = string
  default     = "cdn"
}
