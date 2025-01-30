variable "pm_api_token_id" {
  description = "The Proxmox API token ID"
  default     = "tform_user@pve!tform_user_token"
}

variable "pm_api_token_secret" {
  description = "The Proxmox API token secret"
  default     = "97b511eb-9876-4589-94a9-8b8a2856bf2b"
}

variable "pm_api_url" {
  description = "The Proxmox API URL"
  default     = "https://10.0.0.81:8006/api2/json"
}

variable "pm_tls_insecure" {
  description = "Whether to allow insecure TLS connections"
  default     = true
}

