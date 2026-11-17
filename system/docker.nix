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

  # sing-box's TUN intercepts forwarded Docker traffic and every container
  # connection dies at the first SYN, so image builds (apt, npm) hang and a
  # session that is not on the proxy has no network at all. Marking the bridge
  # subnet with the mark the interception already honours lets those packets
  # take the plain route instead; the containers then reach the internet, and
  # 172.17.0.1 stays reachable from them, which is what the proxy below needs.
  # 0x2024 is sing-box's own constant: `nft list chain inet sing-box
  # prerouting_prematch` shows it on the rule that returns early. If container
  # egress breaks after a sing-box upgrade, that is the line to re-read.
  networking.firewall.extraCommands = ''
    iptables -t mangle -C PREROUTING -s 172.17.0.0/16 -j MARK --set-xmark 0x2024/0x2027 2>/dev/null \
      || iptables -t mangle -A PREROUTING -s 172.17.0.0/16 -j MARK --set-xmark 0x2024/0x2027
  '';

  # The other direction: sessions go through sing-box's mixed inbound on the
  # bridge gateway (home/programs/blackhole.nix points BLACKHOLE_PROXY at it),
  # and the daemon would drop that packet at INPUT. Scoping the rule to docker0
  # keeps 7890 shut on the wireless interface.
  networking.firewall.interfaces."docker0".allowedTCPPorts = [ 7890 ];
}
