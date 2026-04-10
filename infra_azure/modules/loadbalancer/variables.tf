variable "resource_group_name" {
    type = string
}

variable "location" {
  type = string
}

variable "nic_ids" {
  type = list(string)
}