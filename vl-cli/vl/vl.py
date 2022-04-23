#!/usr/bin/env python

from .commands import (
    Clone, Sql, Input, Load, Report
)
import argparse
import os
import sys

sys.tracebacklimit = 0


def main():
    msg_no_envvar = 'No environment var: VL_SQL_PATH'
    class_call = '{0}(package_list=pkgs, **vars(args))'
    p = os.getenv('VL_SQL_PATH')
    path = p if p else exit(msg_no_envvar)
    args = parse_arguments()

    pkgs, list_str = list_packages(path)

    if args.subcommand:
        command = args.subcommand.title()
        command = eval(class_call.format(command))
        with command:
            command.execute()
    elif args.validation_type:
        print_naming_convention(args.validation_type)
    elif args.show_pkgs:
        print(list_str)
    else:
        exit(1)


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
                    #parts.append('%s %s' % (option_string, args_string))
                    parts.append('%s' % option_string)
                parts[-1] += ' %s'%args_string
            return ', '.join(parts)

    def _metavar_formatter(self, action, default_metavar):
        if action.metavar is not None:
            result = action.metavar
        elif action.choices is not None:
            choice_strs = [str(choice) for choice in action.choices]
            #  result = '{%s}' % ','.join(choice_strs)
            result = '{%s}' % ' | '.join(choice_strs)
        else:
            result = default_metavar

        def format(tuple_size):
            if isinstance(result, tuple):
                return result
            else:
                return (result, ) * tuple_size
        return format


def parse_arguments():
    parent_parser = argparse.ArgumentParser(add_help=False)
    parent_parser.add_argument(
        '-t', '--table', dest='table_name', type=str.lower, required=True)
    parser = argparse.ArgumentParser(
        prog='vl', description='validate load', formatter_class=CustomFormatter)
    parser.add_argument(
        '-l', '--list-packages', dest='show_pkgs', action='store_true',
        help='list available sql validation packages')
    parser.add_argument(
        '-n', '--column-names', dest='validation_type',
        help='naming convention for column titles')
    subcommand = parser.add_subparsers(
        title='commands', dest='subcommand')
    cmd_clone = subcommand.add_parser(
        'clone', help='clone data from staging tables',
        formatter_class=CustomFormatter)
    cmd_load = subcommand.add_parser(
        'load', help='load an excel/csv file to database',
        formatter_class=CustomFormatter)
    cmd_dml = subcommand.add_parser(
        'sql', help='execute sql statements like update, select, etc',
        formatter_class=CustomFormatter)
    cmd_report = subcommand.add_parser(
        'report', parents=[parent_parser], help='run reports',
        formatter_class=CustomFormatter)
    cmd_input = subcommand.add_parser(
        'input', parents=[parent_parser], help='create input files',
        formatter_class=CustomFormatter)

    # === Add the options ===
    cmd_clone.add_argument(
        '-i', '--load-id', required=True)
    cmd_clone.add_argument(
        '-s', '--source', default='caps', choices=[
            'caps', 'jde', 'syteline', 'bomload', 'docload', 'docrel'],
        help='default: caps')
    cmd_clone.add_argument(
        '-t', '--target', required=True, dest='table_name', type=str.lower)
    cmd_clone.add_argument(
        '--if-exists', default='replace', choices=['replace', 'append'],
         help='default: replace')
    cmd_clone.add_argument(
        '--dont-clean', action='store_true',
        help='avoid cleaning dataset like fixing status, trimming white space, etc')
    cmd_load.add_argument(
        dest='file_name', nargs='?', metavar='FILE_NAME')
    cmd_load.add_argument(
        dest='table_name', nargs='?', metavar='TABLE_NAME', type=str.lower)
    cmd_load.add_argument(
        '-r', '--repo', dest='load_from_repo', action='store_true',
        help='load latest file from repo/dir')
    cmd_load.add_argument(
        '-s', '--sheet', default='clean',
        help='worksheet name(s) to load. '
       'takes a string, int, list or "all". default is "clean"')
    cmd_load.add_argument(
        '-j', '--join-on', type=lambda x: x.split(','),
        help='join on given column when loading multiple '
        'worksheets. if not concatenate mutliple worksheets.')
    cmd_load.add_argument(
        '--if-exists', default='replace', choices=['replace', 'append'],
         help='default: replace')
    cmd_load.add_argument(
        '--dont-dedup', dest='drop_dup', action='store_false',
        help='avoid dropping duplicate rows')
    cmd_load.add_argument(
        '--dont-clean', action='store_true',
        help='avoid cleaning dataset like fixing status, trimming white space, etc')
    cmd_load.add_argument(
        '--export-file', action='store_true', help='export to an excel file. useful when '
        'concatenating multiple worksheets')
    cmd_dml.add_argument(
        dest='table_name', metavar='TABLE_NAME', type=str.lower)
    cmd_dml.add_argument(
        dest='statement', metavar='STATEMENT', help='{select | update}([distinct | set] <cols> [where])')
    cmd_report.add_argument(
        '-p', '--package', required=False, dest='pckg_no', type=int)
    cmd_report.add_argument(
        '-s', '--site', default='hou', choices=['edm', 'fra', 'hou', 'houp', 'nor', 'sha', 'train'],
        dest='linked_server', help='default: hou')
    cmd_report.add_argument(
        '-f', '--file', metavar='FILENAME', dest='sql_file',help='use sql queries from a file')
    cmd_report.add_argument(
        '-o', '--output', default=os.getcwd(), help='default: current dir')
    cmd_report.add_argument(
        '--after-load', dest='run_afterload_scripts', action='store_true', help='validate after load')
    cmd_report.add_argument(
        '--summary', dest='show_summary', action='store_true', help='run all "counting" queries and ' \
        'display on screen')
    cmd_report.add_argument(
        '--dont-export-sql', action='store_true')
    cmd_input.add_argument(
        '-u', '--utility', dest='input_utility', action='store_true')
    cmd_input.add_argument(
        '-b', '--bulkloader', dest='input_bulkloader', action='store_true')
    cmd_input.add_argument(
        '-p', '--package', required=False, dest='pckg_no', type=int)
    cmd_input.add_argument(
        '-s', '--site', default='hou', choices=['edm', 'fra', 'hou', 'houp', 'nor', 'sha', 'train'],
        dest='linked_server', help='default: hou')
    cmd_input.add_argument(
        '-f', '--file', metavar='FILENAME', dest='sql_file',help='use sql queries from a file')
    cmd_input.add_argument(
        '--dont-export-sql', action='store_true')

    args = parser.parse_args()
    if args.subcommand == 'load':
        if (args.file_name and not args.table_name):
            cmd_load.error("Can't load without TABLE_NAME" )
        if (not args.load_from_repo and not args.file_name):
            cmd_load.error("Need -r or FILE_NAME")
    elif args.subcommand == 'input':
        if (not args.input_utility and not args.input_bulkloader):
            cmd_input.error("Need -u or -b")
        elif not (not args.pckg_no or not args.sql_file):
            p, pkg_list = list_packages(os.getenv('VL_SQL_PATH'))
            cmd_input.error("Need -p or -f\n\n" + pkg_list)
    elif args.subcommand == 'report':
        if (not args.pckg_no and not args.sql_file):
            p, pkg_list = list_packages(os.getenv('VL_SQL_PATH'))
            cmd_report.error("Need -p or -f\n\n" + pkg_list)

    return args


def print_naming_convention(validation_type=None):
    val_types = ['namedesc', 'obsolete', 'supersede', 'ownership', 'active',
        'phase out', 'docload', 'itemload', 'bomload', 'relationload']
    na = 'tc_id, name1, name2, description'
    ob = 'tc_id, status_new'
    su = 'sup_id, sur_id '
    ow = 'tc_id, grp_old, grp_new'
    ac = 'tc_id, status_new'
    ph = 'tc_id, status_new'
    dl = 'doc_id, name, description, revision, revision_status, ' \
        'rev_creation_date, rev_release_date, document_status, ' \
        'document_category, document_type, dataset_name, path_location'
    il = 'tc_id, alternateid, revision, rev_creation_date, name, name2, ' \
        'description, uom, engineering_type, item_status, revision_status, ' \
        'rev_release_date, traceability'
    bl = 'parent_tc_id, parent_gid_id, parent_revision, child_tc_id, ' \
        'child_gid_id, seq_no, quantity, refdefcomments'
    rl = 'item_id, revision, doc_id, relationship_type'
    val_types = zip(val_types, [na, ob, su, ow, ac, ph, dl, il, bl, rl])

    for typ, rule in val_types:
        if validation_type == 'all':
            rule = rule.split(',')
            print('%s\ncols:\n   %s\n' % (typ.upper(), '\n  '.join(rule)))
        elif validation_type in typ:
            rule = rule.split(',')
            if 'load' in validation_type:
                rule = '\t'.join(rule)
            else:
                rule = '\n  '.join(rule)
            print('%s\ncols:\n   %s\n' % (typ.upper(), rule))


def list_packages(path):
    pkgs = []

    for package in os.listdir(path):
        if '.' not in package:
            pkgs.append(os.path.join(path, package))
    pkgs.sort()

    pkgs_enum = enumerate(pkgs, start=1)
    list_str = str('\n'.join([(str(n) + ' ' + os.path.basename(p))
                     for n,p in pkgs_enum]))
    return pkgs, list_str



if __name__ == '__main__':
    main()
