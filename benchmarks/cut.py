#!/usr/bin/env python

# This is a very simplistic version of 'cut'. It was written for performance comparisons,
# it is not intended for real work.

import argparse
import fileinput

def main():
    parser = argparse.ArgumentParser(description='Simple cut utility in python.')
    parser.add_argument('-f', '--fields', nargs='+', type=int, required=True)
    parser.add_argument('files', nargs='*')

    args = parser.parse_args();
    field_indicies = [x - 1 for x in args.fields]

    for line in fileinput.input(args.files):
        fields = line.rstrip('\n').split('\t')
        print '\t'.join([fields[x] for x in field_indicies])
    
if __name__ == '__main__':
    main()
    
