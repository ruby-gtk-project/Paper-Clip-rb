"""
Author: @DodoLeDev

Add a 'Edit pdf metadata' shortcut button to the right-click menu for pdf files (Nautilus GTK4)

Based on the file collision-extension.py created by myself and @GeopJr for the Collision application
    -> https://github.com/GeopJr/Collision/blob/main/nautilus-extension/collision-extension.py


Ported unchanged from upstream's data/nautilus-extension/paper-clip.py except
for two lines: the binary it looks for and launches is the port's
`paper-clip`, and the text domain is the gettext package name
(`pdf-metadata-editor`) rather
than the application id, which is the name the .mo files are installed under.
The msgid is upstream's byte for byte.
"""

from subprocess import Popen, check_call, CalledProcessError
from urllib.parse import urlparse, unquote
from gi import require_version
from gettext import textdomain, gettext

textdomain('pdf-metadata-editor')
_ = gettext

require_version('Gtk', '4.0')
require_version('Nautilus', '4.0')

from gi.repository import Nautilus, GObject, Gtk, Gdk

def is_paperclip_installed():
    try:
        ################################## TO EDIT ##################################
        # TODO: Find a viable way to detect if PaperClip is installed on the system #
        #############################################################################
        check_call("[[ -f /usr/bin/paper-clip ]] &> /dev/null", shell=True)
        
        return True
    except CalledProcessError:
        return False

class NautilusPaperClip(Nautilus.MenuProvider, GObject.GObject):

    def __init__(self):
        self.window = None
        return
    
    # Executed method when the right-click entry is clicked
    def openWithPaperClip(self, menu, file):

        get_path = lambda file: repr(unquote(urlparse(file.get_uri()).path)) # URI parser

        file_path = get_path(file[0])  # Get the absolute file path
        
        ################### TO EDIT ###################
        # TODO: Find a viable way to launch PaperClip #
        ###############################################
        Popen("/usr/bin/paper-clip " + file_path, shell=True)  # Execute the command
    
    # Displays nothing on a right click on the background
    def get_background_items(self, files):
        return

    def get_file_items(self, files):

        # Do not display menu entry if it is not a pdf file that is selected
        def check_file_types():
            if files[0].get_uri().endswith('.pdf'):
                return True
            return False
            
        only_one_file = lambda : True if len(files) == 1 else False
        
        # The option doesn't appear when a folder or a non-pdf file is selected
        if not is_paperclip_installed() or not only_one_file() or not check_file_types(): 
            return ()

        # Registering entry in the Nautilus right-click
        menu_item = Nautilus.MenuItem(
                        name="NautilusPaperClip::EditMetadata",
                        label=_("Edit pdf metadata…"))

        menu_item.connect('activate', self.openWithPaperClip, files)

        return menu_item,
