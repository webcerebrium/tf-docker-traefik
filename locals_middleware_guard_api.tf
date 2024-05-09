locals {
  labels_middleware_guard_api = [
    {
      label = "traefik.http.middlewares.guardapi.forwardauth.address"
      value = "${var.guard_url}/guard/api"
    },
    {
      label = "traefik.http.middlewares.guardapi.forwardauth.trustForwardHeader"
      value = "true"
    },
    {
      label = "traefik.http.middlewares.guardapi.forwardauth.authResponseHeaders"
      value = "X-Real-Ip, X-Country-Code, X-City-EN-Name"
    }
  ]
}

