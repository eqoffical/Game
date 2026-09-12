{
  description = "godot dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        name = "godot";
        packages = with pkgs; [
          godot_4_7
          godot_4_7-export-templates-bin
          slade
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
