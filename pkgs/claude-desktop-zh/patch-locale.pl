#!/usr/bin/env perl
# Teach the desktop main process about the added locale: its hardcoded map and
# catalog list only know the shipped codes, so the extra catalog would never be
# selected. A stored user choice always wins; the added locale is only the
# default for a fresh profile.
use strict;
use warnings;
use File::Temp qw(tempfile);
use FindBin qw($Bin);

my ($asar, $locale) = @ARGV;
die "usage: patch-locale.pl <app.asar> <locale>\n" unless $asar && $locale;

my $tool = "$Bin/asar-tool.pl";
my @entries;
open my $fh, '-|', 'perl', $tool, 'list', $asar or die "list: $!";
while (<$fh>) {
    chomp;
    my ($path) = split /\t/, $_, 2;
    push @entries, $path if $path =~ m{^\.vite/build/.*\.js$};
}
close $fh;

my $lang = $locale;
$lang =~ s/-.*//;
my $marker = qq{$lang:"$locale"};

for my $path (@entries) {
    my ($tfh, $tmp) = tempfile(SUFFIX => '.js');
    close $tfh;
    system('perl', $tool, 'extract', $asar, $path, $tmp) == 0 or die "extract failed\n";
    open my $in, '<:raw', $tmp or die "$tmp: $!";
    local $/;
    my $text = <$in>;
    close $in;
    my $original = $text;

    if ($text =~ /zpt=\{en:"en-US"[^}]*\}/) {
        my $map = $&;
        my $patched = $map;
        $patched =~ s/\}$/,$marker}/;
        $text =~ s/\Q$map\E/$patched/;
    }
    if ($text =~ /\["en-US","de-DE","fr-FR","ko-KR","ja-JP","es-419","es-ES","it-IT","hi-IN","pt-BR","id-ID"(?:,"zh-(?:CN|TW)")*\]/) {
        my $list = $&;
        (my $patched = $list) =~ s/\]$/,"$locale"]/;
        $text =~ s/\Q$list\E/$patched/;
    }
    if ($text =~ /let e=uo\.get\("locale"\);Upt=e,Qpt\(e!==void 0&&Xpt\(\)\.includes\(e\)\?e:Jpt\(\)\)/) {
        my $orig = $&;
        (my $patched = $orig) =~ s/:Jpt\(\)\)/:"$locale")/;
        $text =~ s/\Q$orig\E/$patched/;
    }

    if ($text ne $original) {
        open my $out, '>:raw', $tmp or die "$tmp: $!";
        print $out $text;
        close $out;
        system('perl', $tool, 'replace', $asar, $path, $tmp) == 0 or die "replace failed\n";
        print "main process locale map: $path\n";
    }
    unlink $tmp;
}
