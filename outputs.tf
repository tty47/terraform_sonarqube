output "ip_address_sonar_public" {
    value = aws_instance.ec2_sonar.public_ip
}
output "ip_address_sonar_psql_public" {
    value = aws_instance.ec2_sonar_psql.public_ip
}

output "private_key" {
    value = tls_private_key.devops.private_key_pem
}

output "public_key" {
    value = tls_private_key.devops.public_key_pem
}

output "ip_address_sonar_private" {
    value = aws_instance.ec2_sonar.private_ip
}

output "ip_address_sonar_psql_private" {
    value = aws_instance.ec2_sonar_psql.private_ip
}