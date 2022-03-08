#!/bin/bash

### MAIN ----------------------------
echo "Provided hostname: $1"

if [ "$1" != "" ]; then
    echo "Configuring host"
    swapoff -a
    hostnamectl set-hostname $1
else
    echo "Err: Missing hostname command line argument."
    exit 1
fi
