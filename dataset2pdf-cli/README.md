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
