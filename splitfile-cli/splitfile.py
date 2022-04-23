#!/usr/bin/env python3

import os
import argparse
import subprocess

from re import search
from math import ceil
from string import Template
from threading import Thread
from itertools import groupby
from itertools import dropwhile
from itertools import zip_longest


class CustomStringTemplate(Template):
    delimiter = '%'


def main():
    global args
    args = parse_arguments()

    files = split_file(args.file, args.size, args.number)
    log_dirs = [x.split('.')[0] for x in files]
    threads = []

    if args.exec:

        command = CustomStringTemplate(' '.join(args.exec))

        # make log dirs
        for opt in args.exec:
            if search(r'\W%l(\W+|$)', opt):
                try:
                    logdir = opt.split('=')[1]
                except IndexError:
                    logdir = opt
                for logdir_name in log_dirs:
                    slogdir = CustomStringTemplate(logdir)
                    d = slogdir.safe_substitute(l=logdir_name)
                    os.makedirs(d, exist_ok=True)

        # spin up the threads
        i = 1
        for f, d in zip_longest(files, log_dirs):

            fmt_map = {'f': f,  # file name
                       'l': d,  # log directory
                       'F': f.split('.')[0],   # file name base
                       'e': f.split('.')[-1],  # file name ext
                       'i': i   # counter
                       }

            command_fmtd = command.safe_substitute(**fmt_map)
            thread = Thread(target=subprocess.run,
                            args=(command_fmtd.split(),),
                            kwargs={'shell': os.name == 'nt'})
            thread.start()
            threads.append(thread)
            print(command_fmtd)
            i += 1

        # wait for threads to finish
        for thread in threads:
            thread.join()


def split_file(file, split_size=None, nfiles=None):

    fname_base, fname_ext = file.name.split('.')
    file = list(file)
    out_files = []
    mode = 'w'

    if nfiles:
        split_size = ceil(len(file) / nfiles)

    if args.group_by:

        def get_index_keys(row):
            keys = []
            for i in args.group_by:
                keys.append(row[i-1])
            return keys

        input_rows_parsed = map(lambda row: row.split(args.delim), file)
        input_rows_cleaned = dropwhile(lambda row: len(row) <= 1, input_rows_parsed)
        input_rows_sorted = sorted(input_rows_cleaned, key=get_index_keys)

        i = 0
        chunks = []
        for _, chunk in groupby(input_rows_sorted, key=get_index_keys):
            out_fname = f'{fname_base}_{i+1}.{fname_ext}'
            chunk = list(chunk)
            chunks += chunk

            if len(chunks) >= split_size:
                if args.heading:
                    mode = 'a'
                    open(out_fname, 'w').write(args.heading)
                open(out_fname, mode).writelines([args.delim.join(i) for i in chunks])
                out_files.append(out_fname)
                chunks = []
                i += 1

        # residual data
        if args.heading:
            open(out_fname, 'w').write(args.heading)
        open(out_fname, mode).writelines([args.delim.join(i) for i in chunks])
        out_files.append(out_fname)

    else:

        for i, chunk in groupby(enumerate(file), lambda x: x[0] // split_size):
            out_fname = f'{fname_base}_{i+1}.{fname_ext}'
            if args.heading:
                mode = 'a'
                open(out_fname, 'w').write(args.heading)
            open(out_fname, mode).writelines([l for i,l in chunk])
            out_files.append(out_fname)

    return out_files


def parse_arguments():

    class CustomFormatter(argparse.RawTextHelpFormatter):

        def __init__(self, prog):
            super().__init__(prog, width=80)

        def _format_action_invocation(self, action):
            if not action.option_strings:
                metavar, = self._metavar_formatter(action, action.dest)(1)
                return metavar
            else:
                parts = []
                if action.nargs == 0:
                    parts.extend(action.option_strings)
                else:
                    default = action.dest.upper()
                    args_string = self._format_args(action, default)
                    for option_string in action.option_strings:
                        parts.append('%s' % option_string)
                    parts[-1] += ' %s'% args_string
                return ', '.join(parts)

        def _metavar_formatter(self, action, default_metavar):
            if action.metavar is not None:
                result = action.metavar
            elif action.choices is not None:
                choice_strs = [str(choice) for choice in action.choices]
                result = '{%s}' % '|'.join(choice_strs)
            else:
                result = default_metavar

            def format(tuple_size):
                if isinstance(result, tuple):
                    return result
                else:
                    return (result, ) * tuple_size
            return format

        def _fill_text(self, text, width, indent):
            return ''.join(indent + line for line in text.splitlines(keepends=True))

    parser = argparse.ArgumentParser(
        formatter_class=CustomFormatter,
        description='split a file and parallely execute a command with the splitted files',
        epilog=('example:\n  %(prog)s -f myfile.txt -s 100 --exec "mycmd '
                '-input_file=%%f -log_dir=log\%%l ..."'))
    parser.add_argument('-f', '--file', metavar='FILE', required=True,
                        type=argparse.FileType('r'),
                        help='the input file to be split')
    parser.add_argument('-s', '--size', metavar='NUM', required=False, type=int,
                        help='size in NUM of lines/records per splitted FILE, or')
    parser.add_argument('-n', '--number', metavar='NUM', required=False, type=int,
                        help='generate NUM output files')
    parser.add_argument('-H', '--heading', required=True, choices=['y', 'n'],
                        help='specify if the file has a heading')
    parser.add_argument('-g', '--group-by', metavar='NUM[,NUM]', required=False,
                        type=lambda x: [int(i) for i in x.split(',')],
                        help=('group by index NUM first and then split without\nbreaking '
                              'any groups; NUM of lines/records will be\nuneven in this case'))
    parser.add_argument('-d', '--delim', metavar='DELIM', default='|', choices=['|', ','],
                        help='delimiter used by --group-by to separate fields\n(default: "|")')
    parser.add_argument('-w', '--new-window', required=False, default='y', choices=['y', 'n'],
                        help='wether to run the COMMAND in separate new windows\n(default: y)')
    parser.add_argument('--exec', metavar='"COMMAND"', required=False,
                        type=lambda x: [i for i in x.split()],
                        help=('command to be executed, interpetring string\nsubstitions '
                              'prefixed with the %% character;\nthe string substitutions are:\n\n'
                              '%%f\tfile name\n'
                              '%%F\tbase file name\n'
                              '%%e\tfile extension\n'
                              '%%i\tcounter\n'
                              '%%l\tlog directory; note that the log directory\n'
                              '\twill be created if not found'))

    args = parser.parse_args()

    if args.size and args.number:
        parser.error('cannot use -s/--size and -n/--number at the same time')

    if not args.size and not args.number:
        parser.error('required -s/--size or -n/--number')

    if args.heading == 'y':
        args.heading = next(args.file)
    else:
        args.heading = None

    if args.new_window == 'y' and args.exec:
        args.exec = ['start', 'cmd', '/c'] + args.exec

    return args


if __name__ == '__main__':
    main()
