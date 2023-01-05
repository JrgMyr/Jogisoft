#!perl -w
# analyzeXML.pl
# My 2017-07-14, 2017-08-25, 2020-07-27

$PROGRAM   = 'analyzeXML';
$VERSION   = 'V0.21';
$DESCRPT   = 'Baumstruktur einer XML-Dateien sichtbar machen.';

$VERBOSE = $QUIET = $CONTINUE = $NONUMBERS = $WRITETOFILE = 0;
$AUSGABE = 2;
$trenn = ' - ';
$DATEINAME = '';

sub usage {
	print 'Usage: ', $PROGRAM, " [Parameter] Datei\n",
		$DESCRPT, "\n\n",
		"Parameter:\n",
		"\t-a\tAusfuehrliche Textmeldungen\n",
		"\t-c\tNach Fehler weitermachen\n",
		"\t-d\tDOS-Zeilenenden <CRLF>\n",
		"\t-h\tDiese Hilfe ausgeben\n",
		"\t-k\tAusgabe nur Baum-Knoten\n",
		"\t-n\tAusgabe ohne Zahlen am Zeilenanfang\n",
		"\t-o\tAusgabe Baum ohne Details\n",
		"\t-q\tKeine Textmeldungen\n",
		"\t-t\tAusgabe Baum mit Details (Vorgabe)\n",
		"\t-u\tUNIX-Zeilenenden <LF> (Vorgabe)\n",
		"\t-v\tVersion anzeigen\n",
		"\t-w\tAnalyseergebnis in Datei schreiben\n";
    exit;
}

sub version {
	print $PROGRAM, $trenn, $VERSION, $trenn, $DESCRPT, "\n";
	exit;
}


sub formint {
	my $t = shift;

	if ($t > 1000000) {
		$t =~ s/(.+)(...)(...)$/$1.$2.$3/;
	}
	elsif ($t > 1000) {
		$t =~ s/(.+)(...)$/$1.$2/;
	}
	
	return $t;
} 

if (@ARGV == 0) {
	die $PROGRAM, ": Kein Parameter angegeben.\n";
}

foreach (@ARGV) {
	if (substr($_, 0, 1) eq '-') {
		m/a/ && ($VERBOSE = 1);
		m/c/ && ($CONTINUE = 1);
		m/d/ && ($/ = "\r\n");
		m/h|\?/ && &usage();
		m/k/ && ($AUSGABE = 0);
		m/n/ && ($NONUMBERS = 1);
		m/o/ && ($AUSGABE = 1);
		m/q/ && ($QUIET = 1);
		m/t/ && ($AUSGABE = 2);
		m/u/ && ($/ = "\n");
		m/v/ && &version();
		m/w/ && ($WRITETOFILE= 1);
	}
	elsif ($DATEINAME eq '') {
		$DATEINAME = $_;
	}
	else {
		print "Bitte nur einen Dateinamen angeben!\n";
	}
}

$zeilen = $element = $tiefe = $folgenlaenge = $maxtiefe = 0;
@tagstack = ();
%tag_wied = %path_wied = %tag_is_leaf = %tag_is_node = %tag_folg_anz = ();
%path_val_typ = %path_val_min = %path_val_max = %path_val_max_len = ();
$tagcount = $valuecount = $errorcount = $opentags = $emptytags = $closingtags = $specialtags = 0;
$lasttag = $lastendtag = $lastvalue = '';

print $DESCRPT, "\n" unless $QUIET;

if ($DATEINAME eq '') {
	print "-- Lese von Standard-Input\n" unless $QUIET;
	open(INP, '-');  # STDIN
	$DATEINAME = $PROGRAM;
}
else {
	print '-- Lese Datei ', $DATEINAME, "\n" unless $QUIET;
	open(INP, '<' . $DATEINAME) || die "$DATEINAME ... geht nicht auf!\n";
}

print '-- Ausgabe ',
	($AUSGABE == 0) ? 'nur der Knotentruktur ohne Werte-Tags' : '',
	($AUSGABE == 1) ? 'des Tag-Baums ohne Werte-Details' : '',
	($AUSGABE == 2) ? 'des Tag-Baums mit Werte-Intervallen' : '', "\n"
		unless $QUIET;

while (<INP>) {
	chomp;
	$zeilen++;
	next if /^$/;
	
	if (/\t/) {
		print 'Zeile ', &formint($zeilen), ": Tab-Symbol wird gegen Leerzeichen ersetzt.\n";
		s/\t/ /g;
	}

	s/<br>/ /g;
	s/<!\[CDATA\[//g;
	s/]]>//g;
	s/</\t</g;
	s/>/>\t/g;
	s/\t\t/\t/g;
	s/^\t//;
	s/\t$//;

	@elemente = split "\t", $_;
	$element = 0;
	
	foreach (@elemente) {
		$element++;

		if (substr($_, 0, 1) eq '<') {
			$tagcount++;
		
			if (substr($_, -2, 1) eq '?') {
				# Spezial-Tag
				$specialtags++;
				$_ = substr($_, 2, length($_) - 3);
			}
			elsif (substr($_, -2, 1) eq '/') {
				# Leer-Tag
				$emptytags++;
				$_ = substr($_, 1, length($_) - 3);
			}
			elsif (substr($_, 1, 1) eq '/') {
				# Ende-Tag
				$closingtags++;
				$_ = substr($_, 2, length($_) - 3);

				$stacktop = pop @tagstack;
				$tiefe--;
				if ($_ eq $stacktop) {
					# Tag passt zu Tag-Stapel
					if ($_ eq $lasttag && $lastvalue ne '') {
						$tag_is_leaf{join('/', @tagstack, $_)} = 1;
					}
				}
				else {
					# Tag-Stapel passt nicht!
					print 'Zeile ', &formint($zeilen), ', Element ', $element,
						': Endetag <', $_, '> passt nicht zu Tag-Stapel <',
						join('/', @tagstack, $stacktop), ">\n";
					$errorcount++;
				}
				
				$lastendtag = $_;
				$lasttag = '';
			}
			else {
				# Start-Tag
				$_ = substr($_, 1, length($_) - 2);

				if ($_ eq '' || $_ eq ' ') {
					print 'Zeile ', &formint($zeilen), ', Element ', $element,
						': Leerer Tag ignoriert.', "\n";
					$errorcount++;
				}
				elsif ($_ eq 'br') {
					# Kommt nicht mehr vor! Wird weiter oben gegen Leerzeichen ersetzt
					# um Wert in einem Element zu behalten!
					print 'Zeile ', &formint($zeilen), ', Element ', $element,
						': <br>-Tag ignoriert.', "\n";
					$errorcount++;
				}
				else {
					$opentags++;

					$tag_is_node{join('/', @tagstack)} = 1 if $lasttag ne '';
					
					push @tagstack, $_;
					$tiefe++;
					$maxtiefe = $tiefe if $tiefe > $maxtiefe;

					$tag_wied{$_}++;

					$path = join('/', @tagstack);
					$path_wied{$path}++;
					
					if ($_ eq $lastendtag) {
						$folgenlaenge++;
						if (exists $tag_folg_anz{$path}) {
							# ***
						}
						else {
							# ***
						}
					}	
					else {
						$folgenlaenge = 0;
						# ***
					}

					if (length $path > 74) {
						$path = '... ' . substr($path, -68, 68);
					}
					print '-', $tiefe, '-  ', $path, "\n" if $VERBOSE;
					
					$lasttag = $_;
				}
				
				$lastvalue = '';
			}
		}
		else {
			$valuecount++;
			$path = join('/', @tagstack);
			
			substr($_, 0, 1) = '' if substr($_, 0, 1) eq ' ';
			
			if (not exists $path_val_typ{$path}) {
				$path_val_typ{$path} = '-';
			}
			$bisherTyp = $path_val_typ{$path};
			
			$aktTyp = $_ eq '' ? '-' : '?';
			$aktTyp = 'Z' if m/^\d\d:\d\d:\d\d,?\d*$/;
			$aktTyp = 'R' if m/^-?[0-9.,]+$/;
			$aktTyp = 'D' if m/^\d{1,4}([.\/\-])\d\d?\1\d{1,4}$/;
			$aktTyp = 'I' if m/^-?\d+$/;
			$aktTyp = 'L' if m/^-?\d{10,}$/;
			$aktTyp = 'T' if m/[A-Za-z]/;
			
			if ($bisherTyp eq 'I' or
				$bisherTyp eq 'R' or
				$bisherTyp eq 'L' ) {
					if ($aktTyp eq 'R') {
						$path_val_typ{$path} = 'R';
					}
					elsif ($aktTyp eq 'T' or
						$aktTyp eq 'D') {
							$path_val_typ{$path} = 'T';
							# Evtl. Hinweis vermerken.
					}
			}
			elsif ($bisherTyp eq 'T' or $bisherTyp eq 'D') {
				# nix
			}
			else {
				$path_val_typ{$path} = $aktTyp
					if $aktTyp ne '-' and $aktTyp ne $path_val_typ{$path};
			}
			
			if (exists $path_val_min{$path}) {
				$path_val_min{$path} = $_ if $_ lt $path_val_min{$path};
			}
			else {
				$path_val_min{$path} = $_;
			}
			
			if (exists $path_val_max{$path}) {
				$path_val_max{$path} = $_ if $_ gt $path_val_max{$path};
			}
			else {
				$path_val_max{$path} = $_;
			}
			
			if (exists $path_val_max_len{$path}) {
				$path_val_max_len{$path} = length($_) if length($_) gt $path_val_max_len{$path};
			}
			else {
				$path_val_max_len{$path} = length($_);
			}
			
			$lastvalue = $_;
		}
	}
}

close INP;

print "\n" unless $QUIET;

if ($CONTINUE || not $errorcount) {

	if ($AUSGABE == 0) {
		foreach $key (sort keys %path_wied) {
			if ($NONUMBERS) {
				print $key, "\n" if $tag_is_node{$key};
			}
			else {
				print $path_wied{$key}, "\t", $key, "\n" if $tag_is_node{$key};
			}
		}
		
	}
	else {
		foreach $key (sort keys %path_wied) {
			($path = $key) =~ s+[A-Za-z0-9]*/+|   +g;
			if (exists $path_val_min{$key} && $AUSGABE == 2) {
				if ($path_val_min{$key} eq $path_val_max{$key}) {
					$range = '   (nur "' . 
						(length($path_val_min{$key}) < 20 ? $path_val_min{$key} : (substr($path_val_min{$key}, 0, 15) . '>')) .
						'"';
				}
				else {
					$range = '   ("' . 
						(length($path_val_min{$key}) < 12 ? $path_val_min{$key} : (substr($path_val_min{$key}, 0, 11) . '>')) . 
						'" -- "' . 
						(length($path_val_max{$key}) < 12 ? $path_val_max{$key} : (substr($path_val_max{$key}, 0, 11) . '>')) .
						'"';
				}
				
				$range .= ', Typ ' . $path_val_typ{$key}
					unless $path_val_typ{$key} eq '-' or $path_val_typ{$key} eq 'T';

				if ($path_val_max_len{$key} > 100) {
					$range .= ', MaxLen=' . $path_val_max_len{$key};
				}
				
				$range .= ')';
			}
			else {
				$range = '';
			}
			
			$symbol = '';
			$symbol .= '+' if $tag_is_node{$key};
			$symbol .= '-' if $tag_is_leaf{$key};
			$symbol = ' ' if $symbol eq '';

			if ($NONUMBERS) {
				printf "%s %s%s\n", $symbol, $path, $range;
			}
			else {
				printf "%5i   %s %s%s\n", $path_wied{$key}, $symbol, $path, $range;
			}
		}
	}

	print "\n" unless $QUIET;
}

foreach $key (sort keys %path_wied) {
	if (exists $path_val_max_len{$key} && $path_val_max_len{$key} > 250) {
		print 'Langer Wert bei <', $key, '> mit ', $path_val_max_len{$key},  " Zeichen!\n";
	}
}

print $errorcount == 1 ? 'Ein' : $errorcount, ' Fehler ', 
	$errorcount == 1 ? 'ist' : 'sind', " aufgetreten.\n" if $errorcount;
print	&formint($zeilen), ' Zeilen mit ', 
	&formint($tagcount), ' Tags und ', 
	&formint($valuecount), ' Werten gelesen.' , "\n",
	'Maximale Schachtel-Tiefe der Tags ist ', $maxtiefe, ".\n"
		unless $QUIET;
print "Fertig.\n";
