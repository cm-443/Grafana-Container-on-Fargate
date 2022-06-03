//Specified VPC ID
variable "vpc_id" {
 description = "ID of the Target VPC"
 type        = string
 default     = "vpc-xxxxxxxxxxxxxxxxx"
}

//Subnets for ECS
variable "subnets" {
 description = "Target Subnets"
 type        = list(string)
 default     = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxxx"]
}

//Cert Arn
variable "certificate_arn" {
 description = "Certificate ARN"
 type        = string
 default     = "string-here"
}

//Zone ID
variable "zone_id" {
 description = "ID of the hosted zone"
 type        = string
 default     = "string-here"
}

//DNS Name
variable "name" {
 description = "DNS Name"
 type        = string
 default     = "sample.example.com"
}





