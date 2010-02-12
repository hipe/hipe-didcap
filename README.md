hipe-didcap - dynamic interval delta (screen) capture.

### what?
a wrapper around ffmpeg that does some stuff.

The idea is to make a timelapse screencast.  You take a snapshot of your
screen every 5 seconds or so, and keep that image only if it is different
than the previous image.  When you are done 'recording', you splice all the
images together to make a movie file.  The result is supposed to be a
change-sensitive time lapse.  We'll see.


### how?
    ~> hipe-didcap start
    ~> hipe-didcap stop
    ~> hipe-didcap build

<br/>

### how to install?
#### install ffmpeg on mac snowleopard with intel chip:
 (from http://stephenjungels.com/jungels.net/articles/ffmpeg-howto.html)

    ~ > mkdir ~/ffmpeg; cd ~/ffmpeg
    ~/ffmpeg > svn checkout svn://svn.ffmpeg.org/ffmpeg/trunk svn-source
    ~/ffmpeg > mkdir build; cd build
    ~/ffmpeg/build > ../svn-source/configure --enable-shared --arch=x86_64
    ~/ffmpeg/build > make; sudo make install

#### install ffmpeg in other environments:
  * _ffmpeg is linuxy and windowsesque so let me know how that works out for you._


#### install didcap
    ~> gem install hipe-didcap


<br/>
### credits / thankyou's
  - all contributors to the ffmpeg project especially for getting this to work on mac
  - the helpful people in #ffpeg for making this much less painful than expected
  - Aria for helping me with fork
  - Jan Wikholm for helping me with Open4

<br/>
### support
please let me know how it works out for you.  i'm always in #ruby-lang on irc.freenode.net.  well, not when asleep.
