#!/bin/sh

# ==============================================================================
# FFmpeg Video Clock for Framebuffer
# By: XtendedGreg 7-7-2025
# XtendedGreg YouTube Channel: https://www.youtube.com/@xtendedgreg
#
# Description:
# This script creates a video clock by overlaying the current time onto a
# motion video background. It's designed for a Raspberry Pi running Alpine
# Linux, outputting to a framebuffer device (e.g., /dev/fb0).
#
# Optimization:
# This version first scales the background video to a temporary file matching
# the screen resolution. This significantly reduces CPU load during the main
# clock loop, making it ideal for devices like the Raspberry Pi.
#
# Features:
# - Supports 12h and 24h time formats via config file.
# - Disables framebuffer cursor blink during operation.
# - Pre-scales video to reduce real-time CPU load.
# - Automatically cleans up temporary files on exit.
# - Reads configuration from an external file.
# - Automatically detects framebuffer resolution using ffprobe.
# - Customizable fonts, colors, and video source.
# - Displays date/timezone (small) and time (large).
# ==============================================================================

# --- Configuration File ---
# The script will look for 'videoClock.conf' in the same directory.
# If it doesn't exist, it will use the default values below.
CONFIG_FILE="/etc/videoClock/videoClock.conf"

# --- Default Configuration Values ---
VIDEO_SOURCE="/root/background.mp4"
FONT_FILE="/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"
TEXT_COLOR="white"
TEXT_BG_COLOR="black@0.5" # Black with 50% opacity
FRAMEBUFFER="/dev/fb0"
SMALL_FONT_SIZE=30
LARGE_FONT_SIZE=90
TIME_FORMAT="12h" # Options: "12h" or "24h"

# --- Load Configuration ---
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
fi

# --- Temporary File for Scaled Video ---
# Using $$ makes the filename unique for this script instance.
TEMP_VIDEO_FILE="/tmp/videoclock_bg_$$.mp4"
CURSOR_BLINK_FILE="/sys/class/graphics/fbcon/cursor_blink"
ORIGINAL_CURSOR_STATE=""

# --- Cleanup Function ---
# This function is called when the script exits to remove the temp file
# and restore the framebuffer cursor state.
cleanup() {
    echo
    echo "Cleaning up..."
    rm -f "$TEMP_VIDEO_FILE"
    # Restore original cursor blink state if we changed it
    if [ -n "$ORIGINAL_CURSOR_STATE" ] && [ -w "$CURSOR_BLINK_FILE" ]; then
        echo "Restoring cursor blink state to '$ORIGINAL_CURSOR_STATE'."
        echo "$ORIGINAL_CURSOR_STATE" > "$CURSOR_BLINK_FILE"
    fi
    echo "Cleanup complete. Exiting."
}

# --- Trap Exit Signals ---
# This ensures the cleanup function is called when the script is stopped
# with Ctrl+C (INT), or by a termination signal (TERM), or on normal exit (EXIT).
trap cleanup INT TERM EXIT

# --- Function to check for required commands ---
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: Required command '$1' is not installed. Please install it." >&2
        exit 1
    fi
}

# --- Pre-run Checks ---
check_command "ffmpeg"
# ffprobe is part of the ffmpeg package, so we only need to check for ffmpeg.

if [ ! -f "$FONT_FILE" ]; then
    echo "Error: Font file not found at '$FONT_FILE'" >&2
    exit 1
fi

if [ ! -r "$VIDEO_SOURCE" ]; then
    echo "Error: Video source not found or not readable at '$VIDEO_SOURCE'" >&2
    exit 1
fi

# --- Set Time Format String based on Configuration ---
if [ "$TIME_FORMAT" = "24h" ]; then
    TIME_TEXT_FORMAT='%H\:%M\:%S' # 24-hour format
    echo "Using 24-hour time format."
else
    TIME_TEXT_FORMAT='%I\:%M\:%S %p' # 12-hour format with AM/PM
    echo "Using 12-hour time format (default)."
fi

# --- Get Framebuffer Resolution ---
# We use 'ffprobe' to get the current resolution of the framebuffer device.
FB_INFO=$(ffprobe -v error -f fbdev -i "$FRAMEBUFFER" -show_streams -select_streams v:0 2>&1)

if ! echo "$FB_INFO" | grep -q 'width='; then
    echo "Error: Could not get resolution from framebuffer '$FRAMEBUFFER' using ffprobe." >&2
    exit 1
fi

SCREEN_W=$(echo "$FB_INFO" | grep 'width=' | head -n 1 | cut -d'=' -f2)
SCREEN_H=$(echo "$FB_INFO" | grep 'height=' | head -n 1 | cut -d'=' -f2)

if [ -z "$SCREEN_W" ] || [ -z "$SCREEN_H" ]; then
    echo "Error: Failed to parse resolution from ffprobe output." >&2
    exit 1
fi

echo "Detected screen resolution: ${SCREEN_W}x${SCREEN_H}"

# Disable framebuffer cursor blinking if possible
if [ -w "$CURSOR_BLINK_FILE" ]; then
    ORIGINAL_CURSOR_STATE=$(cat "$CURSOR_BLINK_FILE")
    echo 0 > "$CURSOR_BLINK_FILE"
    echo "Framebuffer cursor blinking disabled."
else
    echo "Warning: Cannot write to '$CURSOR_BLINK_FILE'. Cursor may blink. Run as root."
fi

# --- Step 1: Pre-scale the video to a temporary file ---
echo "Pre-scaling video to ${SCREEN_W}x${SCREEN_H}. This may take a moment..."
# -y: Overwrite output file if it exists
# -an: Strip audio stream, as it's not needed
# -c:v libx264 -preset ultrafast: Fast encoding for low-power devices
ffmpeg -y -i "$VIDEO_SOURCE" -filter_complex "scale=${SCREEN_W}:${SCREEN_H},split[v1][i];[i]drawtext=fontfile='${FONT_FILE}':\
                      text='Loading...':\
                      fontcolor=${TEXT_COLOR}:\
                      box=1:boxcolor=${TEXT_BG_COLOR}:boxborderw=15:\
                      fontsize=${LARGE_FONT_SIZE}:\
                      x=(w-text_w)/2:\
                      y=(h-text_h)/2[v2]" -map "[v1]" -c:v libx264 -preset ultrafast -an "$TEMP_VIDEO_FILE" -map "[v2]" -pix_fmt bgra -f fbdev "$FRAMEBUFFER" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "Error: Failed to pre-scale the video." >&2
    exit 1
fi
echo "Pre-scaling complete. Temporary file created at '$TEMP_VIDEO_FILE'."


# --- Step 2: Run the clock using the pre-scaled video ---
echo "Starting video clock. Press Ctrl+C to stop."

# The 'scale' filter is no longer needed here.
# The input (-i) is now our temporary, pre-scaled video.
while true; do
    ffmpeg \
        -re \
        -stream_loop -1 \
        -i "$TEMP_VIDEO_FILE" \
        -vf "drawtext=expansion=strftime:fontfile='${FONT_FILE}':\
                      text='%A, %B %d, %Y %Z':\
                      fontcolor=${TEXT_COLOR}:\
                      box=1:boxcolor=${TEXT_BG_COLOR}:boxborderw=10:\
                      fontsize=${SMALL_FONT_SIZE}:\
                      x=(w-text_w)/2:\
                      y=(h/2)-text_h-(${LARGE_FONT_SIZE}/2)-10, \
             drawtext=expansion=strftime:fontfile='${FONT_FILE}':\
                      text='${TIME_TEXT_FORMAT}':\
                      fontcolor=${TEXT_COLOR}:\
                      box=1:boxcolor=${TEXT_BG_COLOR}:boxborderw=15:\
                      fontsize=${LARGE_FONT_SIZE}:\
                      x=(w-text_w)/2:\
                      y=(h-text_h)/2" \
        -pix_fmt bgra \
        -f fbdev "$FRAMEBUFFER"
    sleep 1
done
