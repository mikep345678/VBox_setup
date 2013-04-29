#!/bin/bash

# this script should reside at /usr/local/bin/vbox_setup.sh

# Typical use:
#   automated install: 'vbox_setup doitall'

# For testing, 'vbox_set recreate' or call with desired individual command:
#   create_umountwin, umountwin, fixsharedperms, makevboxfolders, fixsharedperms,
#   linkvboxlib, fixsharedperms, vboxinstall, fixsharedperms, makewin7vbox,
#   movemachinedef, fixsharedperms, makedockicon
#  Call 'vbox_setup cleanup' to remove the shared VM

###
### !!! remember to check "installfrom" variable in vboxinstall() !!!
###

#############
# set global VBox home folder variable.
export VBOX_USER_HOME=/Users/Shared/vbox

#############
create_umountwin()
{
# install umountwin
#   System LaunchDaemon calls umountwin.sh on bootup to unmount Windows partition at every boot
#    - umountwin.sh goes in /usr/local/bin
#    - net.barabooschools.umountwin.plist goes in /Library/LaunchDaemons

###
### umountwin has been moved to it's own deployment package and is now distributed to
###   all machines during imaging so this function only resides here for fun...
###

logger -t [vbox_setup] "$FUNCNAME starting..."

if [ ! -f /usr/local/bin/umountwin.sh ]
then

echo "creating and registering umountwin.sh..."

# create umountwin.sh
cat > /usr/local/bin/umountwin.sh <<\EOF
#!/bin/bash

#/usr/local/bin/umountwin.sh
# unmount Windows partition on system startup for VBox access

# called from system LaunchDaemon net.barabooschools.umountwin.plist at bootup
winpart=$(diskutil list | grep WINDOWS | awk '{ print $NF }')

if [ -n "$winpart" ]; then # only if winpart is nonzero
	logger -t [umountwin] Unmounting Windows partition $winpart
	chmod 777 /dev/$winpart
	diskutil unmount /dev/$winpart
else
	echo "No Windows partition!"
fi

exit 0
EOF

chown root:wheel /usr/local/bin/umountwin.sh
chmod 755 /usr/local/bin/umountwin.sh

fi

if [ ! -f /Library/LaunchDaemons/net.barabooschools.umountwin.plist ]
then

# create /Library/LaunchDaemons/net.barabooschools.umountwin.plist to run umountwin.sh on system boot
cat > /Library/LaunchDaemons/net.barabooschools.umountwin.plist <<\EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple$
<plist version="1.0">
<dict>

<key>Label</key>
<string>net.barabooschools.umountwin</string>

<key>Disabled</key>
<false/>

<key>ProgramArguments</key>
<array>
<string>/usr/local/bin/umountwin.sh</string>
</array>

<key>RunAtLoad</key>
<true/>

<key>StandardErrorPath</key>
<string>/Library/Logs/umountwin_errors.log</string>

<key>StandardOutPath</key>
<string>/Library/Logs/umountwin_out.log</string>

</dict>
</plist>
EOF

chown root:wheel /Library/LaunchDaemons/net.barabooschools.umountwin.plist
chmod 644 /Library/LaunchDaemons/net.barabooschools.umountwin.plist

fi

logger -t [vbox_setup] "$FUNCNAME completed..."
}

#############
umountwin()
{
# umount WINDOWS
logger -t [vbox_setup] "$FUNCNAME starting..."

/usr/local/bin/umountwin.sh

logger -t [vbox_setup] "$FUNCNAME completed..."
}


#############
vboxinstall()
{
logger -t [vbox_setup] "$FUNCNAME starting..."

echo "Installing VirtualBox..."

vboxpkg="VirtualBox.pkg"
#extpack_name="Oracle_VM_VirtualBox_Extension_Pack-4.2.6-82870.vbox-extpack"
# instead of changing this script every time we rebuild this package after a version upgrade, hardlink current extpack:
#   ln SoftwareDeployment/VirtualBox/Oracle_VM_VirtualBox_Extension_Pack-4.2.12-84980.vbox-extpack SoftwareDeployment/VirtualBox/vbox.vbox-extpack
extpack_name="vbox.vbox-extpack"


#logger -t [vbox_setup] "$FUNCNAME looking for $1/Contents/Resources/$vboxpkg..."
#logger -t [vbox_setup] "$FUNCNAME ls: $(ls -la $1/Contents/Resources/$vboxpkg)..."

# package places installation files at /tmp/SDOB_VBox
# -- depricated: this is not correct because this is not "postflight": if packaging install, $installfrom should be "$0/Contents/Resources/"
if [ -f "/Users/tsadmin/Desktop/$vboxpkg" ]; then
	installfrom=/Users/tsadmin/Desktop
elif [ -f "$1/Contents/Resources/$vboxpkg" ]; then
	installfrom="$1/Contents/Resources"
elif [ -f "/tmp/SDOB_VBox/$vboxpkg" ]; then
	installfrom="/tmp/SDOB_VBox"
else
	logger -t [vbox_setup] "$FUNCNAME error-- missing pkg..."
	exit 1
fi

logger -t [vbox_setup] "$FUNCNAME installing from $installfrom/$vboxpkg..."

# Install VirtualBox
/usr/sbin/installer -dumplog -verbose -pkg "$installfrom/$vboxpkg" -target LocalSystem

# Install extension pack
/Applications/VirtualBox.app/Contents/MacOS/VBoxManage extpack install "$installfrom/$extpack_name"

# Disable update checking
VBoxManage setextradata global "GUI/UpdateDate" value="never"

logger -t [vbox_setup] "$FUNCNAME completed..."
}


#############
makevboxfolders()
{
logger -t [vbox_setup] "$FUNCNAME started..."

echo "Creating vbox folders in /Users/Shared..."

# create /Users/Shared/vbox
mkdir -p /Users/Shared/vbox
mkdir -p /Users/Shared/vbox/drives
mkdir -p /Users/Shared/vbox/Library/VirtualBox

chmod -R a+rXw /Users/Shared/vbox
chown -R root:everyone /Users/Shared/vbox

logger -t [vbox_setup] "$FUNCNAME completed..."
}


#############
linkvboxlib()
{
# link all existing and future users' ~/Library/VirtualBox to /Users/Shared/vbox/Library/VirtualBox

logger -t [vbox_setup] "$FUNCNAME started..."

echo "linking all existing and future users ~/Library/VirtualBox to /Users/Shared/vbox/Library/VirtualBox..."

#ln -s -f /Users/Shared/vbox/Library/VirtualBox /Users/tsadmin/Library/VirtualBox
#sudo ln -s -f /Users/Shared/vbox/Library/VirtualBox /System/Library/User\ Template/English.lproj/Library/VirtualBox

template="/System/Library/User Template/English.lproj"

sourcefolder="Library/VirtualBox"
targetfolder="/Users/Shared/vbox/Library/VirtualBox"

templatesourcefolder="$template/$sourcefolder"

#mkdir -p $templatesourcefolder

ln -s -F "$targetfolder" "$templatesourcefolder"
chown root:wheel "$template/$sourcefolder"
chmod 700 "$template/$sourcefolder"

for a in $(ls /Users | grep -v "^\." | grep -v "Shared")
do
	ln -s -F "$targetfolder" "/Users/$a/$sourcefolder"
	chown $a:everyone "/Users/$a/$sourcefolder"
    chmod u=rw,go=r "/Users/$a/$sourcefolder"
done

logger -t [vbox_setup] "$FUNCNAME completed..."
}

#############
makewin7vbox()
{
echo "Creating Win7vbox..."

logger -t [vbox_setup] "$FUNCNAME started..."

#   determine disk id of Windows partition
winpart=$(diskutil list | grep WINDOWS | awk '{ print $NF }')
#   determine partition number of Windows partition
winpartnum=${winpart: -1}

# create win7raw.vmdk from physical drive in /Users/Shared/vbox/drives
/Applications/VirtualBox.app/Contents/MacOS/VBoxManage internalcommands createrawvmdk -rawdisk /dev/disk0 -filename "/Users/Shared/vbox/drives/win7raw.vmdk" -partitions $winpartnum

# create Win7 virtual machine
VBoxManage createvm --name "Win7" --register --ostype Windows7_64 --basefolder "/Users/Shared/vbox"
VBoxManage modifyvm Win7 --memory 2048
VBoxManage modifyvm Win7 --vram 27
VBoxManage modifyvm Win7 --accelerate3d on

VBoxManage storagectl Win7 --name "SATA" --add sata --sataportcount 1 --controller IntelAHCI --bootable on
#VBoxManage storageattach Win7 --storagectl SATA --type HDD --port 0 --device 0 --medium "/Users/Shared/vbox/drives/win7raw.vmdk"
#VBoxManage storagectl Win7 --name PIIX4 --add ide --controller PIIX4
VBoxManage storagectl Win7 --name IDE --add ide --controller ICH6
VBoxManage storageattach Win7 --storagectl IDE --port 0 --device 1 --type dvddrive --medium emptydrive
VBoxManage storageattach Win7 --storagectl IDE --type HDD --port 0 --device 0 --medium "/Users/Shared/vbox/drives/win7raw.vmdk"

VBoxManage setextradata global GUI/SuppressMessages
VBoxManage setextradata global GUI/SuppressMessages remindAboutAutoCapture,confirmInputCapture,remindAboutMouseIntegrationOn,remindAboutWrongColorDepth,confirmGoingFullscreen,remindAboutMouseIntegrationOff

VBoxManage setextradata global GUI/UpdateDate never

VBoxManage snapshot Win7 take Windows7

logger -t [vbox_setup] "$FUNCNAME completed..."
}


#############
movemachinedef()
{
logger -t [vbox_setup] "$FUNCNAME started..."

echo "copying VirtualBox.xml..."
cp /Users/Shared/vbox/VirtualBox.xml /Users/Shared/vbox/Library/VirtualBox/VirtualBox.xml

logger -t [vbox_setup] "$FUNCNAME completed..."
}


#############
fixsharedperms()
{
# fix permissions to /Users/Shared folders to full access for all users. Also runs at login from net/lib/sdob-ts/lish

logger -t [vbox_setup] "$FUNCNAME started..."

echo "Fixing perms on /Users/Shared..."

logger -t [fixsharedperm] "Fixing perms on /Users/Shared"
chmod -R a+rXw /Users/Shared/
chown -R root:everyone /Users/Shared/

logger -t [vbox_setup] "$FUNCNAME completed..."
}


#############
makedockicon()
{
# Create dock icon for all users to Window7 VM starter app

logger -t [vbox_setup] "$FUNCNAME started..."

/usr/local/bin/dockutil --add /Applications/Windows7.app --allhomes
/usr/local/bin/dockutil --add /Applications/Windows7.app '/System/Library/User Template/English.lproj'


logger -t [vbox_setup] "$FUNCNAME completed..."
}


#############
cleanup()
{
# remove shared VM

logger -t [vbox_setup] "$FUNCNAME started..."

#ln -s -f /Users/Shared/vbox/Library/VirtualBox /Users/tsadmin/Library/VirtualBox
#sudo ln -s -f /Users/Shared/vbox/Library/VirtualBox /System/Library/User\ Template/English.lproj/Library/VirtualBox

rm -rf /Users/Shared/vbox

template="/System/Library/User Template/English.lproj"

sourcefolder="Library/VirtualBox"
targetfolder="/Users/Shared/vbox/Library/VirtualBox"

templatesourcefolder="$template/$sourcefolder"

echo "removing template ln..."
rm -rf "$templatesourcefolder"

echo "removing template ln in:"
for a in $(ls /Users | grep -v "^\." | grep -v "Shared")
do
	echo "/Users/$a/$sourcefolder"...
	rm -rf "/Users/$a/$sourcefolder"
done

echo "redoing user permissions..."
for a in $(ls /Users | grep -v "^\." | grep -v "Shared")
do
	chown -R $a:everyone "/Users/$a"
	chmod -R u=rw,go=r "/Users/$a"
done

logger -t [vbox_setup] "$FUNCNAME completed..."
}


#############
doitall()
{
logger -t [vbox_setup] "$FUNCNAME started..."

if [ -d "/Applications/VirtualBox.app" ]; then
	# Virtualbox is already on the machine; just upgrade it!
	logger -t [vbox_setup] "VirtualBox exists; upgrading..."
	vboxinstall
else
	create_umountwin
	umountwin
	fixsharedperms
	makevboxfolders
	fixsharedperms
	linkvboxlib
	fixsharedperms
	vboxinstall
	fixsharedperms
	makewin7vbox
	movemachinedef
	fixsharedperms
	makedockicon
fi

logger -t [vbox_setup] "$FUNCNAME completed..."
}


#############
reallydoitall()
{
logger -t [vbox_setup] "$FUNCNAME started..."

	create_umountwin
	umountwin
	fixsharedperms
	makevboxfolders
	fixsharedperms
	linkvboxlib
	fixsharedperms
	vboxinstall
	fixsharedperms
	makewin7vbox
	movemachinedef
	fixsharedperms
	makedockicon

logger -t [vbox_setup] "$FUNCNAME completed..."
}
#############
recreate()
{
logger -t [vbox_setup] "$FUNCNAME started..."

cleanup
umountwin
fixsharedperms
makevboxfolders
fixsharedperms
linkvboxlib
fixsharedperms
makewin7vbox
movemachinedef
fixsharedperms
makedockicon

logger -t [vbox_setup] "$FUNCNAME completed..."
}

$1

exit 0


