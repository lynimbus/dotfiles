{ ... }:

{
  # nix-ld covers an ELF binary that asks for the FHS interpreter. Shebang
  # scripts are the other half of the same problem: a script with
  # #!/usr/bin/python3 or #!/bin/bash gets no interpreter here, because /usr/bin
  # is empty and /bin holds only sh.
  #
  # envfs mounts /usr/bin as a FUSE view of the PATH of whichever process is
  # asking, so a shebang resolves to whatever that process would have found.
  # /bin is bound to /usr/bin so both spellings work.
  services.envfs.enable = true;
}
