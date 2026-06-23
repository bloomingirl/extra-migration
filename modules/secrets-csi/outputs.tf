output "driver_namespace" {
  description = "Namespace where the secrets-store-csi-driver is installed"
  value       = helm_release.secrets_store_csi_driver.namespace
}
