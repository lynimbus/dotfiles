{
  lib,
  runCommand,
  makeWrapper,
  # The real Pi CLI (pi 1.x, a bun-compiled native binary) this wraps: see
  # overlay.nix for where it comes from.
  pi,
}:

# Lody never runs a Pi binary directly: it spawns its own ACP adapter (a
# node package it manages under ~/.lody/agent-binaries) which in turn
# spawns a Pi CLI, its location taken from the Pi agent config's
# executable override (runtimeOverrides.piPath), passed through as
# LODY_PI_PATH. This package is the binary that override points at: the
# real Pi, on PATH under a name pig has not taken.
#
# Pi answers to PI_CODING_AGENT_DIR, so the wrapper pins one explicitly:
# the real Pi's own ~/.pi/agent, whose models.json carries the local
# Magpie gateway (127.0.0.1:3425) as a provider and whose settings.json
# picks the default model -- Lody's Pi turns ride the same gateway the
# rest of this machine's agents do, with no separate login. A value Lody
# itself sets (a provider imported from Magpie points it at
# ~/.lody/magpie, where Lody writes the models.json) still wins: the
# default below only fills the variable when it arrives unset.
#
# The tradeoff of sharing ~/.pi/agent is sharing it entirely: Lody's Pi
# sessions and skills land beside Magpie's pi runs of the same folder.
runCommand "lody-pi-${pi.version}"
  {
    nativeBuildInputs = [ makeWrapper ];

    meta = {
      description = "The real Pi CLI for Lody's ACP adapter, pinned to ~/.pi/agent";
      homepage = pi.meta.homepage or "https://github.com/earendil-works/pi";
      inherit (pi.meta) license platforms;
      mainProgram = "lody-pi";
    };
  }
  ''
    mkdir -p $out/bin
    makeWrapper ${lib.getExe pi} $out/bin/lody-pi \
      --run 'export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"'
  ''
