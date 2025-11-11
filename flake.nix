{
  description = "FIDO SSH key management tool with YubiKey support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;

        # Define runtime dependencies outside mkDerivation for use in wrapper
        runtimeDeps = [
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          pkgs.openssh
          pkgs.findutils
          pkgs.gnugrep
          pkgs.gnused
          pkgs.gawk
          pkgs.diffutils
          # Recommended
          pkgs.gh
        ] ++ lib.optionals pkgs.stdenv.isLinux [
          # Linux-specific dependencies
          pkgs.netcat
        ] ++ lib.optionals pkgs.stdenv.isDarwin [
          # macOS-specific dependencies
          pkgs.netcat
        ];
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "keycutter";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          # Runtime dependencies - core requirements
          buildInputs = runtimeDeps;

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Create directory structure
            mkdir -p $out/share/keycutter

            # Copy everything to share directory to preserve structure
            cp -r bin lib libexec ssh_config shell $out/share/keycutter/

            # Create bin directory for the wrapper
            mkdir -p $out/bin

            # Install shell completions
            mkdir -p $out/share/bash-completion/completions
            cp shell/completions/keycutter.bash $out/share/bash-completion/completions/keycutter

            runHook postInstall
          '';

          postFixup = ''
            # Patch shebangs in all scripts
            patchShebangs $out/share/keycutter

            # Create wrapper for main keycutter binary
            makeWrapper $out/share/keycutter/bin/keycutter $out/bin/keycutter \
              --set KEYCUTTER_ROOT $out/share/keycutter \
              --prefix PATH : ${lib.makeBinPath runtimeDeps}
          '';

          meta = with lib; {
            description = "SSH key management tool focused on FIDO2/YubiKey support";
            homepage = "https://github.com/lukeburciu/keycutter";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.unix;
            mainProgram = "keycutter";
          };
        };

        # Development shell with all dependencies and dev tools
        devShells.default = pkgs.mkShell {
          buildInputs = [
            # Runtime dependencies
            pkgs.bash
            pkgs.git
            pkgs.openssh
            pkgs.netcat
            pkgs.gh

            # Development tools
            pkgs.bats
            pkgs.shellcheck
            pkgs.gnumake
          ];

          shellHook = ''
            echo "Keycutter development environment"
            echo "Run 'make test' to run tests"
            echo "Run 'make shellcheck' to check shell scripts"
          '';
        };

        # Allow running directly with 'nix run'
        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/keycutter";
        };
      }
    );
}
