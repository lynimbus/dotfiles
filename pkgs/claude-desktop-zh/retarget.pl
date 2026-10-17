#!/usr/bin/env perl
# Point the copied launcher and desktop entries at the patched tree.
#
# The upstream package builds them against its own store path, and `cp -a`
# keeps those absolute references; left alone the wrapper would start the
# unpatched application.
use strict;
use warnings;
use File::Find;

my ($out, $old) = @ARGV;
die "usage: retarget.pl <out> <old-store-path>\n" unless $out && $old;

my @files = ("$out/bin/claude-desktop");
find(
    sub {
        push @files, $File::Find::name if -f $_ && !-l $_;
    },
    "$out/share"
);

for my $path (@files) {
    next unless -f $path && !-l $path;
    open my $fh, '<:raw', $path or next;
    local $/;
    my $text = <$fh>;
    close $fh;
    next unless index($text, $old) >= 0;
    $text =~ s/\Q$old\E/$out/g;
    open my $out_fh, '>:raw', $path or die "$path: $!";
    print $out_fh $text;
    close $out_fh;
}
