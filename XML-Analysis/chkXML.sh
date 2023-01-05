#!sh

echo Teste XML-Dateien auf Auffaelligkeiten

echo ------------------------- 
echo '>>>' Zaehle Zeilenanfaenge, die keine Tags sind
grep -vc '^<' ${@-*.xml}
echo ''

echo ------------------------- 
echo '>>>' Zaehle '<br>' in CDATA
grep -cP '<\!\[CDATA\[.*?<br>.*?\]\]>' ${@-*.xml}
echo ''

echo ------------------------- 
echo '>>>' Zaehle andere "'<'" in CDATA
grep -cP '<\!\[CDATA\[.*?<[^b][^r].*?\]\]>' ${@-*.xml}
echo ''

echo ------------------------- 
echo '>>>' Teste auf Tags mit Attributen
grep -cP '<[a-z][^>]*=[^>]*>' ${@-*.xml}  | grep -v ':0$'
echo ''

echo ------------------------- 
echo '>>>' Teste auf Tabulatoren
grep -cP '\t' ${@-*.xml} | grep -v ':0$' 
echo ''

echo ------------------------- 
echo '>>>' Teste auf senkrechte Striche '(Pipe-Symbol)'
grep -c '|' ${@-*.xml} | grep -v ':0$' 
echo ''

echo ------------------------- 
echo '>>>' Teste auf fuehrende Leerzeichen in CDATA
grep -c '<!\[CDATA\[ ' ${@-*.xml} | grep -v ':0$' 
echo ''

echo ------------------------- 
echo '>>>' Teste auf letzte Leerzeichen in CDATA
grep -c ' ]]>' ${@-*.xml} | grep -v ':0$' 
echo ''

echo ------------------------- 
echo '>>>' Teste auf letzte Leerzeichen in Werten
grep -c ' <' ${@-*.xml} | grep -v ':0$' 
echo ''

echo ------------------------- 
echo Fertig.