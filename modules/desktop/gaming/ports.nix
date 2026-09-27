{ config, pkgs, lib, ... }:

with builtins;
with lib;
let cfg = config.modules.desktop.gaming.ports;
in {
  options.modules.desktop.gaming.ports = {
    zelda = {
      majora = mkEnableOption "The Legend of Zelda: Majora's Mask";
      ocarina = mkEnableOption "The Legend of Zelda: Ocarina of Time";
    };
    mario = {
      sixtyfour = mkEnableOption "Super Mario 64";
      kart = {
        wii = mkEnableOption "Mario Kart Wii";
      };
    };
  };

  config = {
    environment.systemPackages =
      optional cfg.zelda.majora pkgs._2ship2harkinian
      ++ optional cfg.zelda.ocarina pkgs.shipwright
      ++ optional cfg.mario.sixtyfour pkgs.sm64ex-coop
      ++ optional cfg.mario.kart.wii pkgs.wheelwizard;
  };
}
