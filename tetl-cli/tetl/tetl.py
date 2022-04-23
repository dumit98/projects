#!/usr/bin/env python3

from datetime import datetime
from cetdm.etl import tiny_etl
import argparse
import sys


def main():
    args = parse_arguments()

    tiny_etl(args.sql, args.target_name, args.target_db,
              args.source_db, False, args.if_exists)


class CustomFormatter(argparse.HelpFormatter):

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
                parts[-1] += ' %s'%args_string
            return ', '.join(parts)

    def _get_help_string(self, action):
        help = action.help
        if '%(default)' not in action.help:
            if action.default is not argparse.SUPPRESS:
                defaulting_nargs = [argparse.OPTIONAL, argparse.ZERO_OR_MORE]
                if action.option_strings or action.nargs in defaulting_nargs:
                    help += ' (default: %(default)s)'
        return help

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


def parse_arguments():
    parser = argparse.ArgumentParser(
        prog='tetl',
        formatter_class=CustomFormatter,
        description='cli wrapper for the tiny_etl module')

    parser.add_argument('sql', metavar='SQL', nargs='?', default=sys.stdin,
                        help='sql to run, can also be piped')
    parser.add_argument('-s', '--source-db', default=['all'], nargs='+',
                        choices=['all', 'edm', 'fra', 'houstby', 'nor', 'sha', 'dw'],
                        help='source database, space separated if more than 1')
    parser.add_argument('-t', '--target-db', default='excel',
                        choices=['excel', 'dw', 'ds'],
                        help='target database')
    parser.add_argument('-n', '--target-name', default=f'Report-{datetime.now().strftime("%Y%m%d-%H%M%S")}.xlsx',
                        help='target name for database table or excel spreadsheet')
    parser.add_argument('-if', '--if-exists', default='drop',
                        choices=['drop', 'append', 'delete'],
                        help='if table exist, what to do')

    args = parser.parse_args()
    try:
        args.sql = args.sql.read()
    except AttributeError:
        pass

    if args.target_name[-4:] == 'xlsx' and args.target_db != 'excel':
        parser.error('TARGET_NAME seems to be an excel file, did you meant a database table?')

    if 'all' in args.source_db:
        args.source_db = 'all'

    return args


if __name__ == '__main__':
    main()
