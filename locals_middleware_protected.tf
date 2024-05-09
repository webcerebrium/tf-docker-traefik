locals {
  labels_middleware_protected = [
    {
      label = "traefik.http.middlewares.protected.forwardauth.address"
      value = "${var.guard_url}/guard/protected"
    },
    {
      label = "traefik.http.middlewares.protected.forwardauth.trustForwardHeader"
      value = "true"
    },
    {
      label = "traefik.http.middlewares.protected.forwardauth.authResponseHeaders"
      value = "X-Real-Ip, X-Country-Code, X-City-EN-Name"
    }
  ]
}

