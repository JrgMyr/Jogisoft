#!/usr/bin/env perl
# (c) Joerg Meyer, 2005-01-05, 2010-02-07, 2022-12-26, 2023-10-28..11-10, 2024-01-15, 2024-05-17..30
# Code copyrighted and shared under GPL v3.0
# mailto:info@jogisoft.de

$PROGRAM = 'dupescan.pl';
$VERSION = 'y1.00';
$DESCRPT = 'Dateidubletten auflisten.';

$trenn   = ' - ';
$dopp    = ': ';
$PathSep = "\\";

($ENV{'PATH'} =~ m|/|) && ($PathSep = '/');

$AUSG_LISTE = 0;
$AUSG_DOS   = 1;
$AUSG_UNIX  = 2;
$AUSG_NAME  = 3;
$AUSG_NICHT = 4;

$IDENT_NAME = 0;
$IDENT_SIZE = 1
$IDENT_ONLY = 2;
$IDENT_TYP  = 3;
$IDENT_CRC  = 4;

$ONEDAY  = 24 * 3600;

$symlinkcount = $dupecount = $filecount = $dircount = $exclcount = 0;
$tiefe = $AUSFUEHRL = $STUMM = $Ausgabe = $Ident = $IGNORECASE = $ZeigStat = 0;
$errorcount = $emptyfiles = 0;
$KOMPLETT = 1;
$AuswTiefe = -1;
$NextArgListFile = $NextArgAusschlListe = $NextArgNurTyp = 0;
@Pfade = ();
$ExclList = $NurTypen = '';
%filearch = ();

sub usage {
    print 'Usage: ', $PROGRAM, " [Parameter] Objekt[e]\n\n",
          "Parameter:\n",
          "\t-0\tKeine Unterverzeichnisse auswerten\n",
          "\t-1\tNur ein Verzeichnis tief auswerten\n",
          "\t-2\tZwei Verzeichnisse tief auswerten\n",
          "\t-<n>\tBeliebige <n> Verzeichnisse tief auswerten\n",
          "\t-a\tAusfuehrliche Meldungen\n",
          "\t-b\tAusgabe: DOS-Batchdatei\n",
          "\t-c\tIdent: Groesse, SDBM-Hash (nur nicht-leere)\n",
          "\t-d\tAusgabe: Nur Dateinamen mit Pfad\n",
          "\t-e\tListe auszuschliessender Dateinamen\n",
          "\t-f\tDateinamen bzw. Pfade aus Datei einlesen\n",
          "\t-g\tAlle Unterverzeichnisse auswerten (Vorgabe)\n",
          "\t-h\tHilfeseite anzeigen\n",
          "\t-i\tGross-/Kleinschreibung ignorieren\n",
          "\t-k\tAlle Dubletten, auch innerhalb Objekten (Vorgabe)\n",
          "\t-l\tAusgabe: Liste mit Dubletten (Vorgabe)\n",
          "\t-m\tIdent: Name, Groesse, Zeitstempel (Vorgabe)\n",
          "\t-n\tIdent: Name, Groesse\n",
          "\t-o\tIdent: Nur Name und Typ\n",
          "\t-q\tKeine Textmeldungen\n",
          "\t-r\tNur angegebene Dateitypen betrachten\n",
          "\t-s\tStatistikinformationen inkl. Pfadnamen\n",
          "\t-t\tIdent: Typ, Groesse, Zeitstempel\n",
          "\t-u\tAusgabe: Unix-Shellskript\n",
          "\t-v\tVersion anzeigen\n",
          "\t-x\tDubletten nur zwischen den Objekten werten\n",
          "\t-z\tAusgabe: Dateien nicht auflisten\n";
    exit;
}

sub version {
    print $PROGRAM, $trenn, $VERSION, "\n",
          $DESCRPT, "\n";
    exit;
}

sub formint {
    my $t = shift;

    if ($t > 1000) {
        $t =~ s/(.+)(...)$/$1.$2/;
    }
    return $t;
}
 
sub ScanFile {
    my $eintrag = shift;

    if (index($ExclList, ','.$eintrag.',') >= $[) {
        # Einzelne Dateien gemaess Liste ueberspringen
        $exclcount++;
        return 2;
    }

    if ($NurTypen gt '') {
        # Nur Dateien durchlassen, die gewuenscht sind!
        ($eintrag =~ m/\.([^.]*)$/) && ($ext = lc $1);

        if ($NurTypen =~ /$ext,/) {
            # Komma wichtig, um .js von .jsx zu unterscheiden
            # Gut, kann weiter
        }
        else {
            return 3;
        }
    }

    $filecount++;
    $AktDat = $AktPath . $PathSep . $eintrag;

    if ($Ident == $IDENT_NAME or
        $Ident == $IDENT_SIZE or
        $Ident == $IDENT_ONLY) {
        $id = $IGNORECASE ? lc $eintrag : $eintrag;
    }
    elsif ($Ident == $IDENT_TYP) {
        $id = $eintrag;
        ($eintrag =~ /.*\.([^.]*)$/) && ($id = $1);
    }
    elsif ($Ident == $IDENT_CRC) {
        $id = 0;
        if (-s $eintrag == 0) {
            $emptyfiles++;
            return 4;
        }

        if (open FILE, '<' . $eintrag) {

            # SDBM Algorithmus
            while ($l = read(FILE, $t, 4)) {
                $t .= ' ' x (4-$l) if $l < 4;
                $id = (($id << 16) + ($id << 6) - $id + unpack('I', $t));
            }
            close FILE;
        }
    }

    if ($Ident == $IDENT_ONLY) {
        $id = $eintrag;
    }
    elsif ($Ident == $IDENT_CRC or $Ident == $IDENT_SIZE) {
        $id = join(':', -s $eintrag,
                        $id);
    }
    elsif ($Ident == $IDENT_NAME or $Ident == $IDENT_TYP) {
        $id = join(':', -s $eintrag,
                        int(($^T - $ONEDAY * (-M _)) / 60),
                        $id);
    }
    else {
        die 'Was ist hier passiert? (Ident = ', $Ident, ")\n";
    }

    if (exists $filearch{$id}) {

        if ($KOMPLETT or $NaechstesObjekt) {
            $dupecount++;

            if ($Ausgabe == $AUSG_NAME) {
                if ($PathSep eq '/') {
                    $AktDat =~ s/([ '])/\\\1/g;
                }
                else {
                    ($AktDat =~ m/ /) && ($AktDat = '"' . $AktDat . '"');
               }
               print $AktDat, "\n";
            }
            elsif ($Ausgabe == $AUSG_DOS) {
                $AktDat =~ tr/ÄÖÜäöüß/Ž™š„”á/;
                print OUT 'del /Q "', $AktDat, '"', "\n";
            }
            elsif ($Ausgabe == $AUSG_UNIX) {
                print OUT 'rm -f "', $AktDat, '"', "\n";
            }
            elsif ($Ausgabe == $AUSG_NICHT) {
                # nichts ausgeben.
            }
            else {
                print '-' x 75, "\n" unless $STUMM;
                print $filearch{$id}, "\n";
                print $AktDat, "\n" unless $STUMM;
           }

           print "\t", $AktDat, "\n"
               if ($Ausgabe > $AUSG_LISTE) && ($Ausgabe < $AUSG_NAME) && ($AUSFUEHRL);
        }
        else {
            # Im ersten Objekt werden bei -m keine Dubletten gewertet.
        }
    }
    else {
        if ($KOMPLETT or !$NaechstesObjekt) {
            $filearch{$id} = $AktDat;
        }
        else {
            # Weitere Objekte werden bei -m nicht als Ausgang für Dubletten mitgezählt.
        }
    }
}

sub ScanDir {

    opendir VERZ, '.';
    my @liste = readdir VERZ;
    closedir VERZ;
    $dircount++;

    $AktPath = join($PathSep, $pfad, @dirstack);

    $ZeigStat && print $AktPath, $PathSep, "\n";

    foreach $eintrag (@liste) {
        &ScanFile($eintrag) if -f $eintrag;
    }

    return 2 if $AuswTiefe == $tiefe;

    foreach $eintrag (@liste) {
        next if $eintrag eq '.' or
                $eintrag eq '..';

        if (-l $eintrag) {
            $symlinkcount++;
            next;
        }

        if (-d $eintrag) {

            push @dirstack, $eintrag;

            if (chdir $eintrag) {
                $tiefe++;
                &ScanDir;
                $tiefe--;
                chdir '..';
            }
            else {
                print "Verzeichnis $eintrag nicht zugaenglich!.\n";
                $errorcount++;
            }
            pop @dirstack;
        }
    }
    return 1;
}

if (@ARGV == 0) {
    print $PROGRAM, $dopp, "Keine Objekte angegeben.\n\n";
    &usage();
}

foreach (@ARGV) {
    if (substr($_, 0, 1) eq '-') {
        m/0/ && ($AuswTiefe = $&);
        m/a/ && ($AUSFUEHRL = 1);
        m/b/ && ($Ausgabe = $AUSG_DOS) && ($PathSep = '\\');
        m/c/ && ($Ident = $IDENT_CRC);
        m/d/ && ($Ausgabe = $AUSG_NAME);
        m/e/ && ($NextArgAusschlListe = 1);
        m/f/ && ($NextArgListFile = 1);
        m/g/ && ($AuswTiefe = -1);
        m/h|\?/ && &usage();
        m/i/ && ($IGNORECASE = 1);
        m/k/ && ($KOMPLETT = 1);
        m/l/ && ($Ausgabe = $AUSG_LISTE);
        m/m/ && ($Ident = $IDENT_NAME);
        m/n/ && ($Ident = $IDENT_SIZE);
        m/o/ && ($Ident = $IDENT_ONLY);
        m/q/ && ($STUMM = 1);
        m/r/ && ($NextArgNurTyp = 1);
        m/s/ && ($ZeigStat = 1);
        m/t/ && ($Ident = $IDENT_TYP);
        m/u/ && ($Ausgabe = $AUSG_UNIX) && ($PathSep = '/');
        m/v/ && &version();
        m/x/ && ($KOMPLETT = 0);
        m/z/ && ($Ausgabe = $AUSG_NICHT);
    }
    elsif ($NextArgAusschlListe) {
        $ExclList .= $_ . ',';
        $NextArgAusschlListe = 0;
    }
    elsif ($NextArgNurTyp) {
        $NurTypen .= $_ . ',';
        $NextArgNurTyp = 0;
    }
    elsif ($NextArgListFile) {
        if(open FILE, '<' . $_) {
            while (<FILE>) {
                chomp;
                next if /^$/;
                next if /^#/;
                push @Pfade, $_;
            }
            close FILE;
        }
        else {
            die "Kann Listendatei $_ nicht einlesen.\n";
        }
        $NextArgListFile = 0;
    }
    else {
        push @Pfade, $_;
    }
}

print $DESCRPT, "\n"
    unless ($Ausgabe == $AUSG_NAME) or $STUMM;

if ($AUSFUEHRL) {
    if ($KOMPLETT) {
        print "Alle Dubletten in den Objekten werden gewertet (komplett).\n";
    }
    else {
        print "Nur Dubletten zwischen dem ersten Objekt und weiteren Objekten werten.\n";
    }
}

if (!$KOMPLETT && scalar(@Pfade) == 1) {
    die "Keine Vergleichsobjekte fuer '-m' angegeben!\n";
}

print 'Gebe Dubletten in ',
      ($Ausgabe ? 'Loeschskript' : 'Listenform'),
      " aus.\n"
    if $AUSFUEHRL and $Ausgabe < $AUSG_NAME;

if ($Ausgabe == $AUSG_DOS) {
    open(OUT, '>dupesdel.bat');
    print OUT "REM Dubletten loeschen\n";
}
elsif ($Ausgabe == $AUSG_UNIX) {
    open(OUT, '>dupes_rm.sh');
    print OUT "#!/bin/sh\n";
}

$StartPfad = $ENV{'PWD'};

print 'Dateien wegen Namen ausschliessen: ', substr($ExclList, 0, -1), "\n"
    if $ExclList gt '' && ! $TUMM;

print 'Nur diese Dateitypen betrachten: ', substr($NurTypen, 0, -1), "\n"
    if $NurTypen gt '' && ! $STUMM;

$NaechstesObjekt = 0;
foreach $pfad (@Pfade) {

    $pfad =~ s/(\/|\\)+$//;
    print "\nUntersuche: ", $pfad, "...\n" if $AUSFUEHRL;

    if (-f $pfad) {
        &ScanFile($pfad);
    }
    elsif (-d _) {
        chdir $pfad || die $PROGRAM, $dopp, 'Kann Pfad ', $pfad, " nicht untersuchen!\n";
        &ScanDir;
        chdir $StartPfad || die $PROGRAM, $dopp, "Kann Startpfad nicht wiederfinden!\n";
    }
    else {
        print $AUSFUEHRL ? "\tWas ist das?\n" : $PROGRAM . $dopp . $pfad . " nicht gefunden.\n";
    }
    $NaechstesObjekt = 1;
}

print OUT "echo Fertig.\n";
if ($Ausgabe == $AUSG_DOS) {
    print OUT "pause\n";
}
elsif ($Ausgabe == $AUSG_UNIX) {
    print OUT "read\n";
}
close(OUT) if $Ausgabe != 0;

print '-' x 75, "\n";
print 'Es wurden ', &formint($symlinkcount), " symbolische Links ignoriert.\n"
    if $symlinkcount && ! $STUMM;
print 'Es wurden ', &formint($emptyfiles), " leere Dateien ignoriert.\n"
    if $emptyfiles && ($Ident = $IDENT_CRC) && ! $STUMM;

print 'Fertig ',
      $dupecount == 0 ? 'OHNE' : 'mit '. &formint($dupecount),
      ' Dubletten in ',
      &formint($filecount), ' Dateien in ',
      $dircount == 1 ? 'einem Verzeichnis' :
                       &formint($dircount). ' Verzeichnissen',
      ' in ',
      scalar(@Pfade) == 1 ? 'einem Objekt' : scalar(@Pfade) . ' Objekten',
      ".\n"
    unless ($Ausgabe == $AUSG_NAME) or $STUMM;
