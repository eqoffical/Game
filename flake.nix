{
  description = "godot dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      trenchbroom =
        let
          appimage = pkgs.fetchzip {
            url = "https://github.com/TrenchBroom/TrenchBroom/releases/download/v2026.2/TrenchBroom-Linux-x86_64-v2026.2-Release.zip";
            hash = "sha256-7YIon2C0sLi0dDD3oJJbRuP7F0JzHjWtD1eqwZKdwmk=";
          };
        in

        pkgs.writeShellScriptBin "trenchbroom" ''
          exec ${pkgs.appimage-run}/bin/appimage-run ${appimage}/TrenchBroom.AppImage "$@"
        '';
    in {
      devShells.${system}.default = pkgs.mkShell {
        name = "godot";
        packages = with pkgs; [
          godot_4_7
          godot_4_7-export-templates-bin
          slade
          trenchbroom
        ];
        shellHook = ''
          mkdir -p "$HOME/.local/share/godot"
          ln -sfn "${pkgs.godot_4_7-export-templates-bin}/share/godot/export_templates" "$HOME/.local/share/godot/export_templates"

          unset PS1
          exec "''${PREFERRED_SHELL:-bash}"
        '';
      };
    };
}
