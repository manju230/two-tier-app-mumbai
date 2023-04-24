#output : resource(.)Name(.)Attribute
#Output : aws_eip.eip.pubic_ip

output "aws_alb" {
  value = aws_alb.myalb.id

}