# Python Scripts 

- [vl](https://github.com/dumit98/proyects/tree/master/vl)
- [quick_etl](https://github.com/dumit98/projects/tree/master/etl)
- [more to come](#moretocome)

# vl

`vl` or `validate_load` is a command line interface written in python for loading and validating data. It is useful for repetitive data validation tasks.

###### Usage
```sh
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

In order to validate the data, the script works with [user-defined sql files](https://github.com/dumit98/projects/blob/master/samples/item_load_report(sample).sql) (packages) with placeholders that the script will use to replace with input arguments, i.e., `table_name`, `site` (db_link), etc.

**Example 1:** load an excel file to database and confirm by checking table info and running select/update statements.
```sh
# vl commands used
$ vl -h
$ vl load -h
$ vl load Jira4653_itemload_dbTest.xlsx MISC_VLLOAD_DEMO --sheet 0  # load excel file to new table
$ vl sql MISC_VLLOAD_DEMO "info()"  # show table info
$ vl sql MISC_VLLOAD_DEMO "select(tc_id, name1)"  # make a select statement
$ vl sql MISC_VLLOAD_DEMO "update(set tc_id=tc_id||'-DEMO')"  # make an update statement
```
[![vl_load](https://raw.githubusercontent.com/dumit98/projects/748d2885aa7582aac2833109efafbdbf0522ec4c/art/vl_load.gif)](https://drive.google.com/file/d/1Gy31ljHaFssg6rzu03xJ10UZBV_3SIAl/view?usp=sharing)

**Example 2:** run a series of data validations and generate excel reports.
```sh
# vl commands used
$ vl -h
$ vl report -h
$ vl report MISC_VLLOAD_DEMO --package 4 --summary  # print summary only, no report written
$ vl report MISC_VLLOAD_DEMO --package 4  # write reports
```
[![vl_load](https://raw.githubusercontent.com/dumit98/projects/748d2885aa7582aac2833109efafbdbf0522ec4c/art/vl_report.gif)](https://drive.google.com/open?id=137gwJpSeF1aZfk1bOeykIHIew--rB7ln)


# quick_etl
`quick_etl` is a simple python script that lets you extract data from multiple databases using sql statemets and load it to a table or excel spreadsheet

**Example 1:** write a small sample script using `quick_etl` containing a sql statement that will extract data from 5 different databases located in Houston TX, Edmonton Canada, France, Norway and Shanghai and load it to a table.
```sh
# commands used
$ touch quick_etl_demo.py  # create empty file
$ subl quick_etl_demo.py  # open file for editing with sublime text
$ python quick_etl_demo.py &  # run file and send it to the background
$ tail -f -n30 quick_etl_demo.log  # open log file with follow mode
$ vl sql MISC_QUICK_ETL "select(*)"  # run vl command to verify that table was created
```
[![vl_load](https://raw.githubusercontent.com/dumit98/proyects/master/art/quick_etl.gif)](https://drive.google.com/open?id=1aHzSEhyVpO7nxvZ7MUkD-nttLbggu26S)
