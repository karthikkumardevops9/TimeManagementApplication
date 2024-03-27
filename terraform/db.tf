resource "aws_db_instance" "timemanagementDB" {
    allocated_storage = 10
    storage_type = "gp2"
    engine = "mysql"
    engine_version = "5.7"
    instance_class = "db.t3.medium"
    username = "karthik"
    password = "I8well4sure!"

    db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name

    backup_retention_period = 7
    backup_window = "03:00-04:00"
    maintenance_window = "mon:04:00-mon:04:30"
   
    # security_groups = [aws_security_group.security_group.id]
    # subnets = tolist(module.vpc.private_subnets)

     skip_final_snapshot = true
     final_snapshot_identifier = "db-snap"

     # Enable enhanced monitoring
     monitoring_interval = 60
     monitoring_role_arn = aws_iam_role.rds_monitoring_role.arn

     # Enable performance insights
     performance_insights_enabled = true

     storage_encrypted = true

     kms_key_id = aws_kms_key.my_kms_key.arn

     multi_az = true
  
}

resource "aws_db_instance" "replica" {
  replicate_source_db = aws_db_instance.timemanagementDB.identifier
  instance_class = "db.t3.medium"
 
  backup_retention_period = 7
  backup_window = "03:00-04:00"
  maintenance_window = "mon:04:00-mon:04:30"
  skip_final_snapshot = false
  final_snapshot_identifier = "my-db"
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring_role.arn
  performance_insights_enabled = true
  storage_encrypted = true
  kms_key_id = aws_kms_key.my_kms_key.arn

 # parameter_group_name = aws_db_parameter_group.my_db_pmg.name

  # Enable Multi-AZ deployment for high availability
  multi_az = true
}

resource "aws_kms_key" "my_kms_key" {
  description = "My KMS Key for RDS Encryption"
  deletion_window_in_days = 30

  tags = {
    Name = "MyKMSKey"
  }
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
    name     = "my-db-subnet-group"
    subnet_ids = tolist(module.vpc.private_subnets)

    tags = {
      Name = "My DB Subnet group"
    }
}

resource "aws_iam_role" "rds_monitoring_role" {
  name = "rds-monitoring-role"

  assume_role_policy = jsonencode({
  Version = "2012-10-17",
  Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }
  ]
})
}

resource "aws_iam_policy_attachment" "rds_monitoring_attachment" {
  name = "rds-monitoring-attachment"
  roles = [aws_iam_role.rds_monitoring_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}