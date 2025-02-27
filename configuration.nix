# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  #nix.settings.sandbox = false;

  nixpkgs.config.allowUnfree = true;
  #system.autoUpgrade.enable  = true;
  #system.autoUpgrade.allowReboot  = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "vizor"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
  networking.nameservers = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];

  services.resolved = {
	  enable = true;
	  dnssec = "true";
	  domains = [ "~." ];
	  fallbackDns = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
	  dnsovertls = "true";
  };
  services.fwupd.enable = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable sound.
  services.pipewire.enable = true;
  services.tailscale = {
  	enable = true;
	package = pkgs.unstable.tailscale;
  };
  
  virtualisation = {
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers = { 
      vaultwarden = {
        image = "ghcr.io/dani-garcia/vaultwarden:latest";
        autoStart = true;
        ports = [ "127.0.0.1:8001:8001" "127.0.0.1:3012:3012" ];
        volumes = [ "/home/alex/services/vaultwarden/vault:/data/" ];
        environmentFiles = [ "/home/alex/services/vaultwarden/vaultwarden.conf" ];
      };
      homebridge = {
        image = "docker.io/homebridge/homebridge:latest";
        autoStart = true;
        volumes = [ "/home/alex/services/homebridge:/homebridge" ];
        ports = [ "8581:8581" ];
        environment = {
          TZ = "America/Los_Angeles";
          HOMEBRIDGE_CONFIG_UI = "1";
          HOMEBRIDGE_CONFIG_UI_PORT = "8581";
        };
        extraOptions = ["--network=host"];
      };
      scrypted = {
        image = "ghcr.io/koush/scrypted:latest";
        volumes = ["/home/alex/services/scrypted/volume:/server/volume"];
        ports = ["10443:10443"];
        autoStart = true;
        extraOptions = ["--network=host"];
      };
      homeassistant = {
	volumes = [ "/home/alex/services/home-assistant:/config" ];
	environment.TZ = "America/Los_Angeles";
	image = "ghcr.io/home-assistant/home-assistant:stable"; # Warning: if the tag does not change, the image will not be updated
	extraOptions = ["--network=host"];
      };
      audiobookshelf = {
	image = "ghcr.io/advplyr/audiobookshelf";
	environment.TZ = "America/Los_Angeles";
	volumes = [ 
		"/home/alex/books/config:/config" 
		"/home/alex/books/audiobooks:/audiobooks" 
		"/home/alex/books/podcasts:/podcasts" 
		"/home/alex/books/metadata:/metadata" 
	];
	ports = ["13378:13378"];
      };
    };
  };
  
  systemd.timers."vaultwardenbackup" = {
    wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true; 
        Unit = "vaultwarden-backup.service";
      };
  };

  systemd.services."vaultwarden-backup" = {
    path = [pkgs.bash pkgs.restic pkgs.sqlite];
    script =''
      set -eu
      /home/alex/services/vaultwarden/vaultwarden_backup
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };


  services.caddy = {
  	enable = true;
        package = inputs.caddy-patched.packages.x86_64-linux.caddy;
	extraConfig = ''
	(cloudflare) {
          	tls {
			dns cloudflare Z0_VMmrWjCClAalaEXvyd9PvZsnSsVNf8ySKg-Cm
			resolvers 1.1.1.1
		}
	}

	(header) {
		header {
			Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
			X-XSS-Protection "1; mode=block"
			X-Content-Type-Options "nosniff"
			Referrer-Policy "same-origin"
			-Server
			Content-Security-Policy "frame-ancestors litvin.cloud *.litvin.cloud"
			Permissions-Policy "geolocation=(self litvin.cloud *.litvin.cloud)"
		}
	}
	'';
        virtualHosts."vw.litvin.online".extraConfig = ''
        	reverse_proxy http://127.0.0.1:8001
		import cloudflare
        '';
        virtualHosts."hb.litvin.online".extraConfig = ''
        	reverse_proxy http://127.0.0.1:8581
		import cloudflare
        '';
        virtualHosts."sd.litvin.online".extraConfig = ''
        	reverse_proxy https://127.0.0.1:10443 {
			transport http {
                        	tls_insecure_skip_verify
                	}
		}
		import cloudflare
        '';
        virtualHosts."ha.litvin.online".extraConfig = ''
        	reverse_proxy http://127.0.0.1:8123
		import cloudflare
		import header
		encode gzip
        '';
  };
  systemd.services.caddy.serviceConfig.AmbientCapabilities = "cap_net_bind_service";
  systemd.services.caddy.serviceConfig.CapabilityBoundingSet = "cap_net_bind_service";


  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.alex = {
     home = "/home/alex";
     description = "Alexander Zhavnerchik";
     shell = pkgs.fish;
     isNormalUser = true;
     extraGroups = [ "wheel" "networkmanager" ]; # Enable ‘sudo’ for the user.
     packages = with pkgs; [
    ];
   };
  users.users.root.hashedPassword = "!";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget
    helix
    rustup
    clang
    cmake
    ninja
    meson
    fzf
    zlib-ng
    starship
    git
    restic
    sqlite
    gnumake
    openssl
    go
    xcaddy
    cacert
    htop
    atop
    unstable.jujutsu
    ghostty
  ];
  
  programs.fish.enable = true;
  programs.neovim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
  };
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/alex/nix";
    package = pkgs.unstable.nh;
  };
  

  # xdg.portal.wlr.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "23.11"; # Did you read the comment?

}

