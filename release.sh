#!/bin/bash

cb=kagent
#version= $(grep ^version metadata.rb | perl -pi -e 's/"//g' |  perl -pi -e "s/version\s*//g")
#echo "Releasing version: $version of $cb  to Chef supermarket"

rm -rf /tmp/cookbooks
berks vendor /tmp/cookbooks
cp metadata.rb /tmp/cookbooks/$cb/
knife cookbook site share $cb Applications
