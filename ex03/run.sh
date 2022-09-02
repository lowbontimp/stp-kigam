#!/bin/sh

./getevents.pl #output = events.xml
./xml2txt.var.pl events.xml > events.txt
./txt2stp.pl > cmd

