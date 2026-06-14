# Loop over the apprunner_services list (from the env tfvars) and call the
# reusable module once per entry — same for_each pattern as s3/ecr.
module "apprunner_service" {
  for_each = { for ars in var.apprunner_services : ars.key => ars }
  source   = "./modules/apprunner-service"

  # Final name = key + delimiter + environment, e.g. "...-app" + "-" + "dev".
  name                 = join(var.delimiter, [each.value.key, var.environment])
  source_configuration = each.value.source_configuration

  tags = merge(try(each.value.tags, {}), { environment = var.environment })
}
