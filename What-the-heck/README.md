This folder contains a simple shell-based abbreviation lookup called "What-the-heck".

I consists of a Bash function called "wth" and a set of lookup files. Those reside into a folder "/usr/local/share/wth".

An installation script is provided. It does three things: creating the target folder, unziping the files into that folder and registering the lookup function "wth" in the Bash resource file "~/.bashrc". You have to close Bash once after installation to allow it to read the function definition upon invocation.

After that you may try
> wth az

or any other abbreviation that comes to mind.
