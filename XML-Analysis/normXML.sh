#!/bin/sh
# Joerg Meyer, 2017-07-14 .. 2017-08-16

echo "XML-Dateien normalisieren"

if [ x"$1" = x ]
then echo "usage: $0 filename(s)";
    exit 1;
fi

for fnm in $*; do

	nfn=norm_$fnm;

	echo Bearbeite Datei $fnm ... $nfn

	sed	-e ':x; /[-+A-Za-z0-9 .,:;%\/()]$/ { N; s/\n/; /; tx }' \
		-e 's/\t/ /g' \
		-e 's/<br>/; /g' \
		-e 's/,; /, /g' \
		-e 's/, ; /, /g' \
		-e 's/[ ;]*]]>/]]>/g' \
		-e 's/[ ;]*</</g' \
		-e 's/<!\[CDATA\[\([-+A-Za-z0-9 .,:;%\/()]*\)]]>/\1/g' \
		$fnm > $nfn;

done

echo "Fertig."
