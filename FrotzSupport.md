This page contains frequently asked questions and miscellaneous help about using Frotz for the iPhone, iPad, and iPod Touch.

**Update 07/03/2020**

**Frotz 1.8.4** is now available, with the following changes:

  * Support for iOS 13, including light/dark mode
  * Support for newer devices with larger screen sizes.
  * Bug fixes.

**Update 07/01/2020**

**Frotz 1.8.3** is now available, with the following changes:

  * This version added support for iOS 13, but introduced a usability bug with manual saved games, fixed in 1.8.4.

**Update 10/03/2017**

**Frotz 1.8.2** now available, with the following changes:

  * Prevent games from being confused by iOS 11 'smart punctuation' feature.
  * Fix window resizing bug in glulx/glk games accidentally introduced in 1.8.1.
  * Launch shortcut to Story List (without resuming current game).
  * Other minor bug fixes, improvements to scrolling behavior.

**Update 09/30/2017**

**Frotz 1.8.1** now available, with the following changes:

  * Updated to DropBox API V2 for DropBox saved game syncing
  * Improvements for iOS 11
  * Other minor bug fixes
  
**Attention DropBox users:**

On September 28, 2017 Dropbox discontinued the version of their API which Frotz uses to automatically
sync saved games between devices and your DropBox account.  They forced all of their application
clients to completely re-write their DropBox support to continue functioning.
Frotz *1.8.1*, which restores DB support, was submitted to the App Store on 9/24, but was stuck in App Review limbo for 5 days, and wasn't
released in time for the API cut-off.   It is available now, and DB syncing will resume automatically
when you upgrade.  You do not have to re-authenticate or re-link your DropBox account.
Sorry for the inconvenience.


**Reporting Bugs**

To report an **bug or usability issue** with Frotz, please click [here to file a bug report](https://github.com/ifrotz/iosfrotz/issues/new?title=One-line%20summary&body=%5BPlease+glance+at+the+existing+issues+to+make+sure+the+problem+you+are%0D%0Areporting++isn%27t+a+known+issue+before+reporting.++Feel+free+to+remove+or%0D%0Aedit+any+parts+of+the+form+template+which+don%27t+apply+to+your+issue.%5D%0AD%0A%0AWhat+steps+will+reproduce+the+problem%3F%0A1.%0A2.%0A3.%0A%0AWhat+is+the+expected+output+or+behavior%3F++What+do+you+see+instead%3F%0A%0AWhat+version+of+Frotz+are+you+using%3F%0A1.7.1%0A%0AWhat+device+model+are+you+using+%28e.g.%2C+iPhone+6%2C+iPad+4%2C+iPod+Touch+4th+gen.%29%0AiPhone+6%0A%0AWhat+version+of+iOS%3F++%286.1%2C+7.0%2C+etc.%29%0A8.3%0A%0APlease+provide+any+additional+information+below.%0A).

If you have general comments or feedback about Frotz, you can post it on the [Frotz Discussion group](http://groups.google.com/group/ifrotz-discuss), or feel free to send email to **ifrotz at gmail dot com**.



**Update 09/06/2016**

**Frotz 1.8** now available, with following enhancements and bug fixes:

  * Now plays TADS games (v2/v3)
  * Improved support for iOS 9 and 10, including split screen multitasking
  * Performance improvements / 64-bit support
  * Various other bug fixes, including iOS 9 crash switching back to app

Previous version *Frotz 1.7.x* had with following enhancements and bug fixes:

  * UI makeover with support for iOS 7/8
  * New Search Bar in Story List.
  * Word auto-completion now uses the current game's vocabulary/dictionary.
  * Fixed issues with accented characters/Unicode support.
  * Improved support for graphics windows, inline images, and hyperlinks in glulx games.
  * Fixed problem where VoiceOver wouldn't read new text right after the game clears the screen.
  * Ability to long-press keyboard toggle button to hide and lock keyboard (for menu-only command input).
  * Update to glk spec 0.7.4, git interpreter 1.3.3.
  * Lots of other minor bug fixes.


---



---


**FAQ**

  * **Why can't you transfer files to Frotz using the iTunes file sharing feature?**

> Unfortunately, iTunes File Sharing doesn't support folders well, and Frotz uses folders internally to keep saved games separate for each story.  I'm not willing to make Frotz put all files at the top level in order for the files to show up in iTunes File Sharing.  If Apple adds better folder support, I will enable the ability in Frotz.  But check out the Dropbox feature, which is by far the easiest way to access your saved game files from multiple computers.

> **Update** - I went ahead and enabled iTunes File Sharing in 1.8, because there are other apps you can then use to connect to Frotz, such as FileApp, which deal with subfolders.

> **Update** - Apple rejected the 1.8.1 update because iTunes File Sharing made some of Frotz's internal files visible, so I had to disable it again to get it approved.  Enabling it in a way acceptable to Apple will require reorganizing Frotz's file structure, so I'll have to tackle that another day.  Sorry.


  * **Speaking of Folders...**
> A couple of people have asked for the ability to move games into folders.  This sounds like a nice idea, but it's actually really hard to design a good interface for manipulating folders that allows everything you'd want to be able to do without moving to a file-centric UI, where you end up with something looking like a desktop file browser.  I think this would benefit a few users at the expense of most, and don't think it's worth it.  (Even Apple didn't do a very good job of implementing Folders in IOS - how is dragging one app on top of another to make a folder intuitive in the least?)

> **Update** - I'm thinking of adding arbitrary, user-editable tags collections to the stories. Combined with the search bar, this may be better than folders.

  * **How can I transfer my own story files (e.g. Infocom files) so Frotz can find them?**

> If you have the Lost Treasures of Infocom, other Infocom game files from antiquity, or your own personal Z-Machine game files, you can use them with Frotz.
    * Starting in Frotz 1.5, you can launch Frotz from a story file mail attachment, or from a generic file management program such as Good Reader or Dropbox.
    * If the file is available on the Internet, although Frotz cannot (read: is not allowed to) download the file directly, you can browser to it in Mobile Safari, and then launch Frotz via the "Open In..." dialog which comes up when tapping a download link.
    * Frotz includes a built-in File Transfer server, so you can easily transfer your own story files, as well as saved games, from pretty much any computer.   To enable the server, press the (i)nfo button in Frotz,  select the "File Transfer" button, and follow the instructions.  Note that you must be connected to a wireless network to use file transfer; it will not work over cellular.  You can then connect to Frotz using either a web browser or ftp client over the local network.  The web interface is much easier to use than ftp and is recommended.
    * Note that Frotz will not look for stories in ZIP files if you transfer them; you should transfer the files individually and make sure they end in a standard suffix such as .z8 or .zblorb.
<a href='Hidden comment: 
* If you have your files on a web server, you can access them using the built-in web interface:
* In Frotz, go to "Browse IFDB", select the Search icon at the bottom, and type in the URL of your web server.
* Frotz will download and install if you click on any link ending in .z3, .z4, .z5, .z8, .dat, or .zblorb.
* You cannot download saved games this way; use the FTP server instead.
* Frotz can also handle ZIP downloads.  If you click on a ZIP file, Frotz will download it, extract files with the playable extensions and add them to the story list, and then delete the ZIP file.  Again, this doesn"t work with FTP, but I plan to add that in a future version.
'></a>

  * **What device/OS versions is Frotz compatible with?**

> Frotz 1.8 works on iPhone, iPad and iPod Touch devices running iOS 8.0 or later.
> If you have a device too old to run iOS 8, the previous version should show up in the App Store when accessed from the device. Frotz 1.7 works on iPhone, iPad and iPod Touch with OS versions 3.0 and later.

<a href='Hidden comment: 
Frotz would be worth nothing without the wealth of great games created by the talented writers and game designers in the IF (Interactive Fiction) community.  I"ve gotten a lot of enjoyment playing these games over the years, and since I"m not a very good writer, this is my way of giving back.
'></a>

  * **Can I make a donation?**

> If you really like Frotz and want to make a donation, you can do so via [PayPal](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=craig%40ni%2ecom&item_name=Frotz%20for%20iPhone%2fiPod%20Touch&no_shipping=0&no_note=1&tax=0&currency_code=USD&lc=US&bn=PP%2dDonationsBF&charset=UTF%2d8).   (Also consider sending thank you emails to the authors of the games you like!)

  * **How do I save my game?**
> If you press the Home button or answer a call, Frotz will automatically save your game state.  Starting with Frotz 1.4, a separate autosave is kept per game, and the game is autosaved when you switch stories or after a period of inactivity.   You can also manually save your game in progress the old-fashioned way by typing "**`save`**" at the command prompt; this is recommended for some of the harder/more complex games, so you have the ability to backtrack and try alternate solutions.

> Type "**`restore`**" to load a previously saved game.  These commands are available in the shortcut menu that appears when you double tap the command prompt as well.

  * **How do I delete games?**
> When you're not playing a story, the standard Edit button in the top right can be used to go into 'delete' mode.  When a story is active, this is replaced by "Now Playing", but you can still use the swipe gesture to delete a story.
> You can also delete games via the web file transfer interface.

