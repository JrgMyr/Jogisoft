#!/usr/bin/env perl
# (c) Joerg Meyer @ Jogisoft, 2008-12-11, 2010-01-12, 2023-01-04
# Code copyrighted and shared under GPL v3.0

$PROGRAM = 'scanint.pl';
$VERSION = 'v0.31';

print "Zahlenfolgen in Intervallen zusammenfassen.\n";
exit if $ARGV[0] eq '-h';

$s = '';
$n = '';

while (<>) {
    chomp;
    next if /^ *$/;
    if (/[^0-9]/) {
        print 'Zeile ', $., ":\tNicht-numerischer Inhalt! '", $_, "'\n";
        next;
    }

    if ($s eq '') {
        $s = $_;
    }
    elsif ($n == $_) {
        print 'Zeile ', $., ":\tWiederholung: ", $n, ".\n";
    }
    elsif ($n+1 != $_) {
        print 'Zeile ', $., ":\tIntervall: ", $s, ' bis ', $n, ".\n";
        $s = $_;
    }
    $n = $_;
}
print "Zeile $.:\tIntervall: $s bis $n.\n" if $s ne '';
print "Ende nach $. Zeilen \n";
