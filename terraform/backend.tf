terraform {
  backend "s3" {
    bucket = "karthik-s3-teammanagementapp"
    key = "karthik/terraform.tfstate"
    region = "us-east-1"  
    
  }
}