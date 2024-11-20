{
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = [
    ./sd-image.nix
    ./modules/network/otg.nix
  ];

  # Some packages (ahci fail... this bypasses that) https://discourse.nixos.org/t/does-pkgs-linuxpackages-rpi3-build-all-required-kernel-modules/42509
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  # ! Need a trusted user for deploy-rs.
  nix.settings.trusted-users = ["@wheel"];
  system.stateVersion = "24.05";

  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  sdImage = {
    # bzip2 compression takes loads of time with emulation, skip it. Enable this if you're low on space.
    compressImage = false;
    imageName = "zero2.img";

    extraFirmwareConfig = {
      # Give up VRAM for more Free System Memory
      # - Disable camera which automatically reserves 128MB VRAM
      start_x = 0;
      # - Reduce allocation of VRAM to 16MB minimum for non-rotated (32MB for rotated)
      gpu_mem = 16;

      # Configure display to 800x600 so it fits on most screens
      # * See: https://elinux.org/RPi_Configuration
      hdmi_group = 2;
      hdmi_mode = 8;
    };
  };

  # Keep this to make sure wifi works
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.firmware = [pkgs.raspberrypiWirelessFirmware];

  boot = {
    kernelPackages = pkgs.linuxPackages_rpi02w;
    kernelParams = [
      "earlycon" # enable writing to uart serial console early in boot process
      "boot.shell_on_fail"
      "8250.nr_uarts=1" # configure mini uart https://forums.raspberrypi.com/viewtopic.php?t=246215
      "console=ttyS0,115200n8" #set console to output to uart1 (miniuart)
    ];
    initrd.availableKernelModules = [
      "xhci_pci" 
      "usbhid" 
      "usb_storage"
      "libcomposite" # For OTG ethernet. See here: https://discourse.nixos.org/t/looking-for-help-to-create-a-raspberry-pi-with-usb-ethernet/27039
      ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    # enable otg usb ethernet
    otg = {
      enable = true;
      module = "ether";
    };

    # Avoids warning: mdadm: Neither MAILADDR nor PROGRAM has been set. This will cause the `mdmon` service to crash.
    # See: https://github.com/NixOS/nixpkgs/issues/254807
    swraid.enable = lib.mkForce false;
  };

  # networking = {
  #   interfaces."wlan0".useDHCP = true;
  #   wireless = {
  #     enable = true;
  #     interfaces = ["wlan0"];
  #     # ! Change the following to connect to your own network
  #     networks = {
  #       "<ssid>" = {
  #         psk = "<ssid-key>";
  #       };
  #     };
  #   };
  # };

  # enable USB Ethernet  https://wiki.nixos.org/wiki/Internet_Connection_Sharing
  networking.interfaces."usb0" = {
    useDHCP = false;
    ipv4.addresses = [{
      address = "10.0.0.1";
      prefixLength = 24;
    }];
  };
  # networking.firewall.extraCommands = ''
  #   # Set up SNAT on packets going from downstream to the wider internet
  #   iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE

  #   # Accept all connections from downstream. May not be necessary
  #   iptables -A INPUT -i enp2s0 -j ACCEPT
  # '';
  # # Run a DHCP server on the downstream interface
  # services.kea.dhcp4 = {
  #   enable = true;
  #   settings = {
  #     interfaces-config = {
  #       interfaces = [
  #         "usb0"
  #       ];
  #     };
  #     lease-database = {
  #       name = "/var/lib/kea/dhcp4.leases";
  #       persist = true;
  #       type = "memfile";
  #     };
  #     rebind-timer = 2000;
  #     renew-timer = 1000;
  #     subnet4 = [
  #       {
  #         id = 1;
  #         pools = [
  #           {
  #             pool = "10.0.0.2 - 10.0.0.255";
  #           }
  #         ];
  #         subnet = "10.0.0.1/24";
  #       }
  #     ];
  #     valid-lifetime = 4000;
  #     option-data = [{
  #       name = "routers";
  #       data = "10.0.0.1";
  #     }];
  #   };
  # };

  # Enable OpenSSH out of the box.
  services.sshd.enable = true;

  # NTP time sync.
  services.timesyncd.enable = true;

  # ! Change the following configuration
  users.users.admin = {
    isNormalUser = true;
    home = "/home/admin";
    description = "Admin";
    extraGroups = ["wheel" "networkmanager"];
    # ! Be sure to put your own public key here
    openssh.authorizedKeys.keys = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD1kcnCJMRYEUf87W37Axq7mjqpxZv/MyIJX9m/WTnWns0lZ/QIwbuMdEnsAszoXllgIDFJdeH05Xzkcm0dnGp9JjWchh61vMdwGPAWbIFL5TBbeBpFiF67/BmXF9hzwnjXpoy7W/t810m2hm3s2AB35R608GUsw6QaByW74y71mz69GxADXZm6bRubF4STBLDr8xrVN8bCUt5LUPvLoWB6Oc8lPAXB/V7gynqRockM25M+B7xF1jg3QRJwnj75TAjnra9OtN+CdhhyhzOZt0xbU2LHAqnYq8OFrM7N5+pCHxWer7fYaN0GaKjq9uJTuUkiPyQRcVvEK1DMBulopTrawvh1nGa/xho2CWmFae6uTR0YUgzO+AJegg1Fso4D8YOD1avURfQsOY6U5nrkz49jVLtXpLAU7Xh8vibZgE9Wrpjlty3ieIHIia9eJd2B+9mAy6k+wY+Q3TuV3wQM2Lcia+KeLuPwfkII5hijl+JUl/VPRtCHaFUg0Pj5h2rIURDjO0SqZr7m/HmsHbdtg5lKxCcWDJaL6e3M0/3PbPBkH+nssnUpRu9laCa8ibjAzKdUorOPzUltaVkSwEaTk1kabaywGEqiZzUwsYfGhBqP6qzbyGmN7lBqCv3UvTJdbX5CJhYSWQWmPr4o/UgP80IJiqTsCmgvJ/r+Nv85sgqP4Q== bryanmehall@gmail.com"];
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
  # ! Be sure to change the autologinUser.
  services.getty.autologinUser = "admin";

  # disable zfs and cifs to prevent samba error when cross-compiling
  boot.supportedFilesystems.zfs = lib.mkForce false;
  boot.supportedFilesystems.cifs = lib.mkForce false;
}
