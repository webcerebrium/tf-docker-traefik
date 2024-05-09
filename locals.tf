locals {
  project             = var.network_params.project
  postfix             = var.network_params.postfix
  network_internal_id = var.network_params.network_id

  shortname       = "traefikapi"
  hostname        = "traefik-${local.postfix}"
  entrypoint      = var.https == 1 ? "https" : "traefik"
  jaeger_endpoint = var.https == 1 ? "${var.jaeger_endpoint}" : ""
  jaeger_enabled  = var.https == 1 ? "true" : "false"

  middlewares = length(var.trusted_ips) > 0 ? "trusted" : ""
  scheme = var.https == 1 ? "https" : "http"
}

locals {
  ports_localhost = [
    for z in var.hosted_zones : {
      internal = z.local_port
      external = z.local_port
    }
  ]
  ports_multihost = [{
    internal = 80
    external = 80
    }, {
    internal = 443
    external = 443
  }]
  ports = var.https == 1 ? local.ports_multihost : local.ports_localhost

  cert_config = join("\n", concat([
    for cert in var.certificates : join("\n", [
      "   - certFile: /certs/${cert.name}.crt",
      "     keyFile: /certs/${cert.name}.key"
    ])
  ]))
  default_cert_config = join("\n", concat([
    for cert in var.certificates : join("\n", [
      "        certFile: /certs/${cert.name}.crt",
      "        keyFile: /certs/${cert.name}.key"
    ])
  ]))

  upload = concat(var.upload, [
    for cert in var.certificates : {
      "file" : "/certs/${cert.name}.crt",
      "content" : cert.certificate,
    }
    ], [
    for cert in var.certificates : {
      "file" : "/certs/${cert.name}.key",
      "content" : cert.private_key,
    }
    ], [
    {
      file = "/certs/certs-traefik.yml",
      content = join("\n", [
        "tls:",
        "  certificates:", local.cert_config,
        #"  stores:", 
        #"    default:", 
        #"      defaultCertificate:", local.default_cert_config,
      ])
    }
  ])
}

locals {
  labels_all_zones = [
    {
      label = "traefik.enable"
      value = "true"
      }, {
      label = "traefik.docker.network"
      value = docker_network.public.name
      }, {
      label = "traefik.constraint-label"
      value = docker_network.public.name
    }
  ]
}

locals {
  zone = {
    for name, z in var.hosted_zones : name => {
      "network_internal_id" = local.network_internal_id
      "network_public_id"   = docker_network.public.id
      "network_public_name" = docker_network.public.name
      "postfix"             = local.postfix
      "project"             = local.project
      "name"                = z.name
      "hosts"               = var.https == 1 ? z.hosts : ["localhost"]
      "host_rule"           = var.https == 1 ? z.host_rule : "Host(`localhost`)"
      "www_rule"            = var.https == 1 ? z.www_rule : ""
      "entrypoint"          = var.https == 1 ? "https" : z.name
      "local_port"          = z.local_port
      "https"               = var.https
      "labels"              = local.labels_all_zones
    }
  }

  zones_list = keys(var.hosted_zones)

  api_host_rule = !contains(local.zones_list, "traefik")  ? "" : (
      length(var.hosted_zones["traefik"].hosts) > 1 ? 
        format("(%s)", join(" || ", formatlist("Host(`%s`)", var.hosted_zones["traefik"].hosts))) : 
        "Host(`${var.hosted_zones["traefik"].hosts[0]}`)"
  )

  labels_api = !contains(local.zones_list, "traefik") ? local.labels_all_zones : [
    {
      label = "traefik.http.routers.${local.shortname}.rule"
      value = local.api_host_rule
    },
    {
      label = "traefik.http.routers.${local.shortname}.entrypoints"
      value = local.zone["traefik"].entrypoint
    },
    {
      label = "traefik.http.routers.${local.shortname}.service"
      value = "api@internal"
    },
    {
      label = "traefik.http.routers.${local.shortname}.tls"
      value = "true"
    },
    {
      label = "traefik.http.routers.${local.shortname}.tls.certresolver"
      value = "le"
    },
    {
      label = "traefik.http.routers.${local.shortname}.middlewares"
      value = local.middlewares
    }
  ]
}

locals {
  labels_container = concat(
    var.network_params.labels,
    contains(local.zones_list, "traefik") ? local.zone["traefik"].labels : [],
    local.labels_api,
    local.labels_middleware_trusted,
    local.labels_middleware_compress,
    var.guard_url == "" ? [] : local.labels_middleware_guard_default,
    var.guard_url == "" ? [] : local.labels_middleware_guard_api,
    var.guard_url == "" ? [] : local.labels_middleware_protected,
  )
  entrypoints_localhost = flatten([
    for name, z in var.hosted_zones : [
      "--entrypoints.${z.name}.address=:${z.local_port}",
      "--metrics.prometheus.entrypoint=${z.name}",
    ]
  ])
  entrypoints_multihost = [
    // TODO: this is actually wrong, we should have as many entry points as zones
    "--entrypoints.http.address=:80",
    "--entrypoints.https.address=:443",
    "--entrypoints.http.http.redirections.entrypoint.to=https",
    "--entrypoints.http.http.redirections.entrypoint.scheme=https",
    "--entrypoints.http.http.redirections.entrypoint.permanent=true",
    "--metrics.prometheus.entrypoint=http",
    "--metrics.prometheus.entrypoint=https",
  ]
  entrypoints = var.https == 1 ? local.entrypoints_multihost : local.entrypoints_localhost

  tracing = [
    "--tracing=${local.jaeger_enabled}",
    "--tracing.jaeger.collector.endpoint=${local.jaeger_endpoint}",
    // "--tracing.jaeger.samplingServerURL=http://localhost:5778/sampling",
    // "--tracing.jaeger.samplingType=const",
    // "--tracing.jaeger.samplingParam=1.0"
    // "--tracing.jaeger.localAgentHostPort=127.0.0.1:6831",
    // "--tracing.jaeger.propagation=jaeger"
    // "--tracing.jaeger.traceContextHeaderName=uber-trace-id",
    // "--tracing.jaeger.collector.user=my-user",
    // "--tracing.jaeger.collector.password=my-password",
  ]
}

locals {
  env = [
    "LOGSPOUT=ignore",
  ]

  command = compact(concat(
    local.entrypoints,
    local.tracing,
    var.https == 1 ? [
      "--certificatesresolvers.le.acme.email=${var.admin_email}",
      "--certificatesresolvers.le.acme.storage=/certificates/acme.json",
      "--certificatesresolvers.le.acme.tlschallenge=true",
      "--log.level=DEBUG",
      ] : [
      "--api.insecure=true",
      "--log.level=DEBUG",
      "--metrics.prometheus.addentrypointslabels=true"
    ],
    length(var.certificates) > 0 ? [
      "--providers.file.directory=/certs/",
      "--providers.file.watch=true"
    ] : [],
    [
      "--providers.docker",
      "--providers.docker.constraints=Label(`traefik.constraint-label`, `${docker_network.public.name}`)",
      "--providers.docker.exposedbydefault=false",
      "--accesslog=true",
      "--accesslog.bufferingsize=10",
      "--api=true",
      "--api.debug=true",
      "--api.dashboard=true",
      "--log",
      "--log.format=json",
    ])
  )
}
