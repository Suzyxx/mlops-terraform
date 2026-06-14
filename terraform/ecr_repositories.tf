# Loop over the ecr_repositories list (from the env tfvars) and call the reusable
# module once per entry. Same for_each pattern as s3_buckets.tf — turn the list
# into a map keyed by `key` so each repo has a stable address in state.
module "ecr_repository" {
  for_each = { for ecr in var.ecr_repositories : ecr.key => ecr }
  source   = "./modules/ecr-repository"

  # Final name = key + delimiter + environment, e.g. "...-repository" + "-" + "dev".
  name                         = join(var.delimiter, [each.value.key, var.environment])
  image_tag_mutability         = each.value.image_tag_mutability
  image_scanning_configuration = each.value.image_scanning_configuration

  # Merge any caller-supplied tags with an automatic environment tag.
  tags = merge(try(each.value.tags, {}), { environment = var.environment })
}
