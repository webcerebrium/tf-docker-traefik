variable "hosted_zones" {
    type = map(object({
        name = string
        hosts = list(string)
        local_port = number
        host_rule = string
        www_rule = string
    }))
}
