{ ... }:

{
  # NixOS normally links every file in /etc to a read-only store path under
  # /etc/static, so nothing you edit survives a rebuild and a file the system
  # does not manage cannot exist at all.
  #
  # An overlay keeps the generated tree as the read-only lower layer and puts
  # your edits in a writable upper layer at /.rw-etc/upper. Edits survive
  # reboots, an upgrade rewrites only the lower layer, and deleting the file in
  # the upper layer returns it to the generated version.
  system.etc.overlay = {
    enable = true;
    mutable = true;
  };
}
