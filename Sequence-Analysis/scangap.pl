#!/usr/bin/env perl
# (c) Joerg Meyer @ Jogisoft, 2014-01-02 .. 2015-10-28, 2018-03-22, 2023-01-03
# Code copyrighted and shared under GPL v3.0

print "Luecken in Zahlenfolgen zeigen.\n";
exit if $ARGV[0] eq '-h';

$n = '';
$zl = $lzl = 0;
$luecke = 0;
$abschnitt = 1000;

while (<>) {
    $zl++;
    chomp;

    next unless /[0-9]+/;
    if (/\t/) {
        $_ =~ /.*\t/;
    }

    if ($n eq '') {
        print 'Zeile ', $zl, ":\tBeginn mit Wert ", $_, ".\n";
    }
    elsif ($_ eq $n) {
        print 'Zeile ', $zl, ":\t! Wiederholung ",  $_, "!\n";
    }
    elsif ($_ == $n + 1) {
        # Super. Nachfolger gefunden.
    }
    else {
        $luecke++;
        if ($_ == $n + 2) {
            print 'Zeile ', $zl, ":\tWert  ", $_ - 1, " fehlt.\n";
        }
        elsif ($_ == $n + 3) {
            print 'Zeile ', $zl, ":\tWerte ", $_ - 2, ' und ', $_ - 1, " fehlen.\n";
        }
        elsif ($_ < $n + $abschnitt) {
            print 'Zeile ', $zl, ":\tWerte ", $n + 1, ' bis ', $_ - 1, " fehlen.\n";
        }
        elsif (/^\d+/){
            print 'Zeile ', $lzl, ":\tAbschnitt endet mit ", $n, ".\n";
            print 'Zeile ', $zl, ":\tNeuer Abschnitt beginnt mit ", $_, ".\n";
        }
        else {
            print 'Zeile ', $zl, ' nicht-numerischer Wert ', $n, ".\n";
	    $luecke--;
        }
    }
    $n = $_;
    $lzl = $zl;
}
print 'Zeile ', $lzl, ":\tEnde mit Wert ", $n, ".\n";
print $luecke ? $luecke . ' Luecken in ' : 'Lueckenloses Ende nach ', $zl, " Zeilen.\n";
