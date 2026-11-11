{
  lib,
  writeShellApplication,
  pig,
  beads,
  jq,
  coreutils,
  gnused,
  gnugrep,
  git,
}:

# The driver itself is docs/pig-swarm.sh, which also runs in-tree while it is being
# worked on; this only puts it on PATH together with the tools it shells out to.
# Those are prepended to PATH instead of replacing it, so the pig instances it
# spawns still find rg, fd and the rest in the user's environment. git is here for
# -w, which makes a worktree per worker.
writeShellApplication {
  name = "pig-swarm";

  # The script decides its own failure policy: a bd or jq lookup that comes back
  # empty is a normal answer here (no epic yet, no open slot to resume), so errexit
  # must stay off and the script's own 'set -uo pipefail' stands.
  bashOptions = [
    "nounset"
    "pipefail"
  ];

  runtimeInputs = [
    pig
    beads
    jq
    git
    coreutils
    gnused
    gnugrep
  ];

  # The source starts with a #! line for in-tree use; writeShellApplication writes
  # its own, so the original would only survive as a stray comment.
  text = builtins.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] (
    builtins.readFile ../docs/pig-swarm.sh
  );

  meta = {
    description = "Fan N pig agents out over one problem, with a bd epic as the ledger";
    mainProgram = "pig-swarm";
  };
}
