# YATERM
YATERM is a homebrew terminal application written in 8080 assembly from scratch, targeting the Altair 8800 (Altairduino). This was mostly as an exercise of "do I understand the 8080 enough to do something useful"

## YATERM V2.0
This version of YATERM is completely rewritten from scratch, using my 2 years of experience since starting the first version.


#### Important!
As of now, FILE SENDING DOES NOT WORK. I REPEAT, IN 2.0, FILE SENDING DOES NOT WORK. For reasons unknown, the stack gets absolutely smacked in my file open routines which I have copied from the old version. Also, the actual file sending code sends nothing but absolute garbage instead of the file chunks, so I have no idea what's going on there.

If you want to send files, go to the FROZEN branch.