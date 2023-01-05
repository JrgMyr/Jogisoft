#!/usr/bin/env perl
# (c) Joerg Meyer, 2020-11-27..30, 2023-01-05
# Code copyrighted and shared under GPL v3.0
# mailto:info@jogisoft.de

use warnings;
# use UTF8;
use DBI;
use DBD::SQLite;

$PROGRAM = 'analyzeTBL.pl';
$VERSION = 'v0.03';
$DESCRPT = 'Analyze fields and values inside a SQLite database';

sub usage {
    print 'Usage: ', $PROGRAM, " [Parameter] Datenbank Tabelle(n)\n",
          $DESCRPT, "\n\n",
          "Parameter:\n",
          "\t-a\tAusfuehrliche Textmeldungen\n",
          "\t-h\tDiese Hilfe ausgeben\n",
          "\t-n\tAnalyse-Tabelle neu anlegen\n",
          "\t-q\tKeine Textmeldungen\n",
          "\t-v\tVersion anzeigen\n";
    exit;
}

if (@ARGV == 0) {
    die $PROGRAM, ": Keine Parameter und keine Datei angegeben!\n\n";
}

$CREATESTAT = $AUSFUEHRL = $STUMM = $totalfields = 0;
$DBNAME = '';
@TABELLEN = ();

foreach (@ARGV) {
    if (substr($_, 0, 1) eq '-') {
        m/a/ && ($AUSFUEHRL = 1);
        m/h/ && &usage;
        m/n/ && ($CREATESTAT = 1);
        m/q/ && ($STUMM = 1);
        m/v/ && die $PROGRAM, ' -- ', $VERSION, "\n";
    }
    else {
        if ($DBNAME eq '') {
            $DBNAME = $_;
        }
        else {
            push @TABELLEN, $_;
        }
    }
}

print $DESCRPT, "\n" unless $STUMM;
print "Ausfuehrliche Meldungen mit SQL-Aufrufen\n"
    if $AUSFUEHRL;

die "Name der SQLite-Datenbank und mindestens einer Tabelle angeben!\n"
    if scalar @TABELLEN == 0;

if (! -e $DBNAME) {
    my @EXTLIST = ('.sqlite', '.sqlite3', '.db');
    foreach $ext (@EXTLIST) {
        if (-e $DBNAME . $ext) {
            print 'Kann Datei "', $DBNAME, '" nicht finden, wohl aber "',
                  $DBNAME. $ext, '".', "\n"
                unless $STUMM;
            $DBNAME .= $ext;
            last;
        }
    }
}

print 'Oeffne Datenbank: ', $DBNAME, "\n"
    unless $STUMM;

$dbh = DBI->connect('dbi:SQLite:dbname='. $DBNAME, '', '')
    or die "Kann Datenbank nicht oeffnen!\n";

foreach $table (@TABELLEN) {
    $stat = $table . '_stat';

    print '-' x 40, "\n", 'Analysiere Tabelle: ', $table, "\n"
        unless $STUMM;

    if ($CREATESTAT) {
        $sql = 'DROP TABLE IF EXISTS '. $stat;
        print "--> $sql\n" if $AUSFUEHRL;
        $sth = $dbh->prepare($sql);
        $sth->execute or print 'FEHLER: ', $DBI::errstr, "\n";

        $sql = 'CREATE TABLE ';
    }
    else {
        $sql = 'CREATE TABLE IF NOT EXISTS ';
    }

    $sql .= '"'. $stat. '" (Feld TEXT, Typ TEXT, ...)';
    print "--> $sql\n" if $AUSFUEHRL;

    $sql = 'CREATE TABLE IF NOT EXISTS "'. $stat.
           '" (Feld TEXT, Typ TEXT, '.
           'Inhalt INTEGER, LeerNull INTEGER, SqlNull INTEGER, '.
           'Minimum TEXT, Maximum TEXT, WerteVorrat INTEGER, '.
           'Eindeutig BOOLEAN, Fortlfd BOOLEAN, '.
           'HWertAnz INTEGER, HWertInh TEXT)';
    $sth = $dbh->prepare($sql);
    $sth->execute or print 'FEHLER: ', $DBI::errstr, "\n";

    if (not $CREATESTAT) {
        $sql = 'DELETE FROM "'. $stat. '"';
        print "--> $sql\n" if $AUSFUEHRL;
        $sth = $dbh->prepare($sql);
        $sth->execute or print 'FEHLER: ', $DBI::errstr, "\n";
    }

    @felder = ();
    %typ = ();
    %werte = ();

    $sql = 'SELECT name, type FROM pragma_table_info("'. $table. '")';
    print "--> $sql\n" if $AUSFUEHRL;
    $sth = $dbh->prepare($sql);
    $sth->execute or print 'FEHLER: ', $DBI::errstr, "\n";

    while (@ergeb = $sth->fetchrow_array()) {
        push @felder, $ergeb[0];
        $typ{$ergeb[0]} = $ergeb[1];
    }
    $sth->finish();
    $totalfields += scalar @felder;

    $anzrec = 0;
    $sql = 'SELECT COUNT(*) FROM "'. $table. '"';
    print "--> $sql\n" if $AUSFUEHRL;

    $sth = $dbh->prepare($sql);
    $sth->execute or print 'FEHLER: ', $DBI::errstr, "\n";
    ($anzrec) = $sth->fetchrow();

    print 'Tabelle ', $table, ' hat ',
          scalar @felder, ' Felder und ',
          $anzrec, ' Zeilen.', "\n"
        unless $STUMM;

    $n = 0;
    foreach $feld (@felder) {
        $n++;

        printf "   %03d  %-20s  %-15s\n", $n, $feld, $typ{$feld}
            unless $STUMM;

        if (substr($typ{$feld}, 0, 4) eq 'TEXT') {
            $vgl = "''";
        }
        else {
            $vgl = 0;
        }

        $sth = $dbh->prepare('SELECT COUNT(*) FROM "'. $table. '" WHERE "'.
            $feld. '" > '. $vgl);
        $sth->execute;
        ($werte{'Inhalt'}) = $sth->fetchrow();

        $sth = $dbh->prepare('SELECT COUNT(*) FROM "'. $table. '" WHERE "'.
            $feld. '" = '. $vgl);
        $sth->execute;
        ($werte{'LeerNull'}) = $sth->fetchrow();

        $sth = $dbh->prepare('SELECT COUNT(*) FROM "'. $table. '" WHERE "'.
            $feld. '" IS NULL');
        $sth->execute;
        ($werte{'SqlNull'}) = $sth->fetchrow();

        $sth = $dbh->prepare('SELECT MIN(['. $feld. ']), '.
            'MAX("'. $feld. '") FROM "'. $table. '"');
        $sth->execute;
        ($werte{'Minimum'}, $werte{'Maximum'}) = $sth->fetchrow();

        $sth = $dbh->prepare('SELECT COUNT(*) FROM (SELECT DISTINCT "'.
            $feld. '" FROM "'. $table. '")');
        $sth->execute;
        ($werte{'WerteVorrat'}) = $sth->fetchrow();

        $sth = $dbh->prepare('SELECT "'. $feld. '", COUNT(*) '.
            'FROM "'. $table. '" '.
            'WHERE "'. $feld. '" IS NOT NULL '.
            'GROUP BY 1 ORDER BY 2 DESC');
        $sth->execute;
        ($werte{'HWertInh'}, $werte{'HWertAnz'}) = $sth->fetchrow();

        $FORTLFD = '0';
        if (substr($typ{$feld}, 0, 3) eq 'INT' and
            $anzrec == $werte{'Maximum'} - $werte{'Minimum'} + 1) {
                $FORTLFD = '1';
        }

        $sql = 'INSERT INTO ' . $stat . ' VALUES ('.
               '"'. $feld. '", '.
               '"'. $typ{$feld}. '", '.
               $werte{'Inhalt'}. ', '.
               $werte{'LeerNull'}. ', '.
               $werte{'SqlNull'}. ', '.
               '"'. $werte{'Minimum'}. '", '.
               '"'. $werte{'Maximum'}. '", '.
               $werte{'WerteVorrat'}. ', '.
               ($werte{'Inhalt'} == $werte{'WerteVorrat'} ? '1, ' : '0, ').
               $FORTLFD. ', '.
               $werte{'HWertAnz'}. ', '.
               '"'. $werte{'HWertInh'}. '")';
        $dbh->do($sql);
    }
}

$sth->finish();
$dbh->disconnect();

$n = scalar @TABELLEN;

print '-' x 40, "\n", 'Fertig nach ',
      $n == 1 ? 'einer Tabelle' : $n. ' Tabellen',
      ' mit zusammen ', $totalfields, " Feldern.\n"
      unless $STUMM;
