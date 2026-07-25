output "endpoint" {
  value = aws_db_instance.this.endpoint
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "password" {
  value     = random_password.master.result
  sensitive = true
}
