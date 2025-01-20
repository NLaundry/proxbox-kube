variable "pm_api_url" {
  description = "The Proxmox API URL"
}

variable "pm_api_token_id" {
  description = "The Proxmox API token ID"
}

variable "pm_api_token_secret" {
  description = "The Proxmox API token secret"
}

variable "pm_tls_insecure" {
  description = "Whether to allow insecure TLS connections"
  default     = true
}

