#!/usr/bin/env perl
# (c) Joerg Meyer @ Jogisoft, 2014-01-02 .. 2015-10-28, 2018-03-22, 2023-01-03, 2024-08-05
# Code copyrighted and shared under GPL v3.0

$PROGRAM = 'scangap.pl';
$VERSION = 'v0.31';

print "Luecken in Zahlenfolgen zeigen.\n";
exit if $ARGV[0] eq '-h';

$n = '';
$lzl = 0;
$luecke = $fehlen = 0;
$abschnitt = 1000;

while (<>) {
    chomp;

    next unless /[0-9]+/;
    if (/\t/) {
        $_ =~ /.*\t/;
    }

    if ($n eq '') {
        print 'Zeile ', $., ":\tBeginn mit Wert ", $_, ".\n";
    }
    elsif ($_ eq $n) {
        print 'Zeile ', $., ":\t++ Wert ",  $_, " ist wiederholt!\n";
    }
    elsif ($_ == $n + 1) {
        # Super. Nachfolger gefunden.
    }
    elsif ($_ < $n) {
        print 'Zeile ', $., ":\t++ Wert ", $_, " ist kleiner als Vorgaenger!\n";
    }
    else {
        $luecke++;
        if ($_ == $n + 2) {
            print 'Zeile ', $., ":\tWert  ", $_ - 1, " fehlt (1).\n";
            $fehlen++;
        }
        elsif ($_ == $n + 3) {
            print 'Zeile ', $., ":\tWerte ", $_ - 2, ' und ', $_ - 1, " fehlen (2).\n";
            $fehlen += 2;
        }
        elsif ($_ < $n + $abschnitt) {
            print 'Zeile ', $., ":\tWerte ", $n + 1, ' bis ', $_ - 1, ' fehlen (', $_ - $n - 1, ").\n";
            $fehlen += $_ - $n - 1;
        }
        elsif (/^\d+/){
            print 'Zeile ', $lzl, ":\tAbschnitt endet mit ", $n, ".\n",
                  'Zeile ', $., ":\tNeuer Abschnitt beginnt mit ", $_, ' (', $_ - $n - 1, ").\n";
            $fehlen += $_ - $n - 1;      
        }
        else {
            print 'Zeile ', $., ' nicht-numerischer Wert ', $n, ".\n";
	    $luecke--;
        }
    }
    $n = $_;
    $lzl = $.;
}
print 'Zeile ', $lzl, ":\tEnde mit Wert ", $n, ".\n";

print 'Fertig nach ', $luecke ? $luecke . ' Luecken in ' : 'Lueckenloses Ende nach ',
      $lzl, ' Zeilen',
      $fehlen ? ', ' . $fehlen . ' Zahlen fehlen' : '',
      ".\n";
