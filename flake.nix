{
  description = "Zen Browser";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      version = "1.14.11b";
      pkgs = import nixpkgs {
        inherit system;
        config = {
        allowUnfree = true;
        allowUnfreePredicate = (pkg: true);
        };
      };

      runtimeLibs = with pkgs; [
        libGL libGLU libevent libffi libjpeg libpng libstartup_notification libvpx libwebp
        stdenv.cc.cc fontconfig libxkbcommon zlib freetype
        gtk3 libxml2 dbus xcb-util-cursor alsa-lib libpulseaudio pango atk cairo gdk-pixbuf glib
        udev libva mesa libnotify cups pciutils
        ffmpeg libglvnd pipewire fontconfig noto-fonts fontconfig.lib harfbuzz icu libthai fribidi
        gtk3 adwaita-icon-theme gnome-themes-extra

      ] ++ (with pkgs.xorg; [
        libxcb libX11 libXcursor libXrandr libXi libXext libXcomposite libXdamage
        libXfixes libXScrnSaver
      ]);

      zenBrowser = pkgs.stdenv.mkDerivation {
        pname = "zen-browser";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-x86_64.tar.xz";
          sha256 = "b2dc6e3c7c4e1f7f28628a9d7c51f21ef10013fe11152c87171a9cd5f9ee6778";
        };

        desktopSrc = ./.;

        nativeBuildInputs = [ pkgs.makeWrapper pkgs.gawk ];

        dontUnpack = true;

        installPhase = ''
          # Unpack the browser tarball to the build directory
          tar -xf $src --strip-components=1

            # Create destination directories
             mkdir -p $out/bin
             mkdir -p $out/share/applications/
             mkdir -p $out/share/icons/hicolor/128x128/apps/

             # Install browser binaries
             cp -r * $out/bin/

             # Copy desktop file to the build directory and then modify it
             cp "$desktopSrc/zen.desktop" ./zen.desktop

             substituteInPlace ./zen.desktop \
             --replace "Exec=zen" "Exec=$out/bin/zen"

             # Install the modified desktop file
             install -m644 ./zen.desktop $out/share/applications/

             # Install the icon
             install -m644 $out/bin/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen.png
             '';

        dontPatchELF = true;

        preFixup = ''
        # The original tarball contains an executable, not a launcher.
    # So we directly patch the main executable.
    # Set the dynamic linker for the main executable
    # patchelf --set-interpreter "$(cat ${pkgs.stdenv.cc.libc}/nix-support/dynamic-linker)" $out/bin/zen
    patchelf --set-interpreter "$(cat ${pkgs.glibc}/nix-support/dynamic-linker)" $out/bin/zen


           # Set the RPATH for the executable to include all runtime libraries
    patchelf --set-rpath "${pkgs.lib.makeLibraryPath runtimeLibs}" $out/bin/zen

           # The executable needs to be wrapped so that it knows about the
    # library paths for its own inner workings.
    # We use wrapProgram to create a wrapper script for the executable.
    wrapProgram $out/bin/zen \
    --set MOZ_LEGACY_PROFILES 1 \
    --set MOZ_ALLOW_DOWNGRADE 1 \
    --set MOZ_APP_LAUNCHER zen \
    --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeLibs}" \
    --set FONTCONFIG_FILE "${pkgs.fontconfig.out}/etc/fonts/fonts.conf" \
    --set FONTCONFIG_PATH "${pkgs.fontconfig.out}/etc/fonts"
    --set GTK_THEME Adwaita \
    --set XDG_DATA_DIRS "$XDG_DATA_DIRS:${pkgs.adwaita-icon-theme}/share:${pkgs.gnome-themes-extra}/share"
'';
    
        meta = with pkgs.lib; {
          description = "Zen Browser";
          homepage = "https://zenbrowser.com/";
          license = licenses.unfree;
          maintainers = [ ];
          platforms = [ "x86_64-linux" ];
        };
      };
    in
    {
      packages.${system}.zenBrowser = zenBrowser;
      defaultPackage.${system} = zenBrowser;
    };
}
