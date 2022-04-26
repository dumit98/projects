#!/usr/bin/env python3

from itertools import groupby

import argparse
import requests
import textwrap
import warnings
import time
import json
import os
import sys


warnings.filterwarnings('ignore')
sys.tracebacklimit = 0


class CdmConvertToPdfError(Exception):
    '''
    A  custom excpetion class.
    '''
    pass


class ObjDict(dict):
    '''
    Returns a dict like object with its keys as attributes.
    '''
    def __getattr__(self, name):
        if name in self:
            return self[name]
        else:
            raise AttributeError("No such attribute: " + name)

    def __setattr__(self, name, value):
        self[name] = value

    def __delattr__(self, name):
        if name in self:
            del self[name]
        else:
            raise AttributeError("No such attribute: " + name)


def main():
    '''
    Get input file, parse input file, make Get Request to get
    document information and then submit for PDF convertion.
    '''
    global token, log_pass, log_fail, log_debug, debug, trans_map

    trans_map = ''.maketrans(r' ,()[]{}\\/@#$%^&*', '__________________')

    def _parse_input_row(row):
        itemid = revid = ds_name = ds_type = file_name = None
        ds_name_new = monochrome = layout = None

        try:
            row = row.split('|')
            itemid = row[0]
            revid = row[1]
            ds_name = row[2]
            ds_type = row[3]
            file_name = row[4].translate(trans_map)
            ds_name_new = row[5]
            monochrome = row[6].lower()
            layout = row[7].upper()
        except Exception:
            pass

        return ObjDict({'itemID': itemid,
                        'revID': revid,
                        'ds_name': ds_name,
                        'ds_type': ds_type,
                        'file_name': file_name,
                        'ds_name_new': ds_name_new,
                        'monochrome': monochrome,
                        'layout': layout,
                        'ds_puid': None})


    now = time.strftime('%Y%m%d%H%M%S')
    args = parse_arguments()

    log_pass = open(os.path.join(
        args.log_dir, 'CDM_CONVERT_TO_PDF_PASS_%s.log' % now), 'w')
    log_fail = open(os.path.join(
        args.log_dir, 'CDM_CONVERT_TO_PDF_FAIL_%s.log' % now), 'w')
    if args.debug:
        log_debug = open(os.path.join(
            args.log_dir, 'CDM_CONVERT_TO_PDF_DEBUG_%s.log' % now), 'w')

    token = get_access_token(args.username, args.password)
    debug = args.debug

    try:
        input_rows = open(args.input_file).read().splitlines()
        input_rows_parsed = map(_parse_input_row, input_rows)
        input_rows_sorted = sorted(
            input_rows_parsed, key=lambda r: (r.itemID, r.revID, r.ds_name))
        input_chunks = groupby(
            input_rows_sorted, key=lambda r: (r.itemID, r.revID))

        for (itemid, revid), data in input_chunks:
            d = get_tokenized_dataset_puid(itemid, revid, list(data))
            if d.item_info:
                dataset_convert_to_pdf(d.item_info)
    except Exception as e:
        raise CdmConvertToPdfError(e)
    finally:
        log_pass.close()
        log_fail.close()
        if debug:
            log_debug.close()


def get_access_token(user_name, user_password):
    '''
    Get access token and cache it to a given path from enviroment variable.
    '''
    TC_AUTH_TOKEN_URL = 'https://{hostname_auth}/rest/api/1.0/novUser/login'
    cache_path = os.getenv('TC_AUTH_TOKEN_CACHE_PATH')

    if not cache_path:
        raise CdmConvertToPdfError(
            'no token cache path found, please setup env var TC_AUTH_TOKEN_CACHE_PATH')

    def _is_token_expired(token_info):
        now = int(time.time())
        return now > token_info['expires_at']


    def _refresh_access_token(user_name, user_password):
        payload = {'name': user_name,
                   'password': user_password}
        response = requests.post(TC_AUTH_TOKEN_URL, json=payload)

        if response.status_code != 200:
            raise CdmConvertToPdfError(
                "couldn't refresh token: code:%d reason:%s" % (
                    response.status_code, response.reason))

        token_info = response.json()
        token_info = _add_custom_values_to_token_info(token_info)
        _save_token_info(token_info)

        return token_info


    def _add_custom_values_to_token_info(token_info):
        token_info['expires_at'] = int(time.time()) + 28800
        return token_info


    def _save_token_info(token_info):
        try:
            f = open(cache_path, 'w')
            f.write(json.dumps(token_info))
            f.close()
        except Exception:
            raise CdmConvertToPdfError("couldn't write token cache to " + cache_path)


    token_info = None
    try:
        token_info_raw = open(cache_path).read()
        token_info = json.loads(token_info_raw)

        if _is_token_expired(token_info):
            token_info = _refresh_access_token(user_name, user_password)

    except Exception:
        token_info = _refresh_access_token(user_name, user_password)

    return token_info['token']


def get_tokenized_dataset_puid(itemid, revid, item_data=[]):
    '''
    Issue a Get Request to get dataset information from the
    documents service
    '''
    TC_SERVICES_DOC_INFO_URL = f'https://{hostname_docs}/rest/api/3.0/documents/' \
        f'{itemid}?rev={revid}&flags=document.revision,document.revision.datasets'
    headers = {'authorization': 'Bearer %s' % token, 'accept': 'application/json'}
    msg_nofile = 'No dataset file found'

    datasets = errors = message = status_code = reason = None

    response = requests.get(TC_SERVICES_DOC_INFO_URL, headers=headers, verify=False)
    status_code = response.status_code
    reason = response.reason
    data = response.json()

    if response.status_code != 200:
        message = response.reason

    try:
        errors = [ObjDict(i) for i in data['errorList']]
        message = ';'.join([e.message for e in errors])
    except (TypeError, KeyError):
        pass

    try:
        datasets = [ObjDict(i) for i in data['datasetList']['dataset']]
    except (TypeError, KeyError):
        pass

    r = []
    for item in item_data:
        if datasets:
            for ds in datasets:
                if item.ds_puid:
                    break
                else:
                    if (
                            ds.objectName == item.ds_name and
                            ds.objectType == item.ds_type and
                            ds.itemID == item.itemID and
                            ds.revID == item.revID
                        ):
                        try:
                            ds_files = [ObjDict(i) for i in ds.datasetFileList['file']]
                            for file in ds_files:
                                if file.fileName == item.file_name:
                                    item.ds_puid = file.filePUID
                                    break
                                else:
                                    message = msg_nofile
                        except TypeError:
                            message = msg_nofile
                            continue
                    else:
                        message = msg_nofile

        if not item.ds_puid:
            r.append(print_log_to_stdout_and_file('error', message, list(item.values())))

    if debug:
        print('*' * 80, file=log_debug)
        print('ITEM SUBMITTED:', file=log_debug)
        print((itemid, revid), file=log_debug)
        print(file=log_debug)
        print('DOCUMENTS SERVICE URL:', file=log_debug)
        print(TC_SERVICES_DOC_INFO_URL, file=log_debug)
        print(file=log_debug)
        print('DOCUMENTS SERVICE RESPONSE:\n%s:%s' % (status_code, reason), file=log_debug)
        print(file=log_debug)
        print('DOCUMENTS SERVICE PAYLOAD RECEIVED (DatasetList):', file=log_debug)
        print(json.dumps(datasets, indent=4), file=log_debug)
        print(file=log_debug)
        print('FAILURES FROM DOCUMENTS SERVICE:', file=log_debug)
        print('\n'.join(r), file=log_debug)

    return ObjDict({'itemID': itemid,
                    'status_code': response.status_code,
                    'message': message,
                    'item_info': [i for i in item_data if i.ds_puid]})
                    # 'item_info': [i for i in item_data]})  # negative test


def dataset_convert_to_pdf(items=[]):
    '''
    Issue a Post Request to the PDF dataset service to make
    convertion on the dataset submitted
    ''' 
    TC_PDF_SERVICES_URL = f'https://{hostname_pdf}/api/pdfdatasets'
    headers = {'authorization': 'Bearer %s' % token, 'accept': '*/*',
               'CET-Referrer-ApplicationId': 'CDM-TEST'}
    response_payload = message = status_code = reason = None

    r = []
    for item in items:

        payload = {'itemId': item.itemID,
                   'itemRevId': item.revID,
                   'datasetName': item.ds_name_new,
                   'datasetFilePuids': [item.ds_puid],
                   'scaleLineweights': 'false',
                   'forceMonochrome': item.monochrome,
                   'zoomExtents': 'false',
                   'layout': item.layout}

        response = requests.post(TC_PDF_SERVICES_URL, headers=headers, json=payload, verify=False)
        status_code = response.status_code
        reason = response.reason

        try:
            response_payload = ObjDict(response.json())
            message = response_payload.message
        except ValueError:
            pass

        for item in items:
            if response.status_code != 201:
                message = message if message else response.reason
                r.append(print_log_to_stdout_and_file('error', message, list(item.values())))
            else:
                r.append(print_log_to_stdout_and_file('info', response.reason, list(item.values())))
            # r.append(print_log_to_stdout_and_file('info', 'baypass for testing', list(item.values())))  # testing code

        if debug:
            print(file=log_debug)
            print('PDF SERVICE PAYLOAD SENT:', file=log_debug)
            print(json.dumps(payload, indent=4), file=log_debug)
            print(file=log_debug)
            print('PDF SERVICE RESPONSE:\n%s:%s' % (status_code, reason), file=log_debug)
            print(file=log_debug)
            print('PDF SERVICE PAYLOAD RECEIVED:', file=log_debug)
            print(json.dumps(response_payload, indent=4), file=log_debug)
            print(file=log_debug)
            print('RESULTS FROM PDF SERVICE:', file=log_debug)
            print('\n'.join(r), file=log_debug)    


def parse_arguments():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter, 
        description='A python script for the PDF Dataset convertion service',
        epilog=textwrap.dedent('''
            additional information:
              input file format <TcId|RevId|DsName|DsType|FileName|DsNameNew|''' \
                    '''Monochrome(true|false)|Layout(PAPER|MODEL|BOTH)>
              example file format <51015012-ASM:99|03|51015012-ASM|ACADDWG|''' \
                    '''51015012-ASM.dwg|51015012-ASM-PDFTEST|true|MODEL>
            ''')
    )
    parser.add_argument(
        '-u', dest='username', help='tc user name', required=True
    )
    parser.add_argument(
        '-p', dest='password', help='tc user password', required=True
    )
    parser.add_argument(
        '-log_dir', dest='log_dir', help='path for writting log file', required=True
    )
    parser.add_argument(
        '-input_file', dest='input_file', help='input text file', metavar='TXT_FILE', required=True
    )
    parser.add_argument(
        '-debug', dest='debug', help='create debug log', action='store_true'
    )

    args = parser.parse_args()
    return args


counter = 0
def print_log_to_stdout_and_file(level='info', message=None, items=[]):
    items.append('%s: %s' % (level.title(), message))
    log = '|'.join([i for i in items if i and len(i) <= 200])

    global counter
    counter += 1
    print(counter, log)

    if level == 'info':
        log_pass.write(log + '\n')
    elif level == 'error':
        log_fail.write(log + '\n')

    return log


if __name__ == '__main__':
    main()
