This folder shares the tool "analyzeCSV.pl" to analyze files with comma-separated-values (CSV) and another tool "analyzeTBL.pl" to perform exploriative analysis on a SQLite database table, for instance after import.

Preparing files with separated values, being it commas or tabs or other characters is an essential step in database preparation.

The file "csv_test.txt" is a sample data file to test the analysis. It does contain headers however only in line 4 (!). So you might invoke the analysis with "-t 4".

Additionally, an annotated statistics analysis is provided to explain the columns. Invoke the sample file with "-w", in this case with "-wt 4".
