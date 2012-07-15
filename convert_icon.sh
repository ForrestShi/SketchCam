#!/bin/bash
ICON512=$1
convert $ICON512 -resize 57x57 ../Icon.png
convert $ICON512 -resize 512x512 ../Icon512.png
convert  $ICON512 -resize 58x58 ../Ion-Small@2x.png
convert $ICON512 -resize 29x29 ../Icon-Small.png
convert  $ICON512 -resize 114x114 ../Icon@2x.png
convert  $ICON512 -resize 50x50 ../Icon-Small-50.png
convert $ICON512 -resize 72x72 ../Icon-72.png
convert $ICON512 -resize 144x144 ../Icon-72@2x.png

