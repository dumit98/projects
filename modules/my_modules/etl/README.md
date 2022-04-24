# etl.tiny_etl()
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
