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

### Installation
`vl` can be installed via `setup.py`:

``` 
pip install .
```
