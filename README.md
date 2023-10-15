# YATERM
YATERM is a homebrew terminal application written in 8080 assembly from scratch, targeting the Altair 8800 (Altairduino). This was mostly as an exercise of "do I understand the 8080 enough to do something useful"

## YATERM V2.0
This version of YATERM is completely rewritten from scratch, using my 2 years of experience since starting the first version.

#### Important!
File sending works...mostly!
The first character doesn't show on the screen (yet).

#### How to use
Press Ctrl-O to open up the menu, then navigate using specified keypresses.
In order to send files, the file MUST be in the same directory as YATERM.COM (will be changed in the future).

Right now, receiving files does not work.


##### Bugs
- Upon exit and restart, the altair terminal screen no longer seems to respond to the connected computer
- Menu behavior may not be ideal quite yet (pauses/no pauses where there shouldn't be)