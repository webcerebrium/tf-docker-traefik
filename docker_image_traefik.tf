resource "docker_image" traefik {
    name = "traefik:v2.11"
    keep_locally = true
}
