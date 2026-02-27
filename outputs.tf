output "dev_appgw_public_ip" {
  value = module.dev.appgw_public_ip
}

output "uat_appgw_public_ip" {
  value = module.uat.appgw_public_ip
}

output "prod_appgw_public_ip" {
  value = module.prod.appgw_public_ip
}