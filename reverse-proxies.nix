{ lib, config, ... }:

sops = {
  defaultSopsFile = ./secrets/secrets.yaml;

  # The server uses its SSH host private key for decryption.
  age.sshKeyPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];

  secrets."cloudflare-acme-env" = {
    owner = "acme";
    group = "acme";
    mode = "0400";
  };
};

let
  acmeCert = "litvin.online";

  headers = ''
    add_header Strict-Transport-Security \
      "max-age=63072000; includeSubDomains; preload" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "same-origin" always;
    add_header Content-Security-Policy \
      "frame-ancestors https://litvin.cloud https://*.litvin.cloud;" always;
    add_header Permissions-Policy \
      "geolocation=(self \"https://litvin.cloud\" \"https://*.litvin.cloud\")" always;

    # Hides the version, but stock nginx still emits "Server: nginx".
    server_tokens off;
  '';

  mkProxy = {
    upstream,
    withHeaders ? false,
    insecureUpstreamTLS ? false,
  }: {
    forceSSL = true;
    useACMEHost = acmeCert;

    extraConfig = lib.optionalString withHeaders headers;

    locations."/" = {
      proxyPass = upstream;

      # Caddy handles WebSocket upgrades automatically; nginx needs this.
      proxyWebsockets = true;

      extraConfig = lib.optionalString insecureUpstreamTLS ''
        proxy_ssl_verify off;
      '';
    };
  };
in
{

  security.acme = {
    acceptTerms = true;
    defaults.email = "your-email@example.com";

    certs."litvin.online" = {
      domain = "litvin.online";
      extraDomainNames = [ "*.litvin.online" ];

      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";

      # This file must be created outside the Nix store.
      environmentFile = config.sops.secrets."cloudflare-acme-env".path;

      # Allows nginx to read the private key.
      group = "nginx";
    };
  };

  services.nginx = {
    enable = true;

    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts = {
      "vw.litvin.online" = mkProxy {
        upstream = "http://127.0.0.1:8001";
      };

      "abs.litvin.online" = mkProxy {
        upstream = "http://127.0.0.1:13378";
      };

      "hb.litvin.online" = mkProxy {
        upstream = "http://127.0.0.1:8581";
      };

      "sd.litvin.online" = mkProxy {
        upstream = "https://127.0.0.1:10443";
        insecureUpstreamTLS = true;
      };

      "ha.litvin.online" = mkProxy {
        upstream = "http://127.0.0.1:8123";
        withHeaders = true;
      };

      "kb.litvin.online" = mkProxy {
        upstream = "http://127.0.0.1:8000";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
