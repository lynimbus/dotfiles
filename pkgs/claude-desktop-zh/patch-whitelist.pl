#!/usr/bin/env perl
# Register the added locales in the renderer's hardcoded language whitelist.
# Only codes present in that literal array are accepted at runtime.
use strict;
use warnings;

my ($assets_dir, @locales) = @ARGV;
die "usage: patch-whitelist.pl <assets/v1> <locale>...\n" unless $assets_dir && @locales;

my $prefix = '["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"';
my $suffix = join('', map { qq(,"$_") } @locales);
my $pattern = qr/\Q$prefix\E(?:,"zh-(?:CN|TW|HK)")*\]/;

for my $path (sort glob("$assets_dir/*.js")) {
    open my $fh, '<:raw', $path or next;
    local $/;
    my $text = <$fh>;
    close $fh;
    next unless $text =~ $pattern;
    my $count = ($text =~ s/$pattern/$prefix$suffix]/g);
    open my $out, '>:raw', $path or die "$path: $!";
    print $out $text;
    close $out;
    print "language whitelist: " . ($path =~ m{([^/]+)$})[0] . " ($count occurrence(s))\n";
    exit 0;
}
die "language whitelist anchor not found; the bundle layout changed\n";
