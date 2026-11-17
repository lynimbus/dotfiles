{ ... }:

{
  # Blackhole's Docker backend can only reach the internet through one HTTP
  # proxy: it builds an internal-only network whose single relay dials this
  # address, and a session that cannot reach it fails closed instead of falling
  # back to direct access. That address is this host's sing-box mixed inbound,
  # firewalled to the docker bridge in system/docker.nix. Without it a session
  # container has no route to api.anthropic.com, which the TUN does not let
  # through directly.
  home.sessionVariables.BLACKHOLE_PROXY = "http://host.docker.internal:7890";
}
