#!/usr/bin/env perl
# (c) Joerg Meyer @ Jogisoft, 2008-12-11, 2015-10-26, 2023-01-03
# Code copyrighted and shared under GPL v3.0

print "Zahlenfolgen auf Luecken pruefen.\n";
exit if $ARGV[0] eq '-h';

$n = '';
$l = 0;

while (<>) {
    $l++;
    chomp;

    next unless /[0-9]+/;

    if ($n eq '') {
        print "Zeile $l:\tBeginn mit Wert $_.\n";
    }
    elsif ($n eq $_) {
        print "Zeile $l:\tWiederholung $n.\n";
    }
    elsif ($n+1 != $_) {
        print "Zeile $l:\tLuecke zwischen $n und $_.\n";
    }
    $n = $_;
}
print "Ende nach $l Zeilen mit Wert $n.\n";

