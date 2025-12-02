#!/usr/bin/env perl
# (c) Joerg Meyer, 2005-01-05, 2010-02-06, 2023-10-28..11-10, 2024-05-17..30, 2025-11-09
# Code copyrighted and shared under GPL v3.0
# mailto:info@jogisoft.de

$PROGRAM = 'diffscan.pl';
$VERSION = 'v1.01';
$DESCRPT = 'Verzeichnisbaeume vergleichen.';

$trenn   = ' - ';
$dopp    = ': ';
$PathSep = "\\";

($ENV{'PATH'} =~ m|/|) && ($PathSep = '/');

$MODUS_REF  = 0;
$MODUS_DIFF = 1;

$AUSG_LISTE = 0;
$AUSG_NAME  = 1;
$AUSG_NICHT = 2;

$IDENT_NAME = 0;
$IDENT_SIZE = 1;
$IDENT_ONLY = 2;
$IDENT_TYP  = 3;
$IDENT_CRC  = 4;
$IDENT_DIR  = 9;

$ONEDAY  = 24 * 3600;

$symlinkcount = $diffcount = $errorcount = $filecount = $dircount = 0;
$tiefe = $AUSFUEHRL = $STUMM = $Modus = $Ausgabe = $Ident = $Ignorecase = 0;
$emptyfiles = 0;
$AuswTiefe = -1;
$NextArgIsListFile = $NextArgNurTyp = 0;
$Orig = $NurTypen = '';
@Pfade = ();
%filearch = ();
@result = ();

sub usage {
    print 'Usage: ', $PROGRAM, " [Parameter] Originalpfad Vergleichsobjekt[e]\n\n",
          "Parameter:\n",
          "\t-0\tKeine Unterverzeichnisse auswerten\n",
          "\t-1\tNur ein Verzeichnis tief auswerten\n",
          "\t-2\tZwei Verzeichnisse tief auswerten\n",
          "\t-<n>\tBeliebige <n> Verzeichnisse tief auswerten\n",
          "\t-a\tAusfuehrliche Meldungen\n",
          "\t-c\tIdent: Groesse, SDBM-Hash (nur nicht-leere)\n",
          "\t-d\tAusgabe: Nur Dateinamen mit Pfad\n",
          "\t-f\tVergleichsobjekte aus Datei einlesen\n",
          "\t-g\tAlle Unterverzeichnisse auswerten (Vorgabe)\n",
          "\t-h\tHilfeseite anzeigen\n",
          "\t-i\tGross- und Kleinschreibung ignorieren\n",
          "\t-l\tAusgabe: Liste mit Dateien (Vorgabe)\n",
          "\t-m\tIdent: Name, Groesse, Zeitstempel (Vorgabe)\n",
          "\t-n\tIdent: Name, Groesse\n",
          "\t-o\tIdent: Nur Name inkl. Typ\n",
          "\t-q\tKeine Textmeldungen\n",
          "\t-r\tNur angegebene Dateitypen betrachten\n",
          "\t-s\tIdent: Nur Verzeichnisse per Namen\n",
          "\t-t\tIdent: Typ, Groesse, Zeitstempel\n",
          "\t-v\tVersion anzeigen\n",
          "\t-x\tAusgabe: Dateien nicht auflisten\n";
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

    if ($NurTypen gt '') {
        # Nur Dateien durchlassen, die gewünscht sind!
        ($eintrag =~ m/\.([^.]*)$/) && ($ext = lc $1);

        if ($NurTypen =~ /$ext,/) {
            # Komma wichtig, um .js von .jsx zu unterscheiden
            # Gut, kann weiter
        }
        else {
            return 2;
        }
    }

    $filecount++;

    if ($Ident == $IDENT_NAME or
        $Ident == $IDENT_SIZE or
        $Ident == $IDENT_ONLY) {
        $id = $Ignorecase ? lc $eintrag : $eintrag;
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

    if ($Ident == $IDENT_DIR) {
        if ($Modus == $MODUS_REF) {
            $filearch{$AktPath} = $AktPath;
        }
        else {
            if (exists $filearch{$AktPath}) {
                $filearch{$AktPath} = '*';
            }
        }
    }
    else {
        foreach $eintrag (@liste) {
            &ScanFile($eintrag) if -f $eintrag;
        }
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

if (@ARGV < 2 and $ARGV[0] ne '-h' and $ARGV[0] ne '-v') {
    print $PROGRAM, $dopp, "Keine Objekte angegeben.\n";
    exit;
}

foreach (@ARGV) {
    if (substr($_, 0, 1) eq '-') {
        m/\d+/ && ($AuswTiefe = $&);
        m/a/ && ($AUSFUEHRL = 1);
        m/c/ && ($Ident = $IDENT_CRC);
        m/d/ && ($Ausgabe = $AUSG_NAME);
        m/f/ && ($NextArgIsListFile = 1);
        m/g/ && ($Ignorecase = 1);
        m/h|\?/ && &usage();
        m/i/ && ($AuswTiefe = -1);
        m/l/ && ($Ausgabe = $AUSG_LISTE);
        m/m/ && ($Ident = $IDENT_NAME);
        m/n/ && ($Ident = $IDENT_SIZE);
        m/o/ && ($Ident = $IDENT_ONLY);
        m/q/ && ($STUMM = 1);
        m/r/ && ($NextArgNurTyp = 1);
        m/s/ && ($Ident = $IDENT_DIR);
        m/t/ && ($Ident = $IDENT_TYP);
        m/v/ && &version();
        m/x/ && ($Ausgabe = $AUSG_NICHT);
    }
    elsif ($NextArgNurTyp) {
        $NurTypen .= $_ . ',';
        $NextArgNurTyp = 0;
    }
    elsif ($NextArgIsListFile) {
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
        if ($Orig eq '') {
            $Orig = $_;
        }
        else {
            push @Pfade, $_;
        }
    }
}

print $DESCRPT, "\n"
    unless $Ausgabe == $AUSG_NAME;

$Modus = $MODUS_REF;

$Orig =~ s/(\/|\\)+$//;

print 'Nur diese Dateitypen betrachten: ', substr($NurTypen, 0, -1), "\n"
    if $NurTypen gt '' && ! $STUMM;

$StartPfad = $ENV{'PWD'};

print '-' x 75, "\n"
    unless $Ausgabe == $AUSG_NAME;

print "Lade Originaldateien aus: ", $Orig, "...\n" if $AUSFUEHRL;
chdir $Orig || die $PROGRAM, $dopp, 'Kann Pfad ', $Orig, "nicht finden!\n";
&ScanDir;
chdir $StartPfad || die $PROGRAM, $dopp, "Kann Startpfad nicht wiederfinden!\n";

print "\t", $filecount, ' Dateien in ',
            $dircount, " Verzeichnissen eingelesen.\n",
            '-' x 75, "\n"
    if $AUSFUEHRL;

$Modus = $MODUS_DIFF;

foreach $pfad (@Pfade) {

    $pfad =~ s/(\/|\\)+$//;
    print "Untersuche: ", $pfad, " ...\n" if $AUSFUEHRL;

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
}
print '-' x 75, "\n" if $AUSFUEHRL;

foreach $t (keys %filearch) {
    if ($filearch{$t} ne '*') {
        push @ergeb, $filearch{$t};
    }
}
$diffcount = scalar @ergeb;

foreach $t (sort @ergeb) {
    $AktDat = $Orig . $PathSep . $t;

    if ($Ausgabe == $AUSG_LISTE) {
        print 'Es fehlt: ', $AktDat, "\n" unless $STUMM;
    }
    elsif ($Aussgabe == $AUSG_NAME) {
        if ($PathSep eq '/') {
            $AktDat =~ s/([ '])/\\\1/g;
        }
        else {
            ($AktDat =~ m/ /) && ($AktDat = '"' . $AktDat . '"');
        }
        print $AktDat, "\n";
    }
    elsif ($Ausgabe == $AUSG_NICHT) {
        # Keine Ausgabe der Dateinamen
    }
    else {
        die 'Ausgabevariable hat falschen Wert: ', $Ausgabe, "!\n";
    }
}

print '-' x 75, "\n";
print 'Es wurden ', &formint($symlinkcount), " symbolische Links ignoriert.\n"
    if $symlinkcount && ! $STUMM;
print 'Es wurden ', &formint($emptyfiles), " leere Dateien ignoriert.\n"
    if $emptyfiles && ($Ident = $IDENT_CRC) && ! $STUMM;

print 'Fertig nach ',
      $diffcount == 1 ? ($Ident == $IDENT_DIR ? 'einem' : 'einer') : &formint($diffcount),
      ' fehlenden ',
      $Ident == $IDENT_DIR ? 'Verzeichnis' : 'Datei',
      $diffcount == 1 ? '' : ($Ident == $IDENT_DIR ? 'sen' : 'en'),
      ' in ',
      scalar(@Pfade) == 1 ? 'einem Vergleichsobjekt':
                          scalar(@Pfade) . ' Vergleichsobjekten',
      ".\n"
    unless $Ausgabe == $AUSG_NAME;
