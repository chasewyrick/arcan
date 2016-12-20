Arcan
=====

Arcan is a powerful development framework for creating virtually anything from
user interfaces for specialized embedded applications all the way to full-blown
standalone desktop environments.

At its heart lies a robust and portable multimedia engine, with a well-tested
and well-documented Lua scripting interface. The development emphasizes
security, debuggability and performance -- guided by a principle of least
surprise in terms of API design.

For more details about capabilities, design, goals, current development,
roadmap, changelogs, notes on contributing and so on, please refer to the
[arcan-wiki](https://github.com/letoram/arcan/wiki).

There is also a [website](https://arcan-fe.com) that collects other links,
announcements, releases, videos / presentations and so on.

For developer contact, check out the IRC channel #arcan on irc.freenode.net.

# Table of Contents
1. [Getting Started](#started)
    1. [Compiling](#compiling)
2. [Compatibility](#compatibility)
3. [Other Tools](#tools)
4. [Appls to Try](#appls)
5. [Database Configuration](#database)
6. [Git layout](#gitlayout)

Getting Started <a name="started"></a>
====

The rest of this readme is directed towards developers or very advanced end-
users as there is no real work or priority being placed on wrapping/packaging
the project and all its pieces at this stage.

Compiling
----
There are a lot of build options for fine-grained control over your Arcan
build. In this section we will just provide the bare essentials for a build
on Linux, BSD or OSX. and you can check out the relevant sections in the wiki
for more detailed documentation on specialized build environments, e.g. an
X.org-free KMS/DRM. (https://github.com/letoram/arcan/wiki/linux-egl)

For starters, the easiest approach is to do the following:

     git clone https://github.com/letoram/arcan.git
     cd arcan
     mkdir build
     cd build
     cmake -DCMAKE_BUILD_TYPE="Debug" -DVIDEO_PLATFORM=sdl ../src
     make -j 12

The required dependencies for this build are: cmake for compilation,
libsdl1.2, openal-soft, opengl and freetype. There is also support
for building some of these dependencies statically:

     git clone https://github.com/letoram/arcan.git
     cd arcan/external/git
     ./clone.sh
     cd ../../
     mkdir build
     cd build
     cmake -DCMAKE_BUILD_TYPE="Debug" -DVIDEO_PLATFORM=sdl
      -DSTATIC_SQLITE3=ON -DSTATIC_OPENAL=ON -DSTATIC_FREETYPE=ON ../src
     make -j 12

You can then test the build with:

     ./arcan -p ../data/resources/ ../data/appl/welcome

Which tells us to use shared resources from the ../data/resources directory,
and launch an application that resides as ../data/appl/welcome. If this path
isn't specified relative to current path (./ or ../) or absolute (/path/to),
the engine will try and search in the default 'applbase'. This path varies
with the OS, but is typically something like /usr/local/share/arcan/appl
or to the current user: /path/to/home/.arcan/appl

The 'recommended' setup is to have a .arcan folder in your user home directory
with a resources and appl subdirectory. Symlink/bind-mount the data you want
accessible into the .arcan/resources path, and have the runable appls in
.arcan/appl.

Compatibility
====
The set of applications that can connect to arcan and use it as a display
server is rather limited. There are specialized back-end patches for some
projects, like SDL2, QEmu and Xorg that you can build and use. Please see
external/compat.README for more information.

There is also an alpha- quality Wayland implementation that is enabled as
a separate protocol bridge tool. This can be found in tools/waybridge but
first, checkout the tools/waybridge/README.md file.

Lastly, there is also the option of using hijack (LD\_PRELOAD and similar
mechanisms) for hacky ways to access legacy software. You can enable this
with the build-time -DDISABLE\_HIJACK=OFF and get access to an SDL1.2 lib
and an Xlib (extremely incomplete, only really useful when there's a dep-
endency that is accidental rather than actually necessary). These will be
built as libahijack\_sdl12.so and libahijack\_x11.so.

Other Tools<a name="tools"></a>
====

Depending on build-time configuration and dependencies, a number of other
binaries may also have been produced. The particularly relevant ones are:

arcan\_lwa: specialized build that connects/renders to an existing Arcan
instance, similar in some ways to Xnest or ephyr.

arcan\_frameserver: a chainloader used to setup/configure the environment
for the individual frameservers.

Frameservers are an important part of the engine. They can be considered
specialized or privileged separate processes for offloading or isolating
sensitive and bug-prone tasks like parsing and decoding media files. One
frameserver implements a single 'archetype' out of the set (decode, net,
encode, remoting, terminal, game, avfeed). The running appl- scripts can
then use these to implement features like desktop sharing, accessibility
tools, screen recorders, etc. with a uniform interface for system-access
policies and granular sandboxing controls.

afsrv\_terminal: the default terminal emulator implementation.

afsrv\_decode: media decoding and rendering implementation, default version
uses libvlc.

afsrv\_encode: used for transforming/recording/streaming media.

afsrv\_net: (experimental/broken) used for negotiating/discovering
local networking services.

afsrv\_remoting: client-side for bridging with remote desktop style protocols,
with the default using VNC.

afsrv\_game: implementation of the [libretro](http://libretro.com) API that
allows you to run a large number of game engines and emulators.

afsrv\_avfeed: custom skeleton for testing/ quick- wrapping some A/V device.

Appls to try<a name="appls"></a>
====

With the engine built, and the welcome- test appl running, what to try next?
That depends on your fancy. For appl- development you have some basic scripting
tutorials and introduction documentation on the wiki.

For desktop environment use, there are two usable ones available right now,
'durden' and 'prio'. 'Durden' is an attempt at evolving a complete, customizable,
heavily integrated approach to the keyboard dominant management/use style promoted
by tiling window managers like Xmonad or i3.

'Prio' is instead a much simpler skeleton for a composable desktop where third
party providers can be set to be responsible for different parts of the UI. Its
window management model is an homage to the 'Rio' system used as part of the
Plan9 operating system.

Demonstrating how more advanced applications can be built, there is also
[senseye](https://github.com/letoram/senseye/wiki), which is an research- level
data visualization, debugging and reverse engineering tool - but senseye is likely
to only be of use to those few that have an unhealthy interest in such areas.

To try out durden or prio:

    git clone https://github.com/letoram/durden.git
    arcan -p /my/home /path/to/checkout/durden/durden

    git clone https://github.com/letoram/prio.git
		arcan -p /my/home /path/to/checkout/prio

The basic format for starting is arcan:
    [engine arguments] applname [appl arguments]

Note that it's the durden subdirectory in the git, not the root. The reason
for the different start path (-p /my/home) is to give read-only access to
the appl for the built-in resource browser. It is possible that (depending
on platform, time of day, the use of bastard devices like KVMs etc.) the
detected resolution is wrong. You can explicitly override that for now by
using -w desiredwidth -h desiredheight as arguments to the engine.

For details on configuring and using durden or prio, please refer to the
respective README.md provided in each git. There are also demonstration
videos on the [youtube-channel](https://www.youtube.com/user/arcanfrontend).

Database
=====
Among the output binaries is one called arcan\_db. It is a tool that can be
used to manipulate the sqlite- database that the engine requires for some
features, e.g. application specific key/value store for settings, but also for
whitelisting execution.

An early design decision was that the Lua VM configuration should be very
restrictive -- no arbitrary creation / deletion of files, no arbitrary
execution etc. The database tool is used to specify explicitly permitted
execution that should not be modifable from the context of the running arcan
application.

The following example attempts to illustrate how this works:

        arcan_db db.sqlite add_target example_app /some/binary -some -args
        arcan_db db.sqlite add_config example_app more_args -yes -why -not
        arcan_db add_target mycore RETRO [ARCAN_RESOURCEPATH]/.cores/core.so
				arcan_db add_config mycore myconfig RETRO [ARCAN_RESOURCEPATH]/.assets/somefile

An arcan application should now be able to:

        launch_target("example_app", "more_args", LAUNCH_EXTERNAL);

or

        vid = launch_target("example_app",
            "more_args", LAUNCH_INTERNAL, callback_function);

The first example would have the engine minimize and release as much
resources as possible (while still being able to resume at a later point),
execute the specified program and wake up again when the program finishes.

The second example would execute the program in the background, expect it to
be able to handle the engine shmif- API for audio/video/input cooperatively
or through an interposition library.

It can be cumbersome to set up database entries to just test something.
Frameservers is a way of separating sensitive or crash-prone functions from
the main engine for purposes such as running games or playing back video.

In a default installation, they are prefixed with afsrv\_ [game, encode,
decode, ...] and while they are best managed from the appl itself, you can
run them from the terminal as well. Which ones that are available depend on
the dependencies that were available at build time, but for starting a
libretro core for instance:

    ARCAN_ARG=core=/path/to/core:resource=/path/to/resourcefile afsrv\_game

or video playback:

    ARCAN_ARG=file=/path/to/moviefile.mkv afsrv_decode

but they are all best managed from the engine and its respective scripts.

Filesystem Layout<a name="gitlayout"></a>
=====
The git-tree has the following structure:

    data/ -- files used for default packaging and installation (icons, etc.)

    doc/*.lua -- specially formatted script files (1:1 between Lua API
                 functions and .lua file in this folder) that is used
                 by doc/mangen.rb to generate manpages, test cases,
                 editor syntax highlighting etc.

    doc/*.1   -- manpages for the binaries
    doc/*.pdf -- presentation slides (updated yearly)
    external/ -- external dependencies that may be built in-source

    src/
        engine/ -- main engine code-base
        frameserver/ -- individual frameservers and support functions
        hijack/ -- interpositioning libraries for different data sources
        platform/ -- os/audio/video/etc. interfacing
				tools/ -- database tools, keymap conversion, protocol/device bridges
        shmif/ -- engine<->frameserver IPC

    tests/ -- (fairly incomplete, development focus target now)
          api_coverage -- dynamically populated with contents from doc/
          benchmark -- scripts to pinpoint bottlenecks, driver problems etc.
          interactive -- quick/messy tests that are thrown together during
                         development to test/experiment with some features.
          security -- fuzzing tools, regression tests for possible CVEs etc.
          regression -- populated with test-cases that highlight reported bugs.
          exercises -- solutions to the exercises in the wiki.
          examples -- quick examples / snippets

