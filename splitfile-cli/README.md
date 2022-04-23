# Splitfile.py 

Split a file and parallely execute a command with the splitted files.
<br/><br/>

###### Usage

``` sh
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
