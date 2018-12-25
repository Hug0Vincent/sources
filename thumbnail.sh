#!/bin/bash

$in_file = ""
$out_file = ""

function usage(){
    printf "\t--small-thumbnail        : make a small thumbnail.\n"
	printf "\t-h                       : print this message.\n"
    exit 1
}

function smallthumbnail(){
    printf "\t--small-thumbnail        : make a small thumbnail.\n"
	printf "\t-h                       : print this message.\n"
}

if [ $# -eq 0 ]
then
	usage
fi

OPTS=$( getopt -o h,i,o -l small-thumbnail: -- "$@" )
if [ $? != 0 ]
then
    exit 1
fi
 
