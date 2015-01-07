#!/bin/bash

echo "Discovery Extension zipfile loaded" > /tmp/discovery-extension.log

# This example shows the RUBYLIB extension working
/usr/bin/ruby -rdiscovery_extension -e'puts Discovery::Extension.confirm'
