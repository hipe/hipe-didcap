hipe-didcap - dynamic interval delta (screen) capture.

this is a wrapper around ffmpeg that does some stuff.

The idea is to make a timelapse screencast.  You take a snapshot of your
screen every 5 seconds or so, and keep that image only if it is different
than the previous image.  When you are done 'recording', you spice all the
images together.  The result is supposed to be a change-sensitive time lapse.
We'll see.

------

Installation guide:

@todo depends on hipe-core gem

Install ffmpeg:

installing ffmpeg on mac snowleopard with intel chip
from
  http://stephenjungels.com/jungels.net/articles/ffmpeg-howto.html

~ > mkdir ~/ffmpeg; cd ~/ffmpeg
~/ffmpeg > svn checkout svn://svn.ffmpeg.org/ffmpeg/trunk svn-source
~/ffmpeg > mkdir build; cd build
~/ffmpeg/build > ../svn-source/configure --enable-shared --arch=x86_64
~/ffmpeg/build > make; sudo make install
