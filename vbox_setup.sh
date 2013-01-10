#!/bin/bash

# set global VbBox variable.
export VBOX_USER_HOME=/Users/Shared/vbox


#############
create_umountwin()
{
# install umountwin
#   System LaunchDaemon calls umountwin.sh on bootup to unmount Windows partition at every boot
#    - umountwin.sh goes in /usr/local/bin
#    - net.barabooschools.umountwin.plist goes in /Library/LaunchDaemons

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
}

#############
umountwin()
{
# umount WINDOWS
/usr/local/bin/umountwin.sh
}


#############
vboxinstall()
{
echo "Installing VirtualBox..."

# if packaging install, $installfrom should be "$1/Contents/Resources/"
installfrom=/Users/tsadmin/Desktop

# Install VirtualBox
/usr/sbin/installer -pkg $installfrom/VirtualBox.pkg -target LocalSystem

# Install extension pack
/Applications/VirtualBox.app/Contents/MacOS/VBoxManage extpack install $installfrom/Oracle_VM_VirtualBox_Extension_Pack-4.2.4-81684.vbox-extpack
}


#############
makevboxfolders()
{
echo "Creating vbox folders in /Users/Shared..."

# create /Users/Shared/vbox
mkdir -p /Users/Shared/vbox
mkdir -p /Users/Shared/vbox/drives
mkdir -p /Users/Shared/vbox/Library/VirtualBox

chmod -R a+rXw /Users/Shared/vbox
chown -R root:everyone /Users/Shared/vbox
}


#############
linkvboxlib()
{
# link all existing and future users' ~/Library/VirtualBox to /Users/Shared/vbox/Library/VirtualBox

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
}

#############
makewin7vbox()
{
echo "Creating Win7vbox..."

#   determine disk id of Windows partition
winpart=$(diskutil list | grep WINDOWS | awk '{ print $NF }')
#   determine partition number of Windows partition
winpartnum=${winpart: -1}

# create win7raw.vmdk from physical drive in /Users/Shared/vbox/drives
/Applications/VirtualBox.app/Contents/MacOS/VBoxManage internalcommands createrawvmdk -rawdisk /dev/disk0 -filename "/Users/Shared/vbox/drives/win7raw.vmdk" -partitions $winpartnum

# create Win7 virtual machine
VBoxManage createvm --name "Win7" --register --ostype Windows7_64 --basefolder "/Users/Shared/vbox"
VBoxManage modifyvm Win7 --memory 1024
VBoxManage storagectl Win7 --name "SATA" --add sata --sataportcount 1 --controller IntelAHCI --bootable on
VBoxManage modifyvm Win7 --vram 27
VBoxManage storageattach Win7 --storagectl SATA --type HDD --port 0 --device 0 --medium "/Users/Shared/vbox/drives/win7raw.vmdk"
VBoxManage storagectl Win7 --name PIIX4 --add ide --controller PIIX4
VBoxmMnage storageattach Win7 --storagectl PIIX4 --port 0 --device 0 --type dvddrive --medium emptydrive

VBoxManage setextradata global GUI/SuppressMessages
VBoxManage setextradata global GUI/SuppressMessages remindAboutAutoCapture,confirmInputCapture,remindAboutMouseIntegrationOn,remindAboutWrongColorDepth,confirmGoingFullscreen,remindAboutMouseIntegrationOff

}


#############
movemachinedef()
{
echo "copying VirtualBox.xml..."
cp /Users/Shared/vbox/VirtualBox.xml /Users/Shared/vbox/Library/VirtualBox/VirtualBox.xml
}


#############
fixsharedperms()
{
# fix permissions to /Users/Shared folders to full access for all users. Also runs at login from net/lib/sdob-ts/lish
echo "Fixing perms on /Users/Shared..."

logger -t [fixsharedperm] "Fixing perms on /Users/Shared"
chmod -R a+rXw /Users/Shared/
chown -R root:everyone /Users/Shared/
}

#############
cleanup()
{
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
}

#############
doitall()
{
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
}

#############
recreate()
{
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
}

#############
#create_umountwin()
#############
#umountwin()
#############
#vboxinstall()
#############
#makevboxfolders()
#############
#linkvboxlib()
#############
#makewin7vbox()
#############
#movemachinedef()
#############
#fixsharedperms()

$1

exit 0


