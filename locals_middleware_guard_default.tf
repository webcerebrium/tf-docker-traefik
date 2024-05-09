locals {
  labels_middleware_guard_default = [
    {
      label = "traefik.http.middlewares.guard.forwardauth.address"
      value = "${var.guard_url}/guard/default"
    },
    {
      label = "traefik.http.middlewares.guard.forwardauth.trustForwardHeader"
      value = "true"
    },
    {
      label = "traefik.http.middlewares.guard.forwardauth.authResponseHeaders"
      value = "X-Real-Ip, X-Country-Code, X-City-EN-Name, X-Local-Ip, X-Uri"
    }
  ]
}

