#!/usr/bin/env perl
# (c) Joerg Meyer, 2005-01-05, 2010-02-07, 2022-12-26, 2023-01-09
# Code copyrighted and shared under GPL v3.0
# mailto:info@jogisoft.de

$PROGRAM = 'dupescan.pl';
$VERSION = 'v0.88';
$DESCRPT = 'Dateidubletten auflisten.';

$trenn   = ' - ';
$dopp    = ': ';
$PathSep = "\\";

($ENV{'PATH'} =~ m|/|) && ($PathSep = '/');

$AUSG_LISTE = 0;
$AUSG_DOS   = 1;
$AUSG_UNIX  = 2;
$AUSG_NAME  = 3;

$IDENT_NAME = 0;
$IDENT_ONLY = 1;
$IDENT_TYP  = 2;
$IDENT_CRC  = 3;

$ONEDAY  = 24 * 3600;

$dupecount = $errorcount = $filecount = $dircount = $exclcount = 0;
$tiefe = $AUSFUEHRL = $STUMM = $Ausgabe = $Ident = $Ignorecase = $ZeigStat = 0;
$AuswTiefe = -1;
$NextArgListFile = $NextArgAusschlListe = 0;
@Pfade = ();
$AuschlussListe = '';

sub usage {
    print 'Usage: ', $PROGRAM, " [Parameter] Objekt[e]\n\n",
          "Parameter:\n",
          "\t-0\tKeine Unterverzeichnisse auswerten\n",
          "\t-1\tNur ein Verzeichnis tief auswerten\n",
          "\t-2\tZwei Verzeichnisse tief auswerten\n",
          "\t-3\tDrei Verzeichnisse tief auswerten\n",
          "\t-4\tVier Verzeichnisse tief auswerten\n",
          "\t-a\tAusfuehrliche Meldungen\n",
          "\t-b\tAusgabe: DOS-Batchdatei\n",
          "\t-c\tIdent: Groesse, SDBM-Hash\n",
          "\t-d\tAusgabe: Nur Dateinamen mit Pfad\n",
          "\t-e\tListe auszuschliessender Dateinamen\n",
          "\t-f\tDateinamen bzw. Pfade aus Datei einlesen\n",
          "\t-g\tGross-/Kleinschreibung ignorieren\n",
          "\t-h\tHilfeseite anzeigen\n",
          "\t-i\tAlle Unterverzeichnisse auswerten (Vorgabe)\n",
          "\t-l\tAusgabe: Liste mit Dubletten (Vorgabe)\n",
          "\t-n\tIdent: Name, Groesse, Zeitstempel (Vorgabe)\n",
          "\t-o\tIdent: Nur Name und Typ\n",
          "\t-q\tKeine Textmeldungen\n",
#         "\t-r\tDateien mittels RegExps ausschliessen\n",
          "\t-s\tStatistikinformationen inkl. Pfadnamen\n",
          "\t-t\tIdent: Typ, Groesse, Zeitstempel\n",
          "\t-u\tAusgabe: Unix-Shellskript\n",
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
 
if (@ARGV == 0) {
    print $PROGRAM, $dopp, "Keine Objekte angegeben.\n\n";
    &usage();
}

foreach (@ARGV) {
    if (substr($_, 0, 1) eq '-') {
        m/0/ && ($AuswTiefe = 0);
        m/1/ && ($AuswTiefe = 1);
        m/2/ && ($AuswTiefe = 2);
        m/3/ && ($AuswTiefe = 3);
        m/4/ && ($AuswTiefe = 4);
        m/a/ && ($AUSFUEHRL = 1);
        m/b/ && ($Ausgabe = $AUSG_DOS) && ($PathSep = '\\');
        m/c/ && ($Ident = $IDENT_CRC);
        m/d/ && ($Ausgabe = $AUSG_NAME);
        m/e/ && ($NextArgAusschlListe = 1);
        m/f/ && ($NextArgListFile = 1);
        m/g/ && ($Ignorecase = 1);
        m/h|\?/ && &usage();
        m/i/ && ($AuswTiefe = -1);
        m/l/ && ($Ausgabe = $AUSG_LISTE);
        m/n/ && ($Ident = $IDENT_NAME);
        m/o/ && ($Ident = $IDENT_ONLY);
        m/q/ && ($STUMM = 1);
        m/s/ && ($ZeigStat = 1);
        m/t/ && ($Ident = $IDENT_TYP);
        m/u/ && ($Ausgabe = $AUSG_UNIX) && ($PathSep = '/');
        m/v/ && &version();
    }
    elsif ($NextArgAusschlListe) {
        $ExclList = ',' . $_ . ',';
        $NextArgAusschlListe = 0;
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

sub ScanFile {
    my $eintrag = shift;

    if (index($ExclList, ','.$eintrag.',') >= $[) {
        $exclcount++;
        return 2;
    }

    $filecount++;
    $AktDat = $AktPath . $PathSep . $eintrag;

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

    if (exists $filearch{$id}) {
        $dupecount++;

        if ($Ausgabe == $AUSG_DOS) {
            $AktDat =~ tr/ÄÖÜäöüß/Ž™š„”á/;
            print OUT 'del /Q "', $AktDat, '"', "\n";
        }
        elsif ($Ausgabe == $AUSG_UNIX) {
            print OUT 'rm -f ', $AktDat, "\n";
        }
        elsif ($Ausgabe == $AUSG_NAME) {
            if ($PathSep eq '/') {
                $AktDat =~ s/([ '])/\\\1/g;
            }
            else {
                ($AktDat =~ m/ /) && ($AktDat = '"' . $AktDat . '"');
            }
            print $AktDat, "\n";
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
        $filearch{$id} = $AktDat;
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

print $DESCRPT, "\n"
    unless ($Ausgabe == $AUSG_NAME) or $STUMM;

print 'Gebe Dubletten in ',
      ($Ausgabe ? 'Loeschskript' : 'Listenform'),
      " aus.\n"
      if $AUSFUEHRL and $Ausgabe != $AUSG_NAME;

if ($Ausgabe == $AUSG_DOS) {
    open(OUT, '>dupes.bat');
    print OUT "REM Dubletten loeschen\n";
}
elsif ($Ausgabe == $AUSG_UNIX) {
    open(OUT, '>dupes.sh');
    print OUT "#!/bin/sh\n";
}

$StartPfad = $ENV{'PWD'};

print 'Dateien wegen Namen ausschliessen: ', substr($ExclList, 1, -1) , "\n" if $ExclList gt ',';

foreach $pfad (@Pfade) {

    $pfad =~ s/(\/|\\)+$//;
    print "\nUntersuche: ", $pfad, "...\n" if $AUSFUEHRL;

    if (-f $pfad) {
        &ScanFile($pfad);
    }
    elsif (-d _) {

        if ($StartPfad) {
            chdir $StartPfad || die $PROGRAM, $dopp, "Kann Startpfad nicht finden!\n";
        }

        chdir $pfad || die $PROGRAM, $dopp, "Kann Pfad nicht untersuchen!\n";
        &ScanDir;
        chdir '..';
    }
    else {
        print $AUSFUEHRL ? "\tWas ist das?\n" : $PROGRAM . $dopp . $pfad . " nicht gefunden.\n";
    }
}

print OUT "echo Fertig.\n";
if ($Ausgabe == $AUSG_DOS) {
    print OUT "pause\n";
}
elsif ($Ausgabe == $AUSG_UNIX) {
    print OUT "read\n";
}
close(OUT) if $Ausgabe != 0;

print '-' x 75, "\n",
      'Fertig mit ', &formint($dupecount), ' Dubletten in ',
                     &formint($filecount), ' Dateien in ',
                     &formint($dircount), ' Verzeichnissen in ',
                     scalar(@Pfade), " Objekt(en).\n"
    unless ($Ausgabe == $AUSG_NAME) or $STUMM;

