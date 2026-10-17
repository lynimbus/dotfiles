#!/usr/bin/env perl
# Inject the online-view translation hook into Claude's main-process bundle.
#
# The hook is appended to the existing `dom-ready` handler of the main view,
# so it runs on every load of the claude.ai page. The handler is located by
# scanning braces (the bundle nests callbacks), not by a regex.
use strict;
use warnings;
use JSON::PP;
use File::Temp qw(tempfile);
use FindBin qw($Bin);

my ($asar, $map_file, $script_tpl, $locale) = @ARGV;
die "usage: patch-asar.pl <app.asar> <map.json> <inject.tpl> <locale>\n" unless $asar && $map_file;

my $tool = "$Bin/asar-tool.pl";
my $files = run_list($asar);
my $target = find_target($asar, $files);
die "target bundle not found\n" unless $target;

my ($fh, $tmp) = tempfile(SUFFIX => '.js');
close $fh;
run("perl", $tool, 'extract', $asar, $target, $tmp);
my $text = slurp($tmp);

if (index($text, '/*__claudeZhOnlineLocaleMain*/') >= 0) {
    print "online locale hook already present\n";
    exit 0;
}

my $span = find_handler($text);
die "main view dom-ready handler not found\n" unless $span;
my $body = $span->{body};
my $contents = $span->{contents};
my $quote = $span->{quote};
my $terminator = $span->{terminator};
my $callback = $span->{wrapped} ? '(()=>{' : '()=>{';
my $close = $span->{wrapped} ? '}))' : '})';

my $mapping = slurp($map_file);
my $tpl = slurp($script_tpl);
$tpl =~ s/__LOCALES__/[ "zh-CN", "zh-TW" ]/;
$tpl =~ s/__MAP__/$mapping/;
my $inject = JSON::PP->new->utf8->canonical(1)->allow_nonref(1)->encode($tpl);

my $replacement = $contents . '.on(' . $quote . 'dom-ready' . $quote . ',' . $callback
    . $body . ';'
    . $contents . '.executeJavaScript(' . $inject . ').catch(()=>{})'
    . $close . $terminator . '/*__claudeZhOnlineLocaleMain*/';

substr($text, $span->{start}, $span->{end} - $span->{start}) = $replacement;
spew($tmp, $text);
run("perl", $tool, 'replace', $asar, $target, $tmp);
unlink $tmp;
print "online translation hook: $target\n";

# --- helpers -------------------------------------------------------------

sub run_list {
    my ($asar) = @_;
    my %entries;
    open my $fh, '-|', 'perl', $tool, 'list', $asar or die "list: $!";
    while (<$fh>) {
        chomp;
        my ($path, $size) = split /\t/, $_, 2;
        $entries{$path} = $size;
    }
    close $fh;
    return \%entries;
}

sub find_target {
    my ($asar, $files) = @_;
    my @candidates = grep { m{^\.vite/build/.*\.js$} } keys %$files;
    my @hits;
    for my $path (@candidates) {
        my ($fh, $tmp) = tempfile(SUFFIX => '.js');
        close $fh;
        run("perl", $tool, 'extract', $asar, $path, $tmp);
        my $text = slurp($tmp);
        unlink $tmp;
        next unless index($text, 'dom-ready') >= 0;
        next unless index($text, '.vite/build/mainView.js') >= 0;
        push @hits, $path if find_handler($text);
    }
    die "expected one main view dom-ready handler, found " . scalar(@hits) . "\n"
        if @hits != 1;
    return $hits[0];
}

sub find_handler {
    my ($text) = @_;
    my $head = qr/([A-Za-z_\$][A-Za-z0-9_\$]*\.webContents)\.on\((["'`])dom-ready\2,\s*/;
    while ($text =~ /$head/g) {
        my ($contents, $quote) = ($1, $2);
        my $start = $-[0];
        my $i = $+[0];
        my $wrapped = substr($text, $i, 1) eq '(' ? 1 : 0;
        $i++ if $wrapped;
        next unless substr($text, $i) =~ /\A\(\)\s*=>\s*\{/;
        $i += $+[0];
        my $body_start = $i;
        my $depth = 1;
        while ($i < length($text) && $depth) {
            my $c = substr($text, $i, 1);
            if ($c eq '"' || $c eq "'" || $c eq '`') {
                $i = skip_string($text, $i);
                next;
            }
            $depth++ if $c eq '{';
            $depth-- if $c eq '}';
            $i++;
        }
        my $body_end = $i - 1;
        $i++ if $wrapped && substr($text, $i, 1) eq ')';
        $i++ if substr($text, $i, 1) eq ')';
        my $term = substr($text, $i, 1);
        next unless $term eq ';' || $term eq ',';
        return {
            start    => $start,
            end      => $i + 1,   # consume the terminator; it is re-emitted below
            contents => $contents,
            quote    => $quote,
            body     => substr($text, $body_start, $body_end - $body_start),
            terminator => $term,
            wrapped  => $wrapped,
        };
    }
    return undef;
}

sub skip_string {
    my ($text, $i) = @_;
    my $q = substr($text, $i, 1);
    $i++;
    while ($i < length($text)) {
        my $c = substr($text, $i, 1);
        if ($c eq '\\') { $i += 2; next }
        return $i + 1 if $c eq $q;
        $i++;
    }
    return $i;
}

sub slurp {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "$path: $!";
    local $/;
    my $d = <$fh>;
    close $fh;
    return $d;
}

sub spew {
    my ($path, $data) = @_;
    open my $fh, '>:raw', $path or die "$path: $!";
    print $fh $data;
    close $fh;
}

sub run {
    system(@_) == 0 or die "command failed: @_\n";
}
