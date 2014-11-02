#!/usr/bin/bash
file=$1
mails=$2
l=jasiu@lazy.if.uj.edu.pl
scp $file $l:erato
ssh $l "cd erato; ./send.sh $file $mails"
