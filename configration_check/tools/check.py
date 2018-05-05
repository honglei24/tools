#!/usr/bin/env python2

from argparse import ArgumentParser
from enum import Enum
from string import Template

import ConfigParser
import csv
import compare


class NodeType(Enum):
    compute = 'compute'
    controller = 'controller'

    def __str__(self):
        return self.value


def main():
    parser = ArgumentParser()
    parser.add_argument('cluster',
                        type=str,
                        help='cluster name.'
                        )

    parser.add_argument('nodeType',
                        type=NodeType,
                        choices=list(NodeType),
                        default='compute',
                        help='node type. controller or compute.')

    parser.add_argument('--resetFlag',
                        type=bool,
                        default=False,
                        help='whether to modify the configuration file.')

    args = parser.parse_args()
    # print(args.nodeType)
    cluster = args.cluster
    reset_flag = args.resetFlag
    print cluster

    cluster_info_file_name = "../conf/cluster_info.ini"
    config = ConfigParser.RawConfigParser(allow_no_value=True)
    config.read(cluster_info_file_name)

    o = config.options(cluster)
    print 'options:', o
    d = {}
    for key in o:
        d[key] = config.get(cluster, key)

    result = ""
    checklist_file_name = "../conf/" + "check_list_" + args.nodeType.__str__()
    with open(checklist_file_name, "r") as csv_file:
        reader = csv.reader(csv_file)
        for item in reader:
            file_type = item[0]
            destination_file_path = item[1]
            template_file_name = item[2]
            # print file_type, destination_file_path, template_file_name
            tmp_file_name = "../tmp/" + template_file_name
            parser_template_file("../template/" + template_file_name, d, tmp_file_name)
            if file_type == 'ini':
                result = result + compare.compare_ini(tmp_file_name, destination_file_path, reset_flag)
            elif file_type == 'json':
                result = result + compare.compare_json(tmp_file_name, destination_file_path, reset_flag)
            else:
                pass

    print result

def parser_template_file(template_file_name, v, tmp_file_name):
    # with open('test.template', 'r') as t:
    #     test = t.read()
    #     print test
    with open(template_file_name, 'r') as f:
        context = f.read()
        temp_template = Template(context)
        output = temp_template.substitute(v)
        with open(tmp_file_name, 'w') as f1:
            f1.write(output)

if __name__ == '__main__':
    main()