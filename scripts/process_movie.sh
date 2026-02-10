#!/bin/bash
# =====================================================
# MOVIE CLIPS PROCESSOR
# Converted from Windows batch file - EXACT SAME LOGIC
# =====================================================

set -e

# CONFIG
IN_DIR="Input"
OUT_RAW="RawClips"
OUT_FINAL="FinalClips"
BG="./assets/bg.jpg"
CLIP_LENGTH=${CLIP_LENGTH:-60}
CHANNEL_NAME=${CHANNEL_NAME:-"Best Movie Moments"}

# Create directories
mkdir -p "$IN_DIR" "$OUT_RAW" "$OUT_FINAL"

# Global counter for raw clips
GLOBAL_COUNT=1

echo "============================================"
echo "PHASE 1: SPLITTING ALL FILES"
echo "============================================"

# Split all input files
for INPUT in "$IN_DIR"/*.mp4; do
    [ -f "$INPUT" ] || continue
    
    echo ""
    echo "-------------------------------------------------------"
    echo "Splitting: $INPUT"
    
    # Get duration
    DURATION=$(ffprobe -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 "$INPUT")
    
    if [ -z "$DURATION" ]; then
        echo "ERROR: Could not read duration. Skipping..."
        continue
    fi
    
    echo "Duration = $DURATION seconds"
    
    # Calculate number of clips
    BASE=${DURATION%.*}
    TOTAL_ROUNDS=$(( (BASE + CLIP_LENGTH - 1) / CLIP_LENGTH ))
    
    if [ $TOTAL_ROUNDS -lt 1 ]; then
        TOTAL_ROUNDS=1
    fi
    
    echo "Creating $TOTAL_ROUNDS clips..."
    
    # Splitting
    COUNT=1
    START=0
    
    while [ $COUNT -le $TOTAL_ROUNDS ]; do
        # 4-digit padding
        CLIPNUM=$(printf "%04d" $GLOBAL_COUNT)
        OUTCLIP="$OUT_RAW/${CLIPNUM}.mp4"
        
        echo "  Creating clip ${CLIPNUM}.mp4 (segment $COUNT of $TOTAL_ROUNDS)"
        
        if [ $COUNT -eq 1 ]; then
            ffmpeg -hide_banner -loglevel error -y -i "$INPUT" -t $CLIP_LENGTH -c copy "$OUTCLIP"
        else
            ffmpeg -hide_banner -loglevel error -y -ss $START -i "$INPUT" -t $CLIP_LENGTH -c copy "$OUTCLIP"
        fi
        
        COUNT=$((COUNT + 1))
        START=$((START + CLIP_LENGTH))
        GLOBAL_COUNT=$((GLOBAL_COUNT + 1))
    done
    
    echo "Split complete for: $INPUT"
    echo "-------------------------------------------------------"
done

echo ""
echo "============================================"
echo "PHASE 2: RENDERING ALL CLIPS"
echo "============================================"

# Render all clips
for RAW in "$OUT_RAW"/*.mp4; do
    [ -f "$RAW" ] || continue
    
    # Get the clip number from filename
    BASENAME=$(basename "$RAW" .mp4)
    OUTNAME="Part-${BASENAME}.mp4"
    
    if [ -f "$OUT_FINAL/$OUTNAME" ]; then
        echo "Skipping already rendered: $OUTNAME"
        continue
    fi
    
    echo "Rendering: $OUTNAME"
    
    # Convert BASENAME to number for display (remove leading zeros)
    PART_NUM=$((10#$BASENAME))
    
    # YOUR EXACT FFMPEG COMMAND WITH BEBAS NEUE FONT
    FONT="./fonts/BebasNeue-Regular.ttf"
    ffmpeg -hide_banner -y \
        -i "$RAW" \
        -loop 1 -i "$BG" \
        -filter_complex "[1:v]scale=1080:1920[bg];[0:v]scale='min(iw,1080)':620,setsar=1[vid];[bg][vid]overlay=(W-w)/2:(H-h)/2:shortest=1[final];[final]drawtext=text='Part-${PART_NUM}':fontfile=${FONT}:fontsize=72:fontcolor=white:x=(w-text_w)/2:y=500,drawtext=text='${CHANNEL_NAME}':fontfile=${FONT}:fontsize=72:fontcolor=white:x=(w-text_w)/2:y=590,drawtext=text='(Full Movie Link In Bio)':fontfile=${FONT}:fontsize=64:fontcolor=white:x=(w-text_w)/2:y=h-630" \
        -c:a aac -b:a 128k -ar 44100 \
        -movflags +faststart \
        -preset veryfast \
        "$OUT_FINAL/$OUTNAME"
    
    if [ $? -eq 0 ]; then
        echo "Completed: $OUTNAME"
    else
        echo "ERROR rendering: $OUTNAME"
    fi
done

TOTAL_CREATED=$((GLOBAL_COUNT - 1))

echo ""
echo "============================================"
echo "ALL PROCESSING COMPLETE!"
echo "Total clips created: $TOTAL_CREATED clips"
echo "============================================"
