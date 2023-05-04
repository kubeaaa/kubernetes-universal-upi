/******************************************
	OPENSTACK PROVIDER
 *****************************************/

# Configure the OpenStack Provider
provider "openstack" {
  alias = "opk"

  auth_url    = var.openstack_address
  region      = var.openstack_region

  cacert_file = "/etc/ssl/certs/ca-bundle.crt"

  tenant_id   = var.openstack_tenant_id
  tenant_name = terraform.workspace

  user_domain_name    = var.openstack_user_domain_name
  project_domain_name = var.openstack_project_domain_name

  user_name   = data.vault_generic_secret.secret_openstack.data["username"]
  password    = data.vault_generic_secret.secret_openstack.data["password"]
}

# Configure the AWS/S3 Provider
provider "aws" {
  alias = "s3"

  region      = "us-east-1"

  access_key  = var.s3_access_key
  secret_key  = var.s3_secret_key

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3       = var.s3_endpoint
  }
}
