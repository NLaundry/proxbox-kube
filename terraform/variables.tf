variable "pm_api_token_id" {
  description = "The Proxmox API token ID"
  default     = "tform_user@pve!tform_user_token"
}

variable "pm_api_token_secret" {
  description = "The Proxmox API token secret"
  default     = "a69458e2-6046-46ea-abd0-8606c6c915eb"
}

variable "pm_api_url" {
  description = "The Proxmox API URL"
  default     = "https://192.168.1.221:8006/api2/json"
}

variable "pm_tls_insecure" {
  description = "Whether to allow insecure TLS connections"
  default     = true
}

