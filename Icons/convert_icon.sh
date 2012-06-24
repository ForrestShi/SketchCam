#!/bin/bash
ICON512=$1

convert $ICON512 -resize 57x57 SIcon.png
convert $ICON512 -resize 512x512 SIcon512.png
convert  $ICON512 -resize 58x58 SIcon-Small@2x.png
convert $ICON512 -resize 29x29 SIcon-Small.png
convert  $ICON512 -resize 114x114 SIcon@2x.png
convert  $ICON512 -resize 50x50 SIcon-Small-50.png
convert $ICON512 -resize 72x72 SIcon-72.png
convert $ICON512 -resize 144x144 SIcon-72@2x.png

