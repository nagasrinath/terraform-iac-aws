# Demo-only credential handling: a generated password kept in Terraform
# state and exposed as a sensitive output. A real deployment would use
# AWS Secrets Manager or RDS-managed master passwords instead.
# ponytail: swap for aws_db_instance.manage_master_user_password if this
# becomes more than a demo.
resource "random_password" "master" {
  length  = 20
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = var.tags
}

resource "aws_security_group" "this" {
  name        = "${var.identifier}-rds"
  description = "Allow Postgres from the app tier"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.identifier}-rds" })
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "postgres"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = merge(var.tags, { Name = var.identifier })
}
