#!/usr/bin/env perl
# (c) Joerg Meyer, 2005-10-31 ... 2021-09-17, 2022-01-03, 2022-02-10, 2022-09-01, 2022-12-23, 2023-01-10
# Code copyrighted and shared under GPL v3.0
# mailto:info@jogisoft.de

$PROGRAM = 'analyzeCSV.pl';
$VERSION = 'V1.01';
$DESCRPT = 'Struktur einer Datei mit separierten Feldinhalten ermitteln.';

sub usage {
    print 'Usage: ', $PROGRAM, " [Parameter] [Datei]\n",
          $DESCRPT, "\n\n",
          "Parameter:\n",
          "\t-a\tAusfuehrliche Textmeldungen\n",
          "\t-c\tErzeuge SQL CREATE-Statment\n",
          "\t-d\tDOS-Zeilenenden <CRLF>\n",
          "\t-e\tAbbruch nach dem zehnten Fehler\n",
          "\t-f\tTitelzeile aus Datei (file) lesen\n",
          "\t-g\tGenauigkeit beim Zaehlen der Felder (n)\n",
          "\t-h\tDiese Hilfe ausgeben\n",
          "\t-l\tLaengste Zeile anzeigen\n",
          "\t-m\tZeilen aus nur Minuszeichen NICHT ueberspringen\n",
          "\t-n\tTrenner in Anfuehrungsstrichen ueberspringen (normal)\n",
          "\t-p\tAlle Trenner beruecksichtigen (pedantisch)\n",
          "\t-q\tKeine Textmeldungen\n",
          "\t-s\t(zchn) Angabe Feldtrenner\n",
          "\t-t\tTitel in Zeile (n)\n",
          "\t-u\tUNIX-Zeilenenden <LF>\n",
          "\t-w\tWertestatistik ausgeben\n",
          "\t-v\tVersion anzeigen\n";
    exit;
}

if (@ARGV == 0) {
    die $PROGRAM, ": Keine Parameter und keine Datei angegeben!\n\n";
}

%Feldtrennername = ("\t" => 'Tabulator',
                    '\|' => 'Pipe-Symbol',
                    ';'  => 'Semikolon',
                    ':'  => 'Doppelpunkt',
                    ','  => 'Komma',
                    '\*' => 'Stern-Symbol',
                    '\+' => 'Plus-Zeichen',
                    '\.' => 'Punkt',
                    '~'  => 'Tilde');

$DATEINAME = $STATNAME = $FELDTRENNER = $TITELFILE = '';
$TITELZEILE = 0;
$SKIPLINIEN = 1;
$FELDERMINDERZAHL = 1;
$FELDBEGRENZER = '"';
$MITBEGRENZER = $ZAEHLEWERTE = $BREAKONERROR = $CREATESQL = 0;
$AUSFUEHRL = $STUMM = $NextParmTitel = $NextParmTrenner = 0;
$NextParmTFile = $NextParmGenau = $PEDANTISCH = $ZEIGLANG = 0;
$MIO = 1000000;
$miolauf = $miozaehl = $laengste = $laengnum = 0;

foreach (@ARGV) {
    if (substr($_, 0, 1) eq '-') {
        m/a/ && ($AUSFUEHRL = 1);
        m/c/ && ($CREATESQL = 1);
        m/d/ && ($/ = "\r\n");
        m/e/ && ($BREAKONERROR = 1);
        m/f/ && ($NextParmTFile = 1);
        m/g/ && ($NextParmGenau = 1);
        m/h/ && &usage;
        m/l/ && ($ZEIGLANG = 1);
        m/m/ && ($SKIPLINIEN = 0);
        m/n/ && ($PEDANTISCH = 0);
        m/p/ && ($PEDANTISCH = 1);
        m/q/ && ($STUMM = 1);
        m/s/ && ($NextParmTrenner = 1);
        m/t/ && ($NextParmTitel = 1);
        m/u/ && ($/ = "\n");
        m/v/ && die $PROGRAM, ' -- ', $VERSION, "\n";
        m/w/ && ($ZAEHLEWERTE = 1);
    }
    else {
        if ($NextParmTrenner) {
            $FELDTRENNER = $_;
            $NextParmTrenner = 0;
        }
        elsif ($NextParmTitel) {
            die "Anzahl Titelzeilen '$_' nicht lesbar\n" unless m/\d+/;
            $TITELZEILE = $_;
            $NextParmTitel = 0;
        }
        elsif ($NextParmTFile) {
            $TITELFILE = $_;
            $NextParmTFile = 0;
        }
        elsif ($NextParmGenau) {
            $FELDERMINDERZAHL = $_;
            $NextParmGenau = 0;
        }
        elsif ($DATEINAME eq '') {
            $DATEINAME = $_;
        }
        else {
            print "Bitte nur einen Dateinamen angeben!\n";
        }
    }
}

print $DESCRPT, "\n" unless $STUMM;

$FELDTRENNER = "\t" if $FELDTRENNER eq 'tab';
$FELDTRENNER = "\n" if $FELDTRENNER eq '\n';
$FELDTRENNER = '\|' if $FELDTRENNER eq '|';
$FELDTRENNER = '\*' if $FELDTRENNER eq '*';
$FELDTRENNER = '\+' if $FELDTRENNER eq '+';
$FELDTRENNER = '\.' if $FELDTRENNER eq '.';
$FELDTRENNER = '\?' if $FELDTRENNER eq '?';

if ($DATEINAME eq '') {
    print "-- Lese von Standard-Input\n" unless $STUMM;
    open(INP, '-');  # STDIN
    $DATEINAME = $PROGRAM;
}
else {
    print '-- Lese Datei ', $DATEINAME, "\n" unless $STUMM;
    open(INP, '<' . $DATEINAME) || die "$DATEINAME ... geht nicht auf!\n";
}

if ($PEDANTISCH) {
    print '-- Zaehle Trenner auch innerhalb Anfuehrungsstrichen!', "\n"
        unless $STUMM;
}
else {
    print '-- Trenner innerhalb Anfuehrungsstrichen werden nicht gewertet.', "\n"
        if $AUSFUEHRL;
}        

if ($ZAEHLEWERTE) {
    ($STATNAME = $DATEINAME) =~ s|^.*[/\\]||;
    $STATNAME = 'stat_' . $STATNAME . '.txt';
    $STATNAME =~ s/\.csv\.txt$/.txt/i;
    $STATNAME =~ s/\.txt\.txt$/.txt/i;
    print '-- Schreibe Statistik in Datei >', $STATNAME, "<\n" unless $STUMM;
}

if ($CREATESQL) {
    ($SQLNAME = $DATEINAME) =~ s|^.*[/\\]||;
    $SQLNAME = 'create_'. $SQLNAME . '.sql';
    $SQLNAME =~ s/\.csv\.sql$/.sql/i;
    $SQLNAME =~ s/\.txt\.sql$/.sql/i;
    print '-- Erzeuge SQL CREATE-Statement in Datei >', $SQLNAME, "<\n" unless $STUMM;
}

@feldnamen  = ();
@feldtyp    = ();
@feldbreite = ();
@feldleer   = ();
@feldmlen   = ();
@feldlenpos = ();
@feldmin    = ();
@feldmax    = ();
@feldval    = ();
@feldkomm   = ();
$feldanzahl = 0;

$zeilen = $datenzeilen = $fehler = 0;

if ($TITELZEILE > 0 or $TITELFILE ne '') {
    $TITELZEILE = 1 if $TITELZEILE == 0;

    if ($TITELFILE ne '') {
        print "-- Titel sind in Datei ", $TITELFILE unless $STUMM;
        open(TFL, '<' . $TITELFILE) || die "Kann Titeldatei nicht oeffnen!\n";
        $t = <TFL> for (1 .. $TITELZEILE);
        close TFL;
    }
    else {
        print "-- Titel sind in Zeile ", $TITELZEILE unless $STUMM;
        $t = <INP> for (1 .. $TITELZEILE);
    }
    chomp $t;

    print "\t'", $t, "'\n" if $AUSFUEHRL and ($TITELZEILE > 1);

    if ($FELDTRENNER eq '') {
        foreach $ftr (keys %Feldtrennername) {
            if ($t =~ m/$ftr/) {
                $FELDTRENNER = $ftr;
                last;
            }
        }
    }

    @feldnamen = split($FELDTRENNER, $t);
    foreach (@feldnamen) { s/\s+$//; }
    foreach (@feldnamen) { push @feldtyp, '-'; }
    $feldanzahl = scalar @feldnamen;

    print ' und bestehen aus ', $feldanzahl, " Feldern.\n" unless $STUMM;
}
else {
    print "-- Keine Titelzeile\n" unless $STUMM;
}

die "Kein Feldtrenner erkennbar oder angegeben!\n" if $FELDTRENNER eq '';
print '-- Feldtrenner ist ',
      exists $Feldtrennername{$FELDTRENNER} ?
          $Feldtrennername{$FELDTRENNER} :
          "'" . $FELDTRENNER . "'",
      ".\n" unless $STUMM;

# Pipe-Symbol darf fuer direkten Vergleich nicht geschuetzt sein, für split-Aufruf muss das bleiben.
$FELDTRENNER = '|' if ($FELDTRENNER eq '\|' && !$PEDANTISCH);

while (<INP>) {
    chomp;
    $zeilen++;
    if ($ZEIGLANG) {
        if (length($_) > $laengste) {
            $laengste = length($_);
            $laengnum = $zeilen + $TITELZEILE;
        }
    }

    if ($AUSFUEHRL) {
        $miolauf++;

        if ($miolauf == $MIO) {
            $miozaehl++;
            $miolauf = 0;
            print '++ ',
                  $miozaehl == 1 ? 'Eine Million' : $miozaehl . ' Millionen',
                  ' Zeilen gelesen', "\n",
        }
    }

    if (/^\s*$/) {
        print '-- Zeile ', $zeilen, " ist leer.\n" unless $STUMM;
        next;
    }

    next if $SKIPLINIEN and m/^\s*-+$/;

    $datenzeilen++;

    if ($PEDANTISCH) {
        @daten = split($FELDTRENNER, $_);
    }
    else {
        $InAnfStr = $j = 0;
        @daten = ();
        foreach $i (0 .. length($_)-1) {
            $z = substr($_, $i, 1);

            $InAnfStr = !$InAnfStr if $z eq '"';
            if ($z eq $FELDTRENNER and !$InAnfStr) {
                if (substr($_, $j, 1) eq '"' and
                    substr($_, $i-1, 1) eq '"') {
                    push @daten, substr($_, $j+1, $i-$j-2);
                }
                else {
                    push @daten, substr($_, $j, $i-$j);
                }
                $j = $i+1;
            }
        }
        push @daten, substr($_, $j, length($_)-$j);
    }

    if ($feldanzahl - $FELDERMINDERZAHL != $#daten and not $STUMM) {
        print '>> Zeile ', ($TITELZEILE + $zeilen), ' hat ',
            scalar(@daten), ' Feld(er), anstatt ', $feldanzahl, "\n";
        $fehler++;
    }

#   $feldanzahl = $#daten + 1 if $feldanzahl <= $#daten;

    $feld = 0;
    foreach (@daten) {
        if (not defined $feldnamen[$feld]) {
            $feldnamen[$feld] = 'Feld_' . ($feld+1);
            $feldkomm[$feld] = 'Zl. ' . $zeilen . ': Neues Feld'
                unless ($TITELZEILE == 0) && ($zeilen == 1);
            $feldtyp[$feld] = '-';
            $fehler++;
            print '-- Zeile ', $zeilen, ' hat ', 1 + scalar @daten, ' Felder oder ',
                  "Feldtrenner in einem Datenfeld\n"
                if $BREAKONERROR;
        }

        $feldbreite[$feld] = length($_) if length($_) > $feldbreite[$feld];

        if (substr($_, 0, 1) eq $FELDBEGRENZER and
            substr($_, -1, 1) eq $FELDBEGRENZER) {

            if (! $MITBEGRENZER) {
                $MITBEGRENZER = 1;
                print '-- Datei enthaelt Feldbegrenzer ab Zeile ', 
              $TITELZEILE + $zeilen, "\n"
                    unless $STUMM;
            }

            $_ = substr($_, 1, -1);

#           (m/$FELDBEGRENZER/) &&
#               ($feldkomm[$feld] = 'Zl. ' . $zeilen . ': Feldbegr. im Feld!');
        }

        s/^\s+//;
        s/\s+$//;
        $aktTyp = $_ eq '' ? '-' : '?';
        $aktTyp = 'Z' if m/^\d{1,4}([.\/\-])\d\d?\1\d{1,4} *\d?\d:\d\d/;
        $aktTyp = 'U' if m/^\d\d:\d\d:\d\d,?\d*$/;
        $aktTyp = 'R' if m/^-?[0-9.,]+$/;
        $aktTyp = 'D' if m/^\d{1,4}([.\/\-])\d\d?\1\d{1,4}$/;
        $aktTyp = 'I' if m/^-?\d+$/;
        $aktTyp = 'L' if m/^-?\d{10,}$/;
        $aktTyp = 'T' if m/[A-Za-z]/;
        $aktTyp = 'P' if m/^[12]\d\d\d-\d\d$/;

        if ($aktTyp eq $feldtyp[$feld]) {
        }
        else {
            if ($feldtyp[$feld] ne 'T' and
                $feldkomm[$feld] eq '') {
                $feldkomm[$feld] = 'Zl. ' . ($zeilen + $TITELZEILE) . ' '.
                                   $feldtyp[$feld] . '~' . $aktTyp . ': ' .
                                   substr($daten[$feld], 0, 10)
                    unless $feldtyp[$feld] eq '-' or
                           $feldtyp[$feld] eq 'T' or
                           $aktTyp eq '-';
            }
            $feldtyp[$feld] = $aktTyp
                unless $feldtyp[$feld] eq 'T' or
                       aktTyp eq '-';
        }

        if (length($_) > $feldmlen[$feld]) {
            $feldmlen[$feld] = length($_);
            $feldlenpos[$feld] = $zeilen + $TITELZEILE;
        }

        if ($ZAEHLEWERTE) {
            if ($_ eq '') {
                $feldleer[$feld]++;
            }
            else {
                if ($feldtyp[$feld] eq 'I' or
                    $feldtyp[$feld] eq 'R' or
                    $feldtyp[$feld] eq 'D') {

                    if ($feldtyp[$feld] eq 'D' and
                            (substr($_, 5, 1) eq '.') or
                            (substr($_, 5, 1) eq '-') or
                            (substr($_, 5, 1) eq '/')) {
  
                        $_ = substr($_, 6, 4) . '-' .
                             substr($_, 3, 2) . '-' .
                             substr($_, 0, 2);
                    }

                    $feldmax[$feld] = $_ if $_ > $feldmax[$feld];

                    $feldmin[$feld] = $_ if $_ < $feldmin[$feld] or
                                            not defined $feldmin[$feld];
                }
                else {
                    $feldmax[$feld] = $_ if $_ gt $feldmax[$feld];

                    $feldmin[$feld] = $_ if $_ lt $feldmin[$feld] or
                                            not defined $feldmin[$feld];
                }
                $feldval[$feld]->{$_}++;
            }
        }
        $feld++;
    }
    last if $BREAKONERROR and ($fehler > 9);
}

close INP;

print "\n" unless $STUMM;

$FORMSTR = "%3s  %30s%2s%3s  %3s  %3s  %-24s\n";
printf $FORMSTR, 'Lfd', 'Feldname', '', 'Typ', 'Brt', 'Len', 'Hinweis';
$TRENNSTR = sprintf $FORMSTR, '---', '-' x 30, '', '---', '---', '---', '-' x 15;
print $TRENNSTR;

$feld = 0;
foreach (@feldnamen) {
    printf $FORMSTR,
           $feld + 1,
           substr($feldnamen[$feld], 0, 30),
           length($feldnamen[$feld]) > 30 ? '>>' : '  ',
           $feldtyp[$feld],
           $feldbreite[$feld] || '0',
           $feldmlen[$feld] || '-',
           substr($feldkomm[$feld], 0, 24);

    $feld++;
}

print $TRENNSTR;

if ($ZAEHLEWERTE) {

    open(OUT, '>' . $STATNAME) || die "$STATNAME ... geht nicht auf!\n";

    $FORMSTR = "%3s  %30s%2s%3s %4s %4s %6s %6s  %6s  %-40s%2s%6s%1s%7s  %-15s  %-24s\n";
    printf OUT $FORMSTR, 'Lfd', 'Feldname', '', 'Typ', 'Brt', 'Len', 'Zeile', 'Inhalt', 'Leer',
                         'Wertebereich', '', 'WrtVor', '', 'HWrtAnz', 'HWrtInhalt', 'Hinweis';
    $TRENNSTR = sprintf $FORMSTR, '---', '-' x 30, '', '---', '---', '---', '------', '------',
                         '------', '-' x 40, '', '------', '', '-------', '-' x 15, '-' x 15;
    print OUT $TRENNSTR;

    $feld = 0;
    foreach (@feldnamen) {

        $hwert_inh = '';
        $hwert_anz = 0;

        foreach (keys %{$feldval[$feld]}) {
            if ($feldval[$feld]->{$_} > $hwert_anz) {
                $hwert_inh = $_;
                $hwert_anz = $feldval[$feld]->{$_};
            }
        }

        if ($feldtyp[$feld] eq '-') {
            $t = '';
        }
        else {
            $t = substr($feldmin[$feld], 0, 18);
            $n = scalar keys %{$feldval[$feld]};
 
            if ($n == 1) {}
            elsif ($n < 7) {
                $t = join(', ', sort keys %{$feldval[$feld]});
            }    
            else {
                if ($feldtyp[$feld] eq 'I') {
                    if ($feldmin[$feld] <  $feldmax[$feld]) {
                        $t .= ' .. ' . substr($feldmax[$feld], 0, 18);
                    }
                }
                else {
                    if ($feldmin[$feld] lt $feldmax[$feld]) {
                        $t .= ' .. ' . substr($feldmax[$feld], 0, 18);
                    }
                }
            }
        }

        printf OUT $FORMSTR,
            $feld + 1,
            substr($feldnamen[$feld], 0, 30),
            length($feldnamen[$feld]) > 30 ? '>>' : '',
            $feldtyp[$feld],
            $feldbreite[$feld] || '0',
            $feldmlen[$feld] || '-',
            $feldlenpos[$feld] || '-',
            $feldtyp[$feld] eq '-' ? '' : $datenzeilen - $feldleer[$feld],
            $feldtyp[$feld] eq '-' ? '' : $feldleer[$feld] || '0',
            substr($t, 0, 40),
            length($t) > 40 ? '>>' : '',
            $feldtyp[$feld] eq '-' ? '' : scalar keys %{$feldval[$feld]},
            scalar keys %{$feldval[$feld]} == $datenzeilen ? '!' : ' ',
            $feldtyp[$feld] eq '-' ? '' : $hwert_anz,
            $hwert_anz == 1 ? '' : substr($hwert_inh, 0, 15),

            substr($feldkomm[$feld], 0, 25);

        $feld++;
    }
    print OUT $TRENNSTR;
    print OUT 'Zeile ', $laengnum, ' war mit ', $laengste, " Stellen am laengsten.\n" if $ZEIGLANG;
    print OUT 'Fertig nach ', $datenzeilen, ' Datenzeilen in ', 
        $TITELZEILE+$zeilen, " Dateizeilen.\n";

    close OUT;
}

if ($CREATESQL) {

    %feldtypname = ('T' => 'TEXT',
                    'I' => 'INTEGER',
                    'R' => 'DECIMAL',
                    'L' => 'BIGINT',
                    'D' => 'DATE',
                    'U' => 'TIME',
                    'Z' => 'DATETIME',
                    'P' => 'TEXT',
                    '?' => 'BLOB',
                    '-' => 'NONE');

    open(OUT, '>' . $SQLNAME) || die "$SQLNAME ... geht nicht auf!\n";
    
    $SQLNAME =~ s/^create_//;
    $SQLNAME =~ s/\.sql$//;
    $SQLNAME =~ s/^rep_//;
    
    print OUT 'CREATE TABLE ', $SQLNAME, " (\n";
    
    $feld = 0;
    foreach (@feldnamen) {
        print OUT "\t",
             ($feldnamen[$feld] =~ m|[- ,/+%]|) ? '[' : '',
                  $feldnamen[$feld],
             ($feldnamen[$feld] =~ m|[- ,/+%]|) ? '] ' : ' ',
                  $feldtypname{$feldtyp[$feld]},
         ($feldtyp[$feld] eq 'T' && $feldmlen[$feld] < 9) ? 
                      '(' . $feldmlen[$feld] . ')' : '',
                  $feld == $feldanzahl-1 ? ');' : ',',
          "\n";
        $feld++;
    }
    close OUT;
}

if ($BREAKONERROR and ($fehler > 9)) {
    print "\nAbbruch nach ", $fehler, " Fehler.\n" unless $STUMM;
}
else {
    print "\n" unless $STUMM;
    print 'Zeile ', $laengnum, ' war mit ', $laengste, " Stellen am laengsten.\n" if $ZEIGLANG;
    print "Fertig nach ", $datenzeilen, ' Datenzeilen in ', 
        $TITELZEILE+$zeilen, " Dateizeilen.\n" unless $STUMM;
}
