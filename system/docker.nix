{ username, ... }:

{
  # Blackhole runs Claude Code in a container that mounts only the project it
  # was started in. It needs a rootful engine: its entrypoint maps the project's
  # UID onto the container's node user, and it refuses a rootless daemon because
  # that maps the files to UID 0 instead.
  virtualisation.docker.enable = true;

  # The module creates the docker group and puts nobody in it. Without the
  # membership the socket is only reachable through sudo, which the launcher
  # rejects just as firmly as rootless: sudo would hand the project to root.
  users.users.${username}.extraGroups = [ "docker" ];
}
