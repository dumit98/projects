# Python Scripts 

- [vl](https://github.com/dumit98/projects/tree/master/vl-cli)
- [tiny_etl](https://github.com/dumit98/projects/tree/master/modules/my_modules/etl)
- [dataset2pdf](https://github.com/dumit98/projects/tree/master/dataset2pdf-cli)
- [bulkload](https://github.com/dumit98/projects/tree/master/bulkload-cli)
- [splitfile](https://github.com/dumit98/projects/tree/master/splitfile-cli)
- [tetl](https://github.com/dumit98/projects/tree/master/tetl-cli)
- [sql](https://github.com/dumit98/projects/tree/master/sql)

# vl

`vl` or `validate_load` is a CLI written in python for loading and validating data. It is useful for repetitive data validation tasks.
<br/><br/>

###### Usage
```
$ vl --help
usage: vl [-h] [-l] [-n VALIDATION_TYPE]
          {clone | load | sql | report | input} ...

validate load

optional arguments:
  -h, --help            show this help message and exit
  -l, --list-packages   list available sql validation packages
  -n, --column-names VALIDATION_TYPE
                        naming convention for column titles

commands:
  {clone | load | sql | report | input}
    clone               clone data from staging tables
    load                load an excel/csv file to database
    sql                 execute sql statements like update, select, etc
    report              run reports
    input               create input files
```
<br/><br/>

In order to validate the data, the script works with boiler plate sql [files](https://github.com/dumit98/projects/tree/master/sql) (packages) with placeholders that the script will use to replace with input arguments, i.e., `table_name`, `site` (db_link), etc.
<br/><br/>

**Example 1:** load an excel file to database and confirm by checking table info and running select/update statements.
```
> vl -h
> vl load -h
> vl load Jira4653_itemload_dbTest.xlsx MISC_VLLOAD_DEMO --sheet 0  # load excel file to new table
> vl sql MISC_VLLOAD_DEMO "info()"  # show table info
> vl sql MISC_VLLOAD_DEMO "select(tc_id, name1)"  # make a select statement
> vl sql MISC_VLLOAD_DEMO "update(set tc_id=tc_id||'-DEMO')"  # make an update statement
```
[![vl_load](https://github.com/dumit98/projects/blob/master/art/vl_load.gif?raw=true)](https://drive.google.com/file/d/1Gy31ljHaFssg6rzu03xJ10UZBV_3SIAl/view?usp=sharing)
<br/><br/>

**Example 2:** run a series of data validations and generate excel reports.
```
> vl -h
> vl report -h
> vl report MISC_VLLOAD_DEMO --package 4 --summary  # print summary only, no report written
> vl report MISC_VLLOAD_DEMO --package 4  # write reports
```
[![vl_load](https://github.com/dumit98/projects/blob/master/art/vl_report.gif?raw=true)](https://drive.google.com/open?id=137gwJpSeF1aZfk1bOeykIHIew--rB7ln)
<br/><br/>

# etl.tiny_etl
`etl.tiny_etl()` is a module for extracting data from multiple databases and loading it to a target table or excel file.
<br/><br/>

**Example:** write a small sample script using `tiny_etl` containing a sql statement that will extract data from 5 different databases located in Houston, Edmonton Canada, France, Norway and Shanghai and load it to a table.
```
> touch quick_etl_demo.py  # create empty file
> subl quick_etl_demo.py  # open file for editing
> python quick_etl_demo.py &  # run file and send it to the background
> tail -f -n30 quick_etl_demo.log  # open log file with follow mode
> vl sql MISC_QUICK_ETL "select(*)"  # run vl command to verify that table was created
```
[![vl_load](https://github.com/dumit98/projects/blob/master/art/quick_etl.gif?raw=true)](https://drive.google.com/open?id=1aHzSEhyVpO7nxvZ7MUkD-nttLbggu26S)
<br/><br/>

# dataset2pdf.py

A script for the dataset-to-PDF conversion service.
<br/><br/>

###### Usage
```
usage: dataset2pdf [-h] -u USERNAME -p PASSWORD -log_dir
                                  LOG_DIR -input_file TXT_FILE [-debug]

A python script for the PDF Dataset convertion service

optional arguments:
  -h, --help            show this help message and exit
  -u USERNAME           tc user name
  -p PASSWORD           tc user password
  -log_dir LOG_DIR      path for writting log file
  -input_file TXT_FILE  input text file
  -debug                create debug log

additional information:
  input file format <TcId|RevId|DsName|DsType|FileName|DsNameNew|Monochrome(true|false)|Layout(PAPER|MODEL|BOTH)>
  example file format <51015012-ASM:99|03|51015012-ASM|ACADDWG|51015012-ASM.dwg|51015012-ASM-PDFTEST|true|MODEL>
```
<br/><br/>

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
<br/><br/>

# Splitfile.py 

Split a file and parallely execute a command with the splitted files.
<br/><br/>

###### Usage

``` 
usage: splitfile.py [-h] -f FILE [-s NUM] [-n NUM] -H {y|n} [-g NUM[,NUM]]
                    [-d DELIM] [-w {y|n}] [--exec "COMMAND"]

split a file and parallely execute a command with the splitted files

optional arguments:
  -h, --help            show this help message and exit
  -f, --file FILE       the input file to be split
  -s, --size NUM        size in NUM of lines/records per splitted FILE, or
  -n, --number NUM      generate NUM output files
  -H, --heading {y|n}   specify if the file has a heading
  -g, --group-by NUM[,NUM]
                        group by index NUM first and then split without
                        breaking any groups; NUM of lines/records will be
                        uneven in this case
  -d, --delim DELIM     delimiter used by --group-by to separate fields
                        (default: "|")
  -w, --new-window {y|n}
                        wether to run the COMMAND in separate new windows
                        (default: y)
  --exec "COMMAND"      command to be executed, interpetring string
                        substitions prefixed with the % character;
                        the string substitutions are:

                        %f	file name
                        %F	base file name
                        %e	file extension
                        %i	counter
                        %l	log directory; note that the log directory
                        	will be created if not found

example:
  splitfile.py -f myfile.txt -s 100 --exec "mycmd -input_file=%f -log_dir=log\%l ..."
```
<br/><br/>

# tetl

CLI wrapper for the [`etl.tiny_etl`](https://github.com/dumit98/projects/tree/master/modules/my_modules/etl) module. Extract data from a site(s) and load to a db or excel file with one command.
<br/><br/>

###### Usage

```
usage: tetl [-h]
            [-s {all|edm|fra|houstby|nor|sha|dw} [{all|edm|fra|houstby|nor|sha|dw} ...]]
            [-t {excel|dw|ds}] [-n TARGET_NAME] [-if {drop|append|delete}]
            [SQL]

cli wrapper for the tiny_etl module

positional arguments:
  SQL                   sql to run, can also be piped (default:
                        <_io.TextIOWrapper name='<stdin>' mode='r'
                        encoding='UTF-8'>)

optional arguments:
  -h, --help            show this help message and exit
  -s, --source-db {all|edm|fra|houstby|nor|sha|dw} [{all|edm|fra|houstby|nor|sha|dw} ...]
                        source database, space separated if more than 1
                        (default: ['all'])
  -t, --target-db {excel|dw|ds}
                        target database (default: excel)
  -n, --target-name TARGET_NAME
                        target name for database table or excel spreadsheet
                        (default: Report-20220421-232041.xlsx)
  -if, --if-exists {drop|append|delete}
                        if table exist, what to do (default: drop)
```
<br/><br/>

