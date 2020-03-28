import os
import sys


REL_FILE_PATH = 'addons/sourcemod/scripting/include/influx/autoversion.inc'


def write_to_file(file_path, version):
    if not os.path.isdir(os.path.dirname(file_path)):
        raise Exception('Failed to build path to autoversion file! (%s)' %
                        file_path)

    with open(file_path, 'w') as fp:
        fp.write("""
#if defined _influx_autoversion_included
#endinput
#endif
#define _influx_autoversion_included

#define INF_VERSION "%s"
""" % version)


def main():
    full_path = os.path.join(os.path.dirname(__file__), REL_FILE_PATH)

    if len(sys.argv) < 2:
        raise Exception('No version string given!')

    write_to_file(full_path, sys.argv[1])


if __name__ == '__main__':
    main()
