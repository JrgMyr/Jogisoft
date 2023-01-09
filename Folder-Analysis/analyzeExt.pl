#!/usr/bin/env perl
# (c) Joerg Meyer @ Jogisoft, 2005-08-19, 2016-09-27, 2017-01-27..30, 2023-01-09
# Code copyrighted and shared under GPL v3.0

$PROGRAM   = 'analyzeExt';
$VERSION   = 'V0.22';
$DESCRPT   = 'Verzeichnisbaum nach Dateitypen gruppieren.';

$STARTPFAD = '';
$VERBOSE   = 0;
$RECURSE   = 1;
$CAPEXT    = 1;
$MAXFOUR   = 1;
$trenn     = ' - ';

sub usage {
    print 'Usage: ', $PROGRAM, " [Parameter] Pfad\n",
          $DESCRPT, "\n\n",
          "Parameter:\n",
          "\t-a\tAusfuehrliche Textmeldungen\n",
          "\t-b\tBeliebig lange Erweiterungen\n",
          "\t-g\tGross-/Kleinschreibung beachten\n",
          "\t-h\tDiese Hilfe ausgeben\n",
          "\t-i\tGross-/Kleinschreibung ignorieren (Vorgabe)\n",
          "\t-m\tMaximal vier Zeichen lange Erweiterungen (Vorgabe)\n",
          "\t-n\tNicht rekursiv\n",
          "\t-r\tRekursive (Vorgabe)\n",
          "\t-v\tVersion anzeigen\n";
    exit;
}

sub version {
    print $PROGRAM, $trenn, $VERSION, $trenn, $DESCRPT, "\n";
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
    $filelen = (500 + -s $datei) >> 10;  # Speichern in gerundeten KB, sonst Überlauf bei 4 GB
    $filevolume += $filelen;

    ($datei =~ m/$ExtPat/) && ($ext = $1);

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
                $VERBOSE && print('--> ', join('/', $STARTPFAD, @dirstack), "\n");

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
        m/r/ && ($RECURS    = 1);
        m/v/ && &version();
    }
    else {
        $STARTPFAD = $_;
    }
}

$ExtPat = $MAXFOUR ? '\.([^.]{1,4})$' : '\.([^.]*)$';
$tiefe = $maxtiefe = 0;
@dirstack = ();
$dircount = $filecount = $errorcount = $filevolume = 0;

$STARTPFAD = '.' if $STARTPFAD eq ''; 

print 'Untersuche ', $STARTPFAD eq '.' ? 'aktuelles Verzeichnis' : $STARTPFAD,
      "\n"; 

chdir($STARTPFAD) || die "Kann Startpfad $STARTPFAD nicht finden!\n";

&ScanDir;

$VERBOSE && print "\n";

foreach (sort keys %extCount) {
    printf "%-8s%6s Datei(en) %9s MB\n",
           $_,
           &formint($extCount{$_}),
           &formsize($extSize{$_});
}

print $errorcount, " Fehler sind aufgetreten.\n" if $errorcount;
print &formint($dircount), ' Verzeichnissen (max. Tiefe: ', $maxtiefe, ') mit ',
      &formint($filecount), ' Dateien in ',
      &formsize($filevolume), " GB untersucht.\n";
print scalar keys %extCount, " verschiedene Dateitypen gefunden.\n",
      "Fertig.\n";

