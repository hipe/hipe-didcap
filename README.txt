hipe-didcap - dynamic interval delta (screen) capture

this is a wrapper around ffmpeg that does some stuff.

INSTALL ffmpeg:

installing ffmpeg on mac snowleopard with intel chip
from
  http://stephenjungels.com/jungels.net/articles/ffmpeg-howto.html

~ > mkdir ~/ffmpeg; cd ~/ffmpeg
~/ffmpeg > svn checkout svn://svn.ffmpeg.org/ffmpeg/trunk svn-source
~/ffmpeg > mkdir build; cd build
~/ffmpeg/build > ../svn-source/configure --enable-shared --arch=x86_64
~/ffmpeg/build > make; sudo make install
