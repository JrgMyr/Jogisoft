#!/usr/bin/env perl
# (c) Joerg Meyer, 2005-01-05, 2010-02-06, 2022-12-26, 2023-01-09
# Code copyrighted and shared under GPL v3.0
# mailto:info@jogisoft.de

# require cwd;

$PROGRAM = 'diffscan.pl';
$VERSION = 'v0.88';
$DESCRPT = 'Verzeichnisbaeume vergleichen.';

$trenn   = ' - ';
$dopp    = ': ';
$PathSep = "\\";

($ENV{'PATH'} =~ m|/|) && ($PathSep = '/');

$MODUS_REF  = 0;
$MODUS_DIFF = 1;

$AUSG_LISTE = 0;
$AUSG_NAME  = 1;

$IDENT_NAME = 0;
$IDENT_ONLY = 1;
$IDENT_TYP  = 2;
$IDENT_CRC  = 3;

$ONEDAY  = 24 * 3600;

$diffcount = $errorcount = $filecount = $dircount = 0;
$tiefe = $AUSFUEHRL = $STUMM = $Modus = $Ausgabe = $Ident = $Ignorecase = 0;
$AuswTiefe = -1;
$NextArgIsListFile = 0;
$Orig = '';
@Pfade = ();

if (@ARGV < 2 and $ARGV[0] ne '-h' and $ARGV[0] ne '-v') {
    print $PROGRAM, $dopp, "Keine Objekte angegeben.\n";
    exit;
}

sub usage {
    print 'Usage: ', $PROGRAM, " [Parameter] Originalpfad Vergleichsobjekt[e]\n\n",
          "Parameter:\n",
          "\t-0\tKeine Unterverzeichnisse auswerten\n",
          "\t-1\tNur ein Verzeichnis tief auswerten\n",
          "\t-2\tZwei Verzeichnisse tief auswerten\n",
          "\t-3\tDrei Verzeichnisse tief auswerten\n",
          "\t-4\tVier Verzeichnisse tief auswerten\n",
          "\t-a\tAusfuehrliche Meldungen\n",
          "\t-c\tIdent: Groesse, SDBM-Hash\n",
          "\t-d\tAusgabe: Nur Dateinamen mit Pfad\n",
          "\t-f\tVergleichsobjekte aus Datei einlesen\n",
          "\t-g\tGross-/Kleinschreibung ignorieren\n",
          "\t-h\tHilfeseite anzeigen\n",
          "\t-i\tAlle Unterverzeichnisse auswerten (Vorgabe)\n",
          "\t-l\tAusgabe: Liste mit Dateien (Vorgabe)\n",
          "\t-n\tIdent: Name, Groesse, Zeitstempel (Vorgabe)\n",
          "\t-o\tIdent: Nur Name und Typ\n",
          "\t-q\tKeine Textmeldungen\n",
          "\t-t\tIdent: Typ, Groesse, Zeitstempel\n",
          "\t-v\tVersion anzeigen\n";
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
 
# Vergleich mit @ARGV bereits oben!

foreach (@ARGV) {
    if (substr($_, 0, 1) eq '-') {
        m/0/ && ($AuswTiefe = 0);
        m/1/ && ($AuswTiefe = 1);
        m/2/ && ($AuswTiefe = 2);
        m/3/ && ($AuswTiefe = 3);
        m/4/ && ($AuswTiefe = 4);
        m/a/ && ($AUSFUEHRL = 1);
        m/c/ && ($Ident = $IDENT_CRC);
        m/d/ && ($Ausgabe = $AUSG_NAME);
        m/f/ && ($NextArgIsListFile = 1);
        m/g/ && ($Ignorecase = 1);
        m/h|\?/ && &usage();
        m/i/ && ($AuswTiefe = -1);
        m/l/ && ($Ausgabe = $AUSG_LISTE);
        m/n/ && ($Ident = $IDENT_NAME);
        m/o/ && ($Ident = $IDENT_ONLY);
        m/q/ && ($STUMM = 1);
        m/t/ && ($Ident = $IDENT_TYP);
        m/v/ && &version();
    }
    else {
        if ($Orig eq '') {
            $Orig = $_;
        }
        else {
            if ($NextArgIsListFile) {
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
                $NextArgIsListFile = 0;
            }
            else {
                push @Pfade, $_;
            }
        }
    }
}

sub ScanFile {
    my $eintrag = shift;

    $filecount++;

    if ($Ident == $IDENT_NAME or $Ident == $IDENT_ONLY) {
        $id = $Ignorecase ? lc $eintrag : $eintrag;
    }
    elsif ($Ident == $IDENT_TYP) {
        $id = $eintrag;
        ($eintrag =~ /.*\.([^.]*)$/) && ($id = $1);
    }
    elsif ($Ident == $IDENT_CRC) {
        $id = 0;

        if (open FILE, '<' . $eintrag) {

            # SDBM Algorithmus
            while (read(FILE, $t, 4) == 4) {
                $id = (($id << 16) + ($id << 6) - $id + unpack('I', $t));
            }
            close FILE;
        }
    }

    if ($Ident == $IDENT_ONLY) {
        $id = $eintrag;
    }
    elsif ($Ident == $IDENT_CRC) {
        $id = join(':', -s $eintrag,
                        $id);
    }
    else {
        $id = join(':', -s $eintrag,
                        int(($^T - $ONEDAY * (-M _)) / 60),
                        $id);
    }

    if ($Modus == $MODUS_REF) {
        $filearch{$id} = $AktPath . ($AktPath gt '' ? $PathSep : '') . $eintrag;
    }
    else {
        if (exists $filearch{$id}) {
            $filearch{$id} = '*';
        }
    }
}

sub ScanDir {

    opendir VERZ, '.';
    my @liste = readdir VERZ;
    closedir VERZ;
    $dircount++;

    $AktPath = join($PathSep, @dirstack);
    foreach $eintrag (@liste) {
        &ScanFile($eintrag) if -f $eintrag;
    }

    return 2 if $AuswTiefe == $tiefe;

    foreach $eintrag (@liste) {
        next if $eintrag eq '.' or
                $eintrag eq '..';

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

print $DESCRPT, "\n",
      '-' x 75, "\n"
    unless $Ausgabe == $AUSG_NAME;

$Modus = $MODUS_REF;

$Orig =~ s/(\/|\\)+$//;

print "Lade Originaldateien aus: ", $Orig, "...\n" if $AUSFUEHRL;
chdir $Orig || die $PROGRAM, $dopp, "Kann Pfad nicht finden!\n";
&ScanDir;
chdir '..';

print "\t", $filecount, ' Dateien in ',
            $dircount, " Verzeichnissen eingelesen.\n",
            '-' x 75, "\n"
    if $AUSFUEHRL;

$Modus = $MODUS_DIFF;

$StartPfad = $ENV{'PWD'};

foreach $pfad (@Pfade) {

    $pfad =~ s/(\/|\\)+$//;
    print "Untersuche: ", $pfad, "...\n" if $AUSFUEHRL;

    if ($StartPfad) {
        chdir $StartPfad || die $PROGRAM, $dopp, "Kann Startpfad nicht finden!\n";
    }

    if (-f $pfad) {
        &ScanFile($pfad);
    }
    elsif (-d _) {
        chdir $pfad || die $PROGRAM, $dopp, "Kann Pfad nicht untersuchen!\n";
        &ScanDir;
        chdir '..';
    }
    else {
        print $AUSFUEHRL ? "\tWas ist das?\n" : $PROGRAM . $dopp . $pfad . " nicht gefunden.\n";
    }
}
print '-' x 75, "\n" if $AUSFUEHRL;

foreach $t (keys %filearch) {
    if ($filearch{$t} ne '*') {
        $diffcount++;

        $AktDat = $Orig . $PathSep . $filearch{$t};

        if ($Ausgabe == $AUSG_LISTE) {
            print 'Es fehlt: ', $AktDat, "\n" unless $STUMM;
        }
        else {
            if ($PathSep eq '/') {
                $AktDat =~ s/([ '])/\\\1/g;
            }
            else {
                ($AktDat =~ m/ /) && ($AktDat = '"' . $AktDat . '"');
            }
            print $AktDat, "\n";
        }
    }
}

print '-' x 75, "\n",
      'Fertig nach ', &formint($diffcount), ' fehlenden Dateien in ',
                      scalar(@Pfade), " Vergleichsobjekt(en).\n"
    unless $Ausgabe == $AUSG_NAME;

