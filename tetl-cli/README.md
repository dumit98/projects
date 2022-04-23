# tetl

CLI wrapper for the [`etl.tiny_etl`](https://stash.nov.com:8443/projects/CDM/repos/cetdm_python/browse/etl) module. Extract data from a site(s) and load to a db or excel file with one command.
<br/><br/>

###### Usage

``` sh
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

### Installation
`tetl` can be installed via `setup.py`

``` sh
pip install .
```
