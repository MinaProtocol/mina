# Overlay containing various overrides for nixpkgs packages used by Mina
final: prev: {
  sodium-static =
    final.libsodium.overrideAttrs (o: { dontDisableStatic = true; });

  # Jobs/Lint/ValidationService
  # Jobs/Test/ValidationService
  validation = ((final.mix-to-nix.override {
    beamPackages = final.beam.packagesWith final.erlangR23; # todo: jose
  }).mixToNix {
    src = ../src/app/validation;
    # todo: think about fixhexdep overlay
    # todo: dialyze
    overlay = (final: prev: {
      goth = prev.goth.overrideAttrs
        (o: { preConfigure = "sed -i '/warnings_as_errors/d' mix.exs"; });
    });
  });

}
