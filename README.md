# MariaDB Backup Script
## Developed by DESENBAHIA-GTI Team
This shell script implelements multi-database backup operation for MariaDB. It provides 
It dumps all databases (compressed using gzip) into an specifc directory labeled by "date-hour".
Its log feature sends messages to the stdout and to a file as well.
Dump files overwriten at the same hour.
It was built with modularity, extensibility and simplicity in mind.

Tested in MariaDB 10.3.16 version

## Try...catch approach
{ commandA && commandB } || { block C }
If commandA succeeds, runs commandB (and so on); if it fails, runs block C
### Optional:
Use trap to capture unexpected/signal errors
The adoption of "||" as error handler doesn't ensure the other part gets executed even under
exceptional conditions (signals), which is pretty much what one expects from finally. That's the reason 
of the function signal_error().

## Strongly recomended: create ~/.my.cnf file with credentials
[mysql]
user=myuser
password=secret

[mysqldump]
user=myuser
password=secret

$ chmod 660 ~/.my.cnf
