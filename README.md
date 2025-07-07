# **FFmpeg Video Clock for Framebuffer**
Written by: XtendedGreg July 7, 2025 [XtendedGreg Youtube Channel](https://www.youtube.com/@xtendedgreg)

## Description

A configurable shell script that displays a real-time clock over a looping video background on a Linux framebuffer device. This project is optimized for low-power devices like the Raspberry Pi running minimal operating systems such as Alpine Linux.

## **Features**

* **Motion Video Background:** Uses any ffmpeg-compatible video file as a looping background.  
* **Customizable Clock Display:**  
  * Displays the full date, day of the week, and timezone.  
  * Displays the time with hours, minutes, and seconds.  
  * Configurable 12-hour (with AM/PM) or 24-hour time format.  
* **Optimized for Raspberry Pi:** Pre-scales the background video to match the screen resolution, storing it in a temporary file to minimize real-time CPU load.  
* **Automatic Centering:** Automatically detects the framebuffer resolution and centers the clock text perfectly on screen.  
* **Highly Configurable:** All settings, including fonts, colors, file paths, and time format, are managed through a simple configuration file.  
* **Clean Operation:** Disables the blinking framebuffer cursor during runtime and automatically cleans up all temporary files on exit.

## **Requirements**

* ffmpeg: The core dependency for all video and text rendering.  
* ffprobe: Used for detecting screen resolution (included with the ffmpeg package).  
* A TTF font file installed on the system.

On Alpine Linux, you can install the necessary dependencies with:
```
apk update  
apk add screen ffmpeg font-dejavu
```

## **Installation**

1. Place the Script:  
   Copy the videoclock.sh script to a suitable location on your system, for example, /bin/.
   ```
   cp videoClock.sh /bin/videoClock.sh
   chmod +x /bin/videoClock.sh
   ```

2. Create the Configuration Directory:  
   The script is designed to look for its configuration file in /etc/videoClock/. Create this directory:
   ```
   mkdir -p /etc/videoClock
   ```

3. Create the Configuration File:  
   Copy the sample videoclock.conf file into the new directory.
   ```
   cp videoClock.conf /etc/videoClock/videoClock.conf
   ```

4. Place the Init.d Script to Start on Boot:  
   Copy the videoClock script to the /etc/init.d/ folder.
   ```
   cp videoClock /etc/init.d/videoClock
   chmod +x /etc/init.d/videoClock
   rc-update add videoClock default
   ```

5. (Optional) If not a disk install, add the files to LBU to persist after reboot.
   ```
   lbu add /bin/videoClock.sh /etc/init.d/videoClock
   lbu commit -d
   ```

7. Edit the Configuration:  
   Open /etc/videoClock/videoClock.conf with a text editor and adjust the settings to match your system and preferences. See the Configuration section below for details.

## **Configuration**

All settings are managed in /etc/videoClock/videoClock.conf.

| Setting | Description | Example |
| :---- | :---- | :---- |
| VIDEO\_SOURCE | The full path to your background video file. | /root/videos/background.mp4 |
| FONT\_FILE | The full path to the .ttf font file you want to use. | /usr/share/fonts/dejavu/DejaVuSans-Bold.ttf |
| TEXT\_COLOR | The color of the clock text. Can be a name or hex code. | white or \#FFFFFF |
| TEXT\_BG\_COLOR | The color and opacity of the box behind the text. Format is color@opacity (0.0 to 1.0). | black@0.5 |
| FRAMEBUFFER | The framebuffer device to output to. | /dev/fb0 |
| SMALL\_FONT\_SIZE | The font size for the date line of text. | 30 |
| LARGE\_FONT\_SIZE | The font size for the time line of text. | 90 |
| TIME\_FORMAT | The time display format. Use 12h for 12-hour with AM/PM, or 24h for 24-hour format. | 12h |

## **Usage**

Once installed and configured, you can start the clock service directly from the command line:
```
service videoClock start
```
Use the following command to stop the clock service from the command line:
```
service videoClock stop
```
The script will automatically perform a cleanup, deleting the temporary video file and restoring the cursor state.

### **Important Note: Memory (RAM) Usage**

This script's optimization works by pre-scaling the background video and storing it in a temporary file located in /tmp. For the main clock display, ffmpeg loads this entire temporary video file into your system's RAM.

On a memory-constrained device like a Raspberry Pi, this means **the length and complexity of your source video are critical**. A long, high-bitrate video will result in a large temporary file that may exceed the available RAM, causing the script to fail or the system to become unstable.

**Recommendation:** Use short, seamlessly looping videos (e.g., 15-30 seconds) for the best performance and stability.
