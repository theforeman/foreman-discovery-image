#!/bin/bash
#
# Prints mapping table of block devices and TCP ports
#
PORT=13000
echo "dev | port"
echo "----|------"
for pre in sd hd vd; do
  for x in {a..z}; do
    echo "$pre$x | $PORT"
    ((PORT+=1))
  done
  ((PORT+=74))
done
