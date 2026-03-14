#!/bin/bash

# Generate a `:something-intensifies:` Slack emoji, given a reasonable image
# input. I recommend grabbing an emoji from https://emojipedia.org/

set -euo pipefail

# Configuration: Number of frames and delay between them
count=8
# Delay between frames in 1/100 seconds (50 = 0.5s, 5 = 0.05s)
delay=5

# Check for input file
if [ $# -eq 0 ]; then
  echo "Usage: $0 input.png"
  exit 1
fi

input=$1
if [ ! -f "$input" ]; then
  echo "Input file '$input' not found."
  exit 1
fi

# Change to input file's directory for relative paths
cd "$(dirname "$input")"

filename=$(basename -- "$input")

# Scale image to 85% of 512x512 canvas
width=$(identify -format "%w" "$filename")
height=$(identify -format "%h" "$filename")
canvas_size=512
image_scale_num=17  # Numerator for 85% scaling (17/20)
image_scale_den=20  # Denominator for 85% scaling
image_width=$(( (canvas_size * image_scale_num) / image_scale_den ))
image_height=$(( (canvas_size * image_scale_num) / image_scale_den ))
# Centered positioning on canvas
imgX=$(( (canvas_size - image_width) / 2 ))
imgY=$(( (canvas_size - image_height) / 2 ))
# Max possible positions for shake boundaries
maxX=$(( canvas_size - image_width ))
maxY=$(( canvas_size - image_height ))
# Max shake distance (half the space from center to edge)
maxXMove=$(( (maxX - imgX) / 2 ))
maxYMove=$(( (maxY - imgY) / 2 ))
# Scale the input image to fit
extended="${filename%.*}-extended.png"
magick \
  "$filename" \
  -gravity center \
  -background none \
  -geometry ${image_width}x${image_height} \
  "$extended"

# Generate some shaky frames
frame="${filename%.*}-frame"
n=0
while [ "$n" -lt "$count" ]; do
  # Generate random shake
  # Random sign for direction (±1)
  sign_x=$(( RANDOM % 2 == 0 ? -1 : 1 ))
  # Random offset: 0 to maxXMove, scaled and exaggerated by 1.5x
  offset_x=$(( ((RANDOM % 100 * maxXMove * 3) / 2) / 100 ))
  x=$(( imgX + offset_x * sign_x ))
  
  sign_y=$(( RANDOM % 2 == 0 ? -1 : 1 ))
  offset_y=$(( ((RANDOM % 100 * maxYMove * 3) / 2) / 100 ))
  y=$(( imgY + offset_y * sign_y ))

  # Create frame: composite extended image on transparent canvas at (x,y)
  magick -size ${canvas_size}x${canvas_size} xc:none "$extended" -geometry +${x}+${y} -composite "$frame"-"$n".png

  n=$((n + 1))
done

# Combine the frames into a GIF
gif="${filename%.*}-intensifies.gif"
magick -delay $delay -dispose Background "${frame}"-*.png -loop 0 "$gif"

# Clean up temporary files
rm "$extended" "${frame}"-*.png

# We did it y'all
echo "Created $gif. Enjoy!"