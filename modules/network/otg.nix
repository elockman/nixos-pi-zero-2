#copied from: https://github.com/illegalprime/nixos-on-arm/blob/master/machines/raspberrypi-zero/otg.nix
{ config, lib, ... }:
let
  otg_modules = {
    "serial"       = { module = "g_serial"; config = "USB_G_SERIAL"; };
    "ether"        = { module = "g_ether"; config = "USB_ETH"; };
    "mass_storage" = { module = "g_mass_storage"; config = "USB_MASS_STORAGE"; };
    # "midi"         = { module = "g_midi"; config = "USB_MIDI_GADGET"; };
    # "audio"        = { module = "g_audio"; config = "USB_AUDIO"; };
    "hid"          = { module = "g_hid"; config = "USB_G_HID"; };
    "acm_ms"       = { module = "g_acm_ms"; config = "USB_G_ACM_MS"; };
    "cdc"          = { module = "g_cdc"; config = "USB_CDC_COMPOSITE"; };
    # "webcam"       = { module = "g_webcam"; config = "USB_G_WEBCAM"; };
    # "printer"      = { module = "g_printer"; config = "USB_G_PRINTER"; };
    # "zero"         = { module = "g_zero"; config = "USB_ZERO"; };
    # "multi"        = { module = ""; config = ""; }; # TODO:
  };
in
with builtins;
with lib;
{
  options = {
    boot.otg = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          enable USB OTG, let your raspberry pi
          act as a USB device.
        '';
      };
      module = mkOption {
        type = types.enum (attrNames otg_modules);
        default = "zero";
        example = "ether";
        description = ''
          the OTG module to load
        '';
      };
      link = mkOption {
        type = types.enum ["module" "static"];
        default = "module";
        example = "static";
        description = ''
          to build the OTG kernel module statically in the kernel
          or as a dynamic module that can be loaded / unloaded
        '';
      };
    };
  };
  config = let
    module = otg_modules.${config.boot.otg.module};
    link = { "static" = "y"; "module" = "m"; }.${config.boot.otg.link};
  in mkIf config.boot.otg.enable {

    # add otg modules if necessary to kernel config
    boot.kernelPatches = [
      {
        name = "usb-otg";
        patch = null;
        extraConfig = ''
          USB_GADGET y
          USB_DWC2 m
          USB_DWC2_DUAL_ROLE y
          ${module.config} ${link}
        '';
      }
    ];

    # make sure they're loaded when the pi boots
    boot.kernelModules = [
      "dwc2" "${module.module}"
    ];

    boot.loader.raspberryPi.firmwareConfig = "dtoverlay=dwc2";

    # enable USB Ethernet  https://wiki.nixos.org/wiki/Internet_Connection_Sharing
    networking.interfaces."usb0" = {
      useDHCP = true;
    };

    # don't wait for the usb ethernet to connect
    networking.dhcpcd.wait = "background";

    # load usb0 in device mode in the device tree
    hardware.deviceTree = {
      enable = true;
      filter = "bcm2837-rpi-zero-2-w.dtb";
      overlays = [
        {
          name = "dwc2_usb";
          dtsText = ''
            /dts-v1/;
            /plugin/;
            / {
              compatible = "raspberrypi,model-zero-2-w", "brcm,bcm2837";
            };
            &usb {
                compatible = "brcm,bcm2835-usb";
                dr_mode = "otg";
                g-np-tx-fifo-size = <32>;
                g-rx-fifo-size = <558>;
                g-tx-fifo-size = <512 512 512 512 512 256 256>;
                status = "okay";
            };
          '';
        }
      ];
    };
  };
}
