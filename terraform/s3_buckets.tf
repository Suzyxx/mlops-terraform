# Loop over the s3_buckets list (from the env tfvars) and call the reusable
# module once per entry. for_each turns the list into a map keyed by `key`,
# so each bucket has a stable address in state.
module "s3_bucket" {
  for_each = { for s3 in var.s3_buckets : s3.key => s3 }
  source   = "./modules/s3-bucket"

  # Final name = key + delimiter + environment, e.g. "...-datastore" + "-" + "dev".
  bucket = join(var.delimiter, [each.value.key, var.environment])

  # Merge any caller-supplied tags with an automatic environment tag.
  tags = merge(try(each.value.tags, {}), { environment = var.environment })
}
