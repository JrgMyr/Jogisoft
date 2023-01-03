#!/usr/bin/env perl
# (c) Joerg Meyer @ Jogisoft, 2008-12-11, 2010-01-12, 2023-01-03
# Code copyrighted and shared under GPL v3.0

print "Zahlenfolgen in Intervallen zusammenfassen.\n";
exit if $ARGV[0] eq '-h';

$s = '';
$n = '';
$l = 0;

while (<>) {
    $l++;
    chomp;

    next unless /[0-9]+/;

    if ($s eq '') {
        $s = $_;
    }
    elsif ($n == $_) {
        print "Zeile $l:\tWiederholung: $n.\n";
    }
    elsif ($n+1 != $_) {
        print "Zeile $l:\tIntervall: $s bis $n.\n";
        $s = $_;
    }
    $n = $_;
}
print "Zeile $l:\tIntervall: $s bis $n.\n" if $s ne '';
print "Ende nach $l Zeilen \n";
