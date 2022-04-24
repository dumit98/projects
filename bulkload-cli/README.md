# Bulkload.py

A CLI client for the Bulkloader.
<br/><br/>

###### Usage

```
usage: bulkload.py [-h] [-n [{Nov4Part | Documents}]] -u USER -p PASSWORD
                   [-g GROUP] -f FILE -l LOG_DIR [-S SERVER] [-Po PORT_OUT]
                   [-Pi PORT_IN] [-y] [-v] [-e EMAIL] [--release] [--delete]

cli client for Bulkloader

optional arguments:
  -h, --help            show this help message and exit
  -n, --list-field-names [{Nov4Part | Documents}]
                        list the default field names for mapping
  -u, --user USER
  -p, --password PASSWORD
  -g, --group GROUP
  -f, --file FILE       file to load. heading must be included. supported types
                        are: excel:.xlsx/.xls and csv:.csv
  -l, --log-dir LOG_DIR
                        dir path for the log files
  -S, --server SERVER   bulkloader server (default: localhost)
  -Po, --port-out PORT_OUT
                        bulkloader server port (default: 13151)
  -Pi, --port-in PORT_IN
                        bulkload.py client port (default: 13152)
  -y, --yes             assume the answer "yes" to any prompts, proceeding with
                        all operations if possible
  -v, --verbose         increase verbosity
  -e, --notify-to EMAIL
                        notify when finished or on errors
  --release             release the items
  --delete              delete the items
```
<br/><br/>

**Example:** run a data load from a spreadsheet to a test environment.

[![bulkload](https://github.com/dumit98/projects/blob/master/art/bulkload.gif?raw=true)](https://drive.google.com/file/d/1tvq8cenDLiWtTAHCnahxx4vabFM3jaDn/view?usp=sharing)
