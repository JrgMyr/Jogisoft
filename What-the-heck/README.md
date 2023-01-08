This folder contains a simple abbreviation lookup function for the Bash shell.

I consists of a Bash function called "wth" and a set of lookup files. Those go into a folder "/usr/local/share/wth".

A installation script does three steps, create the target folder, unzip the files into that folder and register the lookup function wth in the Bash resource file "~/.bashrc". You have to close Bash once after installation once to allow it to read the function definition upon invocation.

Try
> wth az
