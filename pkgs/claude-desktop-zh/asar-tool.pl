#!/usr/bin/env perl
# Read and rewrite Electron app.asar files without Node.js.
#
# Layout: [u32 size-pickle=4][u32 header-size][header-pickle][content...]
# header-pickle: [u32 payload-size][i32 json-length][json...][padding to 4]
# Files live at 8 + header-size + offset; replacing one file shifts every
# later offset by the size delta, so the header is rewritten in place.
use strict;
use warnings;
use JSON::PP;
use Digest::SHA qw(sha256_hex);

my $cmd = shift @ARGV // usage();
if ($cmd eq 'list') {
    my ($asar) = @ARGV;
    my ($data, $hsize, $header) = read_asar($asar);
    my $files = flatten($header);
    print "$_\t" . $files->{$_}{size} . "\n" for sort keys %$files;
} elsif ($cmd eq 'extract') {
    my ($asar, $entry, $out) = @ARGV;
    my ($data, $hsize, $header) = read_asar($asar);
    my $node = entry_for($header, $entry) or die "no such entry: $entry\n";
    write_file($out, substr($data, 8 + $hsize + $node->{offset}, $node->{size}));
} elsif ($cmd eq 'replace') {
    my ($asar, $entry, $new) = @ARGV;
    my ($data, $hsize, $header) = read_asar($asar);
    my $node = entry_for($header, $entry) or die "no such entry: $entry\n";
    my $into = read_file($new);
    my $old = substr($data, 8 + $hsize + $node->{offset}, $node->{size});
    exit 0 if $old eq $into;

    my $delta = length($into) - length($old);
    my $body = substr($data, 8 + $hsize);
    substr($body, $node->{offset}, length($old)) = $into;
    my $files = flatten($header);
    for my $other (values %$files) {
        next if $other == $node;
        $other->{offset} = int($other->{offset}) + $delta
            if int($other->{offset}) > int($node->{offset});
    }
    $node->{size} = length($into);
    $node->{integrity} = integrity($into);

    # asar's loader expects every offset to stay a string, as the original
    # header has it; a JSON number makes the header fail to load silently.
    for my $other (values %$files) {
        $other->{offset} = "$other->{offset}";
    }

    my $json = JSON::PP->new->utf8->canonical(0)->encode($header);
    my $payload = pack('V', align4(4 + length($json))) . pack('l<', length($json)) . $json;
    $payload .= "\0" x (align4(length($payload)) - length($payload));
    write_file($asar, pack('V', 4) . pack('V', length($payload)) . $payload . $body);
} elsif ($cmd eq 'delete') {
    my ($asar, @entries) = @ARGV;
    my ($data, $hsize, $header) = read_asar($asar);
    my $files = flatten($header);
    my @remove = grep { exists $files->{$_} } @entries;
    exit 0 unless @remove;

    # Drop entries from the header and rebuild the content area without them.
    my %drop = map { $_ => 1 } @remove;
    remove_nodes($header, \%drop);
    my $body = substr($data, 8 + $hsize);
    my $out = '';
    for my $entry (sort { int($files->{$a}{offset}) <=> int($files->{$b}{offset}) } keys %$files) {
        next if $drop{$entry};
        $out .= substr($body, $files->{$entry}{offset}, $files->{$entry}{size});
    }
    my $pos = 0;
    for my $entry (sort { int($files->{$a}{offset}) <=> int($files->{$b}{offset}) } keys %$files) {
        next if $drop{$entry};
        $files->{$entry}{offset} = "$pos";
        $pos += $files->{$entry}{size};
    }
    my $json = JSON::PP->new->utf8->canonical(0)->encode($header);
    my $payload = pack('V', align4(4 + length($json))) . pack('l<', length($json)) . $json;
    $payload .= "\0" x (align4(length($payload)) - length($payload));
    write_file($asar, pack('V', 4) . pack('V', length($payload)) . $payload . $out);
} else {
    usage();
}

sub remove_nodes {
    my ($node, $drop, $prefix) = @_;
    $prefix //= '';
    for my $name (keys %{ $node->{files} // {} }) {
        my $path = length($prefix) ? "$prefix/$name" : $name;
        if ($drop->{$path}) {
            delete $node->{files}{$name};
        } elsif (exists $node->{files}{$name}{files}) {
            remove_nodes($node->{files}{$name}, $drop, $path);
        }
    }
}

sub flatten {
    my ($node) = @_;
    my %out;
    my @stack = (['', $node]);
    while (@stack) {
        my ($prefix, $cur) = @{ pop @stack };
        for my $name (keys %{ $cur->{files} // {} }) {
            my $path = length($prefix) ? "$prefix/$name" : $name;
            my $child = $cur->{files}{$name};
            if (exists $child->{files}) {
                push @stack, [$path, $child];
            } elsif (exists $child->{offset}) {
                $out{$path} = $child;
            }
        }
    }
    \%out;
}

sub entry_for {
    my ($header, $path) = @_;
    my $node = $header;
    for my $part (split m{/}, $path) {
        return undef unless exists $node->{files}{$part};
        $node = $node->{files}{$part};
    }
    $node;
}

sub integrity {
    my ($bytes) = @_;
    my @blocks;
    for (my $i = 0; $i < length($bytes); $i += 4194304) {
        push @blocks, sha256_hex(substr($bytes, $i, 4194304));
    }
    @blocks = (sha256_hex($bytes)) unless @blocks;
    return {
        algorithm => 'SHA256',
        hash      => sha256_hex($bytes),
        blockSize => 4194304,
        blocks    => \@blocks,
    };
}

sub align4 {
    my $n = shift;
    return $n + ((4 - $n % 4) % 4);
}

sub read_asar {
    my ($path) = @_;
    my $data = read_file($path);
    die "short asar\n" if length($data) < 16;
    my $hsize = unpack('V', substr($data, 4, 4));
    my $payload = substr($data, 8, $hsize);
    my $jlen = unpack('l<', substr($payload, 4, 4));
    my $json = substr($payload, 8, $jlen);
    return ($data, $hsize, JSON::PP->new->utf8->decode($json));
}

sub read_file {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "$path: $!";
    local $/;
    my $data = <$fh>;
    close $fh;
    return $data;
}

sub write_file {
    my ($path, $data) = @_;
    open my $fh, '>:raw', $path or die "$path: $!";
    print $fh $data;
    close $fh;
}

sub usage {
    die <<'USAGE';
usage: asar-tool.pl list <app.asar>
       asar-tool.pl extract <app.asar> <entry> <out>
       asar-tool.pl replace <app.asar> <entry> <file>
USAGE
}
