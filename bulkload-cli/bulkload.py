#!/usr/bin/env python3

"""
TODO

 - email notification X
 - config file support
 - terminate signal hadling
 - receive timeout X
 - excel file support X
 - colored stream messages X
"""

import argparse
import logging
import socket
import time
import os
import tqdm
import copy
import colorama
import smtplib

from tqdm import tqdm
from datetime import datetime
from itertools import chain
from pprint import pformat
from pandas import read_excel, read_csv
from email.mime.text import MIMEText


DEFAULT_TIMEOUT = 30
DEFAULT_PART_COLS = ['itemid', 'name', 'description', 'revision', 'item_type',
                     'rsone_itemtype', 'rsone_uom', 'rsone_uow',
                     'rev_weight', 'name2', 'part_sub_type',
                     'lifecycle', 'rev_status', 'rev_sites', 'rev_comments',
                     'uom', 'nov4_mis_type', 'nov4_mis_serialize',
                     'nov4_height', 'nov4_length', 'nov4_width',
                     'nov4_lwhunits', 'nov4_volume', 'nov4_volunits',
                     'nov4_weight', 'nov4_weightunits', 'date_created',
                     'date_released']

DEFAULT_DOC_COLS = ['itemid', 'name', 'description', 'revision', 'item_type',
                    'doc_category', 'doc_type', 'sequence', 'sheet_no',
                    'publish_toweb', 'publish_topp', 'pull_drawing',
                    'ds_path', 'ds_name', 'rev_sites', 'lifecycle', 'rev_status',
                    'rev_comments', 'date_created', 'date_released']

now = datetime.now()
now_str = now.strftime('%m/%d/%Y %H:%M:%S')
socket.setdefaulttimeout(DEFAULT_TIMEOUT)
bl_client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
log_client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)


def main():
    global args, logger, pbar

    args = parse_arguments()
    args.file = file_to_dict(args.file)
    logger = getlogger()
    icols = invalid_cols(args.file[0].keys())

    itemid = None
    revid = None
    itemid_prev = None
    revid_prev = None

    if icols:
        exit('There are invalid columns, '
             'please fix them and try again:\n\n%s' % '\n'.join(icols))

    client = login(args.user, args.password, args.server, args.port_out, args.port_in)
    pbar = tqdm(total=len(args.file), ncols=80, colour='green')

    # beginnning of the for loop to iterate item list
    for row in args.file:

        itemid_prev = itemid
        revid_prev = revid
        itemid = row.get('itemid')
        revid = row.nget('revision', '01')
        typ = row.nget('item_type', 'Documents')

        cxfilter.set_item_rev((itemid, revid))

        cdate = row.nget('date_created', now_str)
        rdate = row.nget('date_released', now_str)

        # delete item if args.delete is true
        if args.delete:
            if itemid != itemid_prev:
                try:
                    delete_item(client, itemid)
                except socket.timeout:
                    notify(1, args.notify_to, (f'{__file__} has stopped because '
                                                'of a timeout from the server'))
                    exit(1)
            pbar.update(1)
            continue

        # try parsing the dates
        try:
            row['date_created']  = datetime.strptime(cdate, '%m/%d/%Y %H:%M:%S')\
                                           .strftime('%d-%b-%y %H:%M:%S')
            row['date_released'] = datetime.strptime(rdate, '%m/%d/%Y %H:%M:%S')\
                                           .strftime('%d-%b-%y %H:%M:%S')
        except ValueError as e:
            logger.ifail(e)
            continue

        # release item if args.release is true
        if args.release:
            if itemid != itemid_prev and revid != revid_prev:
                try:
                    if not get_item_rev(client, itemid, revid).released:
                        release_rev(client, itemid, revid,
                                    row.nget('rev_status', 'null'),
                                    row.get('date_released'))
                    else:
                        logger.ifail('item revision already released')
                        pbar.colour = 'red'
                except socket.timeout:
                    notify(1, args.notify_to, (f'{__file__} has stopped because '
                                               f'of a timeout from the server'))
                    exit(1)
            pbar.update(1)
            continue

        # inspect data before loading
        while not args.cont:
            pbar.write('\n%s\n' % pformat(row))
            answer = prompt('data OK?')
            if answer == 'y':
                break
            elif answer == 'n':
                logout()
                exit()
            elif answer == 'C':
                args.cont = True

        # start processing the item
        logger.info('processing item')

        # check if the item already exists
        # and if it does, try to load the revision
        try:
            if get_item(client, itemid).ok:
                logger.warning(f'item already exist, '
                               f'attempting revision load ({revid})...')
                if get_item_rev(client, itemid, revid).ok:
                    logger.ifail('item revision already exists, skipping')
                    pbar.colour = 'red'
                else:
                    revload = load_revision(client, row)
                    if revload.ok and typ == 'Documents' and row.get('ds_path'):
                        dsload = load_dataset(client, row)
                        if dsload.ok:
                            relate_objects(client, revload.puid, dsload.puid,
                                           'IMAN_specification')
                pbar.update(1)
                continue
        except socket.timeout:
            notify(1, args.notify_to, (f'{__file__} has stopped because '
                                       f'of a timeout from the server'))
            exit(1)

        # if item not exists, load it to tc
        try:
            if typ == 'Documents':
                docload = load_doc(client, row)
                if docload.ok and row.get('ds_path'):
                    dsload = load_dataset(client, row)
                    if dsload.ok:
                        relate_objects(client, get_item_rev(client, itemid, revid).puid,
                                       dsload.puid, 'IMAN_specification')
            elif typ == 'Nov4Part':
                load_part(client, row)
            else:
                logger.ifail(f'item has an unsupported type ({typ})')
        except socket.timeout:
            notify(1, args.notify_to, (f'{__file__} has stopped because '
                                       'of a timeout from the server'))
            exit(1)
        except Exception as e:
            logger.exception(e)
            pbar.colour = 'red'

        pbar.update(1)

    notify(0, args.notify_to, f'{__file__} has finished')
    logout()


# def map_columns(columns, mapping):
#     # return mapped columns
#     pass


def invalid_cols(cols):
    icols = []
    for col in cols:
        if col.lower() not in DEFAULT_DOC_COLS:
            icols.append(col)
    return icols


def load_part(client, item):
    itemid = item.nget('itemid')

    data = ('FUNCTION addPartItem\tITEMID' + item.nget('itemid', 'null') +
            '\tITEMNAME' + item.nget('name', 'null') +
            '\tITEMDESC' + item.nget('description', 'null') +
            '\tREVISION' + item.nget('revision', '01') +
            '\tRSONE_ITEMTYPE' + item.nget('item_type', 'null') +
            '\tRSONE_UOM' + item.nget('rsone_uom', 'null') +
            '\tRSONE_UOW' + item.nget('rsone_uow', 'null') +
            '\tREV_WEIGHT' + item.nget('rev_weight', 'null') +
            '\tNAME2' + item.nget('name2', 'null') +
            '\tPARTSUBTYPE' + item.nget('part_sub_type', 'null') +
            '\tLIFECYCLE' + item.nget('lifecycle', 'null') +
            '\tSITES' + item.nget('rev_sites', 'null') +
            '\tREVCOMMENTS' + item.nget('rev_comments', 'null') +
            '\tITEM_UOM' + item.nget('uom', 'null') +
            '\tNOV4_MIS_TYPE' + item.nget('nov4_mis_type', 'null') +
            '\tNOV4_MIS_SERIALIZE' + item.nget('nov4_mis_serialize', 'null') +
            '\tNOV4_HEIGHT' + item.nget('nov4_height', 'null') +
            '\tNOV4_LENGTH' + item.nget('nov4_length', 'null') +
            '\tNOV4_WIDTH' + item.nget('nov4_witdth', 'null') +
            '\tNOV4_LWH_UNITS' + item.nget('nov4_lwhunits', 'null') +
            '\tNOV4_VOLUME' + item.nget('nov4_volume', 'null') +
            '\tNOV4_VOL_UNITS' + item.nget('nov4_volunits', 'null') +
            '\tNOV4_WEIGHT' + item.nget('nov4_weight', 'null') +
            '\tNOV4_WGT_UNITS' + item.nget('nov4_weightunits', 'null') +
            '\tDATE' + item.nget('date_created', 'null')).replace('\n', '')

    response = sendrecv(client, data, itemid=itemid)

    if not response.ok:
        pbar.colour = 'red'
        logger.ifail(response.err_msg)
    else:
        logger.ipass('success')

    return response


def load_doc(client, item):
    itemid = item.nget('itemid', 'null')

    data = ('FUNCTION addDocumentsItem\tITEMTYPE ' + item.nget('doc_type') +
            '\tITEMID ' + item.nget('itemid', 'null') +
            '\tITEMNAME ' + item.nget('name', itemid) +
            '\tITEMDESC ' + item.nget('description', 'null') +
            '\tCATEGORY ' + item.nget('doc_category', 'null') +
            '\tREVISION ' + item.nget('revision', '01') +
            '\tSEQNO ' + item.nget('sequence', '001') +
            '\tSHEET ' + item.nget('sheet_no', 'null') +
            '\tPUBLISHWEB ' + item.nget('publish_toweb', 'false') +
            '\tPUBLISHPP ' + item.nget('publish_topp', 'false') +
            '\tPULLDRAWING ' + item.nget('pull_drawing', 'false') +
            '\tLIFECYCLE ' + item.nget('lifecycle', 'null') +
            '\tSITES ' + item.nget('rev_sites', 'null') +
            '\tREVCOMMENTS ' + item.nget('rev_comments', 'null') +
            '\tDATE ' + item.nget('date_created', 'null')).replace('\n', '')

    response = sendrecv(client, data, itemid=itemid)

    if not response.ok:
        pbar.colour = 'red'
        logger.ifail(response.err_msg)
    else:
        logger.ipass('success')

    return response


def load_revision(client, revision):
    itemid = revision.nget('itemid')

    data = ('FUNCTION addRevision\tITEMID ' + revision.nget('itemid', 'null') +
            '\tREVISION ' + revision.nget('revision', '01') +
            '\tREV_WEIGHT ' + revision.nget('rev_weight', 'null') +
            '\tLIFECYCLE ' + revision.nget('lifecycle', 'null') +
            '\tSITES ' + revision.nget('rev_sites', 'null') +
            '\tREVCOMMENTS ' + revision.nget('rev_comments', 'null') +
            '\tNAME2 ' + revision.nget('name2', 'null') +
            '\tNOV4_HEIGHT ' + revision.nget('nov4_height', 'null') +
            '\tNOV4_LENGTH ' + revision.nget('nov4_length', 'null') +
            '\tNOV4_WIDTH ' + revision.nget('nov4_width', 'null') +
            '\tNOV4_LWH_UNITS ' + revision.nget('nov4_lwhunits', 'null') +
            '\tNOV4_VOLUME ' + revision.nget('nov4_volume', 'null') +
            '\tNOV4_VOL_UNITS ' + revision.nget('nov4_volunits', 'null') +
            '\tNOV4_WEIGHT ' + revision.nget('nov4_weight', 'null') +
            '\tNOV4_WGT_UNITS ' + revision.nget('nov4_weightunits', 'null') +
            '\tDATE ' + revision.nget('date_created', 'null'))

    response = sendrecv(client, data, itemid=itemid)

    if not response.ok:
        pbar.colour = 'red'
        logger.ifail(response.err_msg)
    else:
        logger.ipass('success')

    return response


def load_dataset(client, dataset):
    itemid = dataset.nget('itemid')
    ds_name = itemid.split(':')[0]
    file_path = dataset.nget('ds_path').strip()
    file_ext = os.path.splitext(file_path)[1].strip('.')

    dataset_types = {
        "doc": "MSWord", "ppt": "MSPowerPoint", "xls": "MSExcel", "csv": "MSExcel",
        "dwg": "ACADDWG", "vsd": "MSVisio", "idw": "INVENTOR", "pdf": "PDF",
        "zip": "Zip", "mpg": "Mpeg", "txt": "Text", "xpi": "Text", "xpr": "Text",
        "cnr": "Text", "cns": "Text", "dat": "Text", "ncf": "Text", "hd3": "Text",
        "min": "Text", "cnc": "Text", "vnc": "Text", "htm": "HTML", "html": "HTML",
        "xml": "XML", "tif": "Image", "tiff": "Image", "jpg": "Image", "jpeg": "Image",
        "gif": "Image", "bmp": "Image", "wmv": "WMV", "mov": "Quicktime",
        "rtf": "MSWord", "plt": "Plot_File", "dxf": "DXF", "sch": "PCADSCH",
        "pcb": "PCADPCB", "sat": "sat", "docx": "MSWord", "xlsx": "MSExcel",
        "pptx": "MSPowerPoint", "wmf": "ACADDWG", "pds": "Photoshop", "mdb": "MSAccess",
        "msg": "Email", "avi": "Image", "png": "Image", "pptm": "MSPowerPoint",
        "pps": "MSPowerPoint", "xlsm": "MSExcel", "ext": "Reference", "btw": "Nov4BTW",
        "gp4": "Nov4GP4"}

    if file_ext:
        file_type = dataset_types.get(file_ext.lower(), 'MISC')
    else:
        logger.ifail('invalid file extension')
        return

    data = ('FUNCTION addSimpleDataset' +
            '\tDATASETNAME ' + dataset.nget('ds_name', ds_name) +
            '\tDATASETTYPE ' + file_type +
            '\tITEMDESC ' + dataset.nget('description', 'null') +
            '\tFILENAME ' + dataset.nget('ds_path', 'null'))

    response = sendrecv(client, data, itemid=itemid)

    if not response.ok:
        pbar.colour = 'red'
        logger.ifail(response.err_msg)
    else:
        logger.ipass('success')

    return response


def relate_objects(client, primary, secondary, reltype):
    data = ('FUNCTION createRelationship\tFROMPUID ' + primary +
            '\tTOPUID ' + secondary +
            '\tRELATION ' + reltype)

    response = sendrecv(client, data)

    if not response.ok:
        pbar.colour = 'red'
        logger.ifail(response.err_msg)
    else:
        logger.ipass('success')

    return response


def get_item(client, itemid):
    data = ('FUNCTION getItem\tITEMID ' + itemid)
    response = sendrecv(client, data, itemid=itemid)
    return response


def get_item_rev(client, itemid, revid):
    data = ('FUNCTION getItemRevision\tITEMID ' + itemid +
            '\tREVISION ' + revid)
    response = sendrecv(client, data, itemid=itemid)
    return response


def release_rev(client, itemid, revid, status, date):
    data = ('FUNCTION releaseRevision\tITEMID ' + itemid +
            '\tREVISION ' + revid +
            '\tRELEASESTATUS ' + status +
            '\tRELEASEDATE ' + date)
    response = sendrecv(client, data)

    if not response.ok:
        pbar.colour = 'red'
        logger.ifail(response.err_msg)
    else:
        logger.ipass('success')

    return response.ok


def delete_item(client, itemid):
    data = ('FUNCTION deleteItem\tITEMID ' + itemid)
    response = sendrecv(client, data)

    if not response.ok:
        pbar.colour = 'red'
        logger.ifail(response.err_msg)
    else:
        logger.ipass('success')

    return response.ok


def login(user, pwd, host, port_out, port_in):
    hostip = socket.gethostbyname('localhost')

    try:
        bl_client.connect((host, port_out))
        log_client.bind((hostip, port_in))
    except Exception as e:
        exit(e)

    response = sendrecv(bl_client, f'LOGSOCKET\tIP {hostip}\tPORT {port_in}')
    if not response.ok:
        print(response.err_msg)
        exit(1)

    response = sendrecv(bl_client, f'FUNCTION login\tUSER {user}\tPASSWORD {pwd}')
    if not response.ok:
        print(response.err_msg)
        if 'already logged' in response.err_msg:
            while not args.cont:
                answer = input('continue? [y/n] >> ')
                if answer == 'y':
                    break
                elif answer == 'n':
                    exit(1)
        else:
            exit(1)

    return bl_client


def logout():
    # send(bl_client, 'END_OF_RUN')
    bl_client.close()
    log_client.close()
    pbar.close()


trx = 1
def send(client, data):
    global trx
    client.send(bytes(f'{data}\tTRANSACTION {trx}', 'utf-8'))
    trx += 1


def sendrecv(client, data, **kwargs):
    response = {}

    ok = None
    puid = None
    itemid = None
    revid = None
    released = None
    itemtype = None
    primary_obj = None
    secondary_obj = None
    err_msg = None

    class DictAttr(dict):
        def __getattr__(self, name):
            if name in self:
                return self[name]
            else:
                raise AttributeError("No such attribute: " + name)

        def __setattr__(self, name, value):
            self[name] = value

    try:
        send(client, data)
        # msg = recv_timeout(log_client, 1).split('\n')
        msg = log_client.recv(1024).decode('utf-8')
    except Exception as e:
        exit(e)

    msg_splitted = msg.split('\t')

    for words in msg_splitted:
        key = words.split()[0].upper()
        val = ' '.join(words.split()[1:])

        if 'SUCCESS' in key:
            ok = True
        elif 'FAILED' in key:
            ok = False
        elif 'PUID' in key:
            puid = val
        elif 'ITEMID' in key:
            itemid = val
        elif 'REVISION' in key:
            revid = val
        elif 'ISRELEASED' in key:
            if val == 'true':
                released = True
            else:
                released = False
        elif 'TYPE' in key:
            itemtype = val
        elif 'PRIMARY_OBJECTU' in key:
            primary_obj = val
        elif 'SECONDARY_OBJECTU' in key:
            secondary_obj = val
        elif 'ERROR' in key:
            err_msg = val

    response['msg'] = msg
    response['ok'] = ok
    response['puid'] = puid
    response['itemid'] = itemid
    response['revid'] = revid
    response['released'] = released
    response['itemtype'] = itemtype
    response['primary_obj'] = primary_obj
    response['secondary_obj'] = secondary_obj
    response['err_msg'] = err_msg

    return DictAttr(response)


def recv_timeout(client, timeout=2):
    begin = time.time()
    total_data = []
    data = ''

    client.setblocking(0)
    while True:
        # if you got some data, then break after wait sec
        if total_data and time.time()-begin>timeout:
            break
        # if you got no data at all, wait a little longer
        elif time.time()-begin>timeout*2:
            break
        try:
            data = client.recv(1024)
            if data:
                total_data.append(data.decode('utf-8')+'\n')
                begin = time.time()
            else:
                time.sleep(0.1)
        except Exception:
            pass
    return ''.join(total_data)


def prompt(message):
    m = ' '.join([message, '[y/n/(C)ontinue] >> '])
    choices = ['y', 'n', 'C']
    answer = None

    pbar.clear()
    while answer not in choices:
        answer = input(m)
    pbar.refresh()

    return answer


def notify(status, email, message):
    if not args.notify_to:
        return

    msg = MIMEText(message)
    msg['From'] = 'PyBulkload@nov.com'
    msg['To'] = email

    if status == 0:
        msg['Subject'] = 'Bulkload Successfully Finished'
    elif status == 1:
        msg['Subject'] = 'Bulkload Failed'

    s = smtplib.SMTP(f'smtp_server')
    s.send_message(msg)
    s.quit()


def getlogger():
    global cxfilter

    class ContextFilter(logging.Filter):
        """
        This is a filter which injects contextual information into the log.
        """
        def set_item_rev(self, itemrev):
            self.itemrev = '/'.join(itemrev)

        def filter(self, record):
            if hasattr(self, 'itemrev'):
                itemrev = self.itemrev
            else:
                itemrev = None
            record.itemrev = itemrev
            return True

    class CustomFilter():
        def __init__(self, level):
            self._level = level

        def filter(self, logRecord):
            return logRecord.levelno == self._level

    class TqdmLoggingHandler(logging.StreamHandler):
        def __init__(self, level=logging.NOTSET):
            super().__init__(level)

        def emit(self, record):
            # Need to make a actual copy of the record
            # to prevent altering the message for other loggers
            myrecord = copy.copy(record)
            levelno = myrecord.levelno
            if(levelno >= 50):  # CRITICAL / FATAL
                color = '\x1b[31m'  # red
            elif(levelno >= 40):  # ERROR
                color = '\x1b[1;31m'  # red
            elif(levelno >= 30):  # WARNING
                color = '\x1b[33m'  # yellow
            elif(levelno >= 20):  # INFO
                color = '\x1b[0m'  # none
            elif(levelno >= 10):  # DEBUG
                color = '\x1b[35m'  # pink
            else:  # NOTSET and anything else
                color = '\x1b[0m'  # normal
            myrecord.msg = color + str(myrecord.msg) + '\x1b[0m'
            try:
                msg = self.format(myrecord)
                tqdm.write(msg)
                self.flush
            except Exception:
                self.handleError(myrecord)

    PASS = 21
    FAIL = 41

    logging.addLevelName(PASS, 'PASS')
    logging.addLevelName(FAIL, 'FAIL')

    def ipass(self, message, *args, **kwargs):
        if self.isEnabledFor(PASS):
            self._log(PASS, message, args, **kwargs)

    def ifail(self, message, *args, **kwargs):
        if self.isEnabledFor(FAIL):
            self._log(FAIL, message, args, **kwargs)

    logging.Logger.ipass = ipass
    logging.Logger.ifail = ifail

    cxfilter = ContextFilter()
    name = os.path.basename(__file__).split('.')[0]
    tnow = now.strftime('%Y%m%d_%H%M%S')
    sformatter = logging.Formatter('%(itemrev)s: %(funcName)20s: %(message)s')

    if args.delete:
        action = 'delete'
    elif args.release:
        action = 'release'
    else:
        action = 'load'

    logger = logging.getLogger(__name__)
    logger.setLevel(logging.DEBUG)
    logger.addFilter(cxfilter)

    if args.log_level == logging.DEBUG:
        colorama.init()
        stream_handler = TqdmLoggingHandler()
    else:
        stream_handler = logging.StreamHandler()
    stream_handler.setLevel(args.log_level)
    stream_handler.setFormatter(sformatter)

    pass_log = logging.FileHandler(os.path.join(args.log_dir,
                                                f'{name}_{action}_pass_{tnow}.log'))
    pass_log.setLevel(PASS)
    pass_log.setFormatter(sformatter)
    pass_log.addFilter(CustomFilter(PASS))

    fail_log = logging.FileHandler(os.path.join(args.log_dir,
                                                f'{name}_{action}_fail_{tnow}.log'))
    fail_log.setLevel(FAIL)
    fail_log.setFormatter(sformatter)
    fail_log.addFilter(CustomFilter(FAIL))

    logger.addHandler(stream_handler)
    logger.addHandler(pass_log)
    logger.addHandler(fail_log)

    return logger


def file_to_dict(file):

    class CustomDict(dict):

        def __init__(self, *args, **kwargs):
            super(CustomDict, self).__init__(*args, **kwargs)

        def nget(self, key, default=None):
            if default:
                val = self.get(key, default)
                if not val:
                    return default
            return self.get(key, default)

    def dateconv(date):
        return date.strftime('%m/%d/%Y %H:%M:%S')

    file_ext = file.split('.')[-1]

    if file_ext in ('xlsx', 'xls'):
        df = read_excel(file, keep_default_na=False,
                        converters={'date_released': dateconv,
                                    'date_created': dateconv})
    elif file_ext in ('csv'):
        df = read_csv(file, keep_default_na=False, encoding='utf-8-sig')
    else:
        exit(f'unsupported file type ({file_ext})')

    df.columns = map(str.lower, df.columns)

    return df.applymap(str).replace({'': None}).to_dict(orient='records', into=CustomDict)


def parse_arguments():

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
                    parts[-1] += ' %s' % args_string
                return ', '.join(parts)

        def _metavar_formatter(self, action, default_metavar):
            if action.metavar is not None:
                result = action.metavar
            elif action.choices is not None:
                choice_strs = [str(choice) for choice in action.choices]
                result = '{%s}' % ' | '.join(choice_strs)
            else:
                result = default_metavar

            def format(tuple_size):
                if isinstance(result, tuple):
                    return result
                else:
                    return (result, ) * tuple_size
            return format

    class ListFieldsAction(argparse.Action):
        def __call__(self, parser, namespace, values, option_string=None):
            flist = {'Documents': DEFAULT_DOC_COLS, 'Nov4Part': DEFAULT_PART_COLS}
            if not values:
                for typ in flist:
                    print('Default %s Fields:\n  %s\n' % (typ, '\n  '.join(flist[typ])))
                parser.exit()
            else:
                print('Default %s Fields:\n  %s' % (values, '\n  '.join(flist[values])))
                parser.exit()

    def lower_first(iterator):
        return chain([next(iterator).lower()], iterator)

    # config = configparser.ConfigParser()

    parser = argparse.ArgumentParser(
        formatter_class=CustomFormatter,
        description='cli client for Bulkloader')
    parser.add_argument('-n', '--list-field-names', required=False, action=ListFieldsAction,
                        nargs='?', choices=['Nov4Part', 'Documents'],
                        help='list the default field names for mapping')
    parser.add_argument('-u', '--user', required=True)
    parser.add_argument('-p', '--password', required=True)
    parser.add_argument('-g', '--group', required=False)
    parser.add_argument('-f', '--file', required=True,
                        # type=argparse.FileType('r', encoding='utf-8-sig'),
                        help=('file to load. heading must be included. supported types are: '
                              'excel:.xlsx/.xls and csv:.csv'))
    parser.add_argument('-l', '--log-dir', required=True,
                        help='dir path for the log files')
    # parser.add_argument('-m', '--mapping-file', required=True, type=argparse.FileType('r'),
                        # metavar='MAPPING', dest='mapping',
                        # help='file containing column/field mappings')
    parser.add_argument('-S', '--server', required=False, default='localhost',
                        help='bulkloader server (default: localhost)')
    parser.add_argument('-Po', '--port-out', required=False, default=13151, type=int,
                        help='bulkloader server port (default: 13151)')
    parser.add_argument('-Pi', '--port-in', required=False, default=13152, type=int,
                        help='%(prog)s client port (default: 13152)')
    parser.add_argument('-y', '--yes', required=False, dest='cont', action='store_true',
                        help=('assume the answer "yes" to any prompts, proceeding with '
                              'all operations if possible'))
    parser.add_argument('-v', '--verbose', required=False, dest='log_level', action='store_const',
                        default=logging.WARNING, const=logging.DEBUG,
                        help='increase verbosity')
    parser.add_argument('-e', '--notify-to', metavar='EMAIL', required=False,
                        help='notify when finished or on errors')
    parser.add_argument('--release', required=False, action='store_true',
                        help='release the items')
    parser.add_argument('--delete', required=False, action='store_true',
                        help='delete the items')

    args = parser.parse_args()
    # config.read_file(args.mapping)

    # args.file = list(csv.DictReader(lower_first(args.file)))
    # args.mapping = config

    if not os.path.isdir(args.log_dir):
        parser.error('invalid log directory path')
    if args.delete and args.release:
        parser.error('cannot --release and --delete at the same time')

    return args


if __name__ == '__main__':
    main()
