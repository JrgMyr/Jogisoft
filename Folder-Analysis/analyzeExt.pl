#!/usr/bin/env perl
# (c) Joerg Meyer, 2005-08-19 .. 2025-11-10
# Code copyrighted and shared under GPL v3.0
# mailto:info@jogisoft.de

$PROGRAM   = 'analyzeExt';
$VERSION   = 'V0.25';
$DESCRPT   = 'Verzeichnisbaum nach Dateitypen gruppieren.';

$VERBOSE   = 0;
$STUMM     = 0;
$RECURSE   = 1;
$CAPEXT    = 1;
$MAXFOUR   = 1;
$trenn     = ' - ';
@Pfade     = ();
$StartPfad = $NurTypen  = ''; 

$tiefe = $maxtiefe = 0;
@dirstack = ();
$dircount = $filecount = $filefound = $errorcount = $filevolume = 0;

sub usage {
    print 'Usage: ', $PROGRAM, " [Parameter] Pfad(e)\n",
          $DESCRPT, "\n\n",
          "Parameter:\n",
          "\t-a\tAusfuehrliche Textmeldungen\n",
          "\t-b\tBeliebig lange Erweiterungen\n",
          "\t-g\tGross- und Kleinschreibung beachten\n",
          "\t-h\tDiese Hilfe ausgeben\n",
          "\t-i\tGross- und Kleinschreibung ignorieren (Vorgabe)\n",
          "\t-m\tMaximal vier Zeichen lange Erweiterungen (Vorgabe)\n",
          "\t-n\tNicht rekursiv\n",
          "\t-o\tNur benannte Dateitypen auflisten\n",
          "\t-q\tKeine Textmeldungen\n",
          "\t-r\tRekursive (Vorgabe)\n",
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
 
sub formsize {
    my $t = shift;

    if ($t == 0) {
        return '0';
    }
    elsif ($t < 1024) {
        return '< 1';
    }
    else {
        $t += 500;
        $t >>= 10;
        $t =~ s/(.+)(...)$/$1.$2/;
        return $t;
    }
}

sub RegisterFile {
    my $datei = shift;
    my $ext = '';

    $filecount++;

    $ext = '';
    ($datei =~ m/$ExtPat/) && ($ext = lc $1);

    if ($NurTypen gt '') {
        # Nur Dateien durchlassen, die gewünscht sind!
        if ($ext gt '' && $NurTypen =~ /$ext,/) {
            # Komma wichtig, um .js von .jsx zu unterscheiden
            # Gut, kann weiter
        }
        else {
            return 2;
        }
    }
    $filefound++;

    $filelen = (500 + -s $datei) >> 10;  # Speichern in gerundeten KB, sonst Ueberlauf bei 4 GB
    $filevolume += $filelen;
    $CAPEXT && ($ext = uc $ext);

# print "Datei: $datei --> Ext: $ext\n";

    $extCount{$ext}++;
    $extSize{$ext} += $filelen;

    return 1;
}

sub ScanDir {

    opendir VERZ, '.';
    my @liste = sort readdir VERZ;
    closedir VERZ;
    $dircount++;

    foreach $eintrag (@liste) {
        if (-f $eintrag) {
            &RegisterFile($eintrag);
        }
    }

    if ($RECURSE) {
        foreach $eintrag (@liste) {
            if (-d $eintrag) {
                next if ($eintrag eq '.') || ($eintrag eq '..');

                push @dirstack, $eintrag;
                $VERBOSE && print('--> ', join('/', $pfad, @dirstack), "\n");

                if (chdir $eintrag) {;
                    $tiefe++;
                    $maxtiefe = $tiefe if $tiefe > $maxtiefe;

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
    }
    return 1;
}

if (@ARGV == 0) {
    die $PROGRAM, ": Kein Startpfad angegeben.\n";
}

foreach (@ARGV) {
    if (substr($_, 0, 1) eq '-') {
        m/a/ && ($VERBOSE   = 1);
        m/b/ && ($MAXFOUR   = 0);
        m/h|\?/ && &usage();
        m/g/ && ($CAPEXT    = 0);
        m/i/ && ($CAPEXT    = 1);
        m/n/ && ($RECURS    = 0);
        m/m/ && ($MAXFOUR   = 1);
        m/o/ && ($NextArgNurTyp = 1);
        m/q/ && ($STUMM     = 1);
        m/r/ && ($RECURS    = 1);
        m/v/ && &version();
    }
    elsif ($NextArgNurTyp) {
        $NurTypen .= $_ . ',';
        $NextArgNurTyp = 0;
    }
    else {
        push @Pfade, $_;
    }
}

$ExtPat = $MAXFOUR ? '\.([^.]{1,4})$' : '\.([^.]*)$';

print $DESCRPT, "\n"
    unless $STUMM;

$StartPfad = $ENV{'PWD'};

print '** Nur diese Dateitypen betrachten: ', substr($NurTypen, 0, -1) , "\n"
    if $NurTypen gt '' && ! $STUMM;

die "Kein Pfad zur Durchsuchung angegeben!\n" if scalar(@Pfade) == 0;

foreach $pfad (@Pfade) {
    print '-- Untersuche ', $pfad eq '.' ? 'aktuelles Verzeichnis' : $pfad,
          "\n"
        unless $STUMM;

    if (-d $pfad) {
        chdir $pfad || die $PROGRAM, $dopp, "Kann Pfad nicht untersuchen!\n";
        &ScanDir;
        chdir $StartPfad;
    }
    else {
        print $pfad, " nicht gefunden.\n" unless $STUMM;
    }

    $VERBOSE && print "\n";
}

foreach (sort keys %extCount) {
    printf "%-8s%6s Datei(en) %9s MB\n",
           $_,
           &formint($extCount{$_}),
           &formsize($extSize{$_});
}

print $errorcount, " Fehler sind aufgetreten.\n" if $errorcount;
print &formint($dircount), ' Verzeichnisse (max. Tiefe: ', $maxtiefe, ') mit ',
      &formint($filecount), ' Dateien (zus. ', &formsize($filevolume), ' GB) in ', 
      scalar(@Pfade) == 1 ? 'einem Objekt' : scalar(@Pfade). ' Objekten',
      " durchsucht.\n"
    unless $STUMM;
print scalar keys %extCount, ' verschiedene Dateitypen',
      $NurTypen gt '' ? ' in ' . &formint($filefound) . ' Dateien' : '',
      " gesichtet.\n",
      "Fertig.\n"
    unless $STUMM;
