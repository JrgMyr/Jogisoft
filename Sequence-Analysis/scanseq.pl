#!/usr/bin/env perl
# (c) Joerg Meyer @ Jogisoft, 2008-12-11, 2015-10-26, 2023-01-04
# Code copyrighted and shared under GPL v3.0

$PROGRAM = 'scanseq.pl';
$VERSION = 'v0.31';

print "Zahlenfolgen auf Luecken pruefen.\n";
exit if $ARGV[0] eq '-h';

$n = '';

while (<>) {
    chomp;
    next if /^ *$/;
    if (/[^0-9]/) {
        print 'Zeile ', $., ":\tNicht-numerischer Inhalt! '", $_, "'\n";
        next;
    }

    if ($n eq '') {
        print "Zeile $.:\tBeginn mit Wert $_.\n";
    }
    elsif ($_ eq $n) {
        print "Zeile $.:\tWiederholung $n.\n";
    }
    elsif ($_ < $n) {
        print "Zeile $.:\tFalsche Reihenfolge mit Wert $_.\n";
    }
    elsif ($_ > $n+1) {
        print "Zeile $.:\tLuecke zwischen $n und $_.\n";
    }
    $n = $_;
}
print "Ende nach $. Zeilen mit Wert $n.\n";
