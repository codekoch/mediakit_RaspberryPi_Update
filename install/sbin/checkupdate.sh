#!/bin/bash
## checkupdatescript for update system image
### Settings
### Path to image location
if !  [ -d "/media/pi/berryboot/data/FILES" ]; then
  sudo mkdir /media/pi/berryboot/data/FILES
fi
path="/media/pi/berryboot/data/FILES"
### Imagename
file="Mediakit.img256"
### Servername
server="http://images.mediakit.education"
function red_msg() {
echo -e "\\033[31;1m${@}\033[0m"
}
 
function green_msg() {
echo -e "\\033[32;1m${@}\033[0m"
}
function yellow_msg() {
echo -e "\\033[33;1m${@}\033[0m"
}
 
function blue_msg() {
echo -e "\\033[34;1m${@}\033[0m"
}
### check if Image exists on USB Stick
dataDevice="`cat /boot/cmdline.txt | awk -F'datadev=' '{print $2}' | awk '{print $1}'`"
### get usb-device-links
mapfile -t usbLinks < <(ls /dev/disk/by-id | grep -i 'usb' | grep -v 'part')
#usbLink=(`ls /dev/disk/by-id | grep -i 'usb' | grep -v 'part'`)
for entry in "${usbLinks[@]}"
do
usbDevice="`readlink -e /dev/disk/by-id/$entry`"
usbDevice="`ls $usbDevice* | tail -1`"
echo "check usbDevice=$usbDevice"
if ! [[ $usbDevice == *"$dataDevice"* ]]; then 
usbLink=$entry
break 
fi
echo "Skipped!It's the data device!"
done

echo "usblink="$usbLink
echo "usbDevice="$usbDevice

mkdir /media/pi/usbImage
sudo mount $usbDevice /media/pi/usbImage
usb="0"
sudo touch /$path/update.txt
sudo chmod 777 /$path/update.txt

if [ -e /media/pi/usbImage/$file ]; then
   green_msg "Found mediakit image file on USB drive!"
   usb="1"
   green_msg "USB" > /$path/update.txt
else
  sudo umount $usbDevice
fi
###
if ! [ -e $path/update.txt ]; then
  yellow_msg "Updatecheck not completed. Check if Mediakitsystem is already installed..."
  if ! [ -e /media/pi/berryboot/images/$file ]; then
    yellow_msg "No Mediakitsystem found. Try to get it from server"
    ### Image does not exists, so it should be downloaded
    license="`cat /boot/mediakit.lic`"
    green_msg "Found license!-->" $license
    rm $path/version.txt
    curl -u $license -o $path/version.txt -C - -O $server/version.txt 
    lines="`cat $path/version.txt | wc -l`"
    if [ $lines != "0" ]; then
      red_msg "IP and license not ok! Get a a valid license for your IP-adress...\nUpdate check cancelled."
      read -rsn1 -p"Press any key to continue";echo
      reboot 
    fi
    green_msg "IP and license ok"
    externalVersion="`cat $path/version.txt`"
    green_msg "Found Mediakit $externalVersion. Continue downloading imagefile..."
    rm $path/version.txt
    installUpdate=1
    finished="no"
    hashok="no"
    curl -u $license -o $path/$file -C - -O $server/$file 
    finished="yes"
    green_msg "Download finished!"
    # Check if File is not corrupted
    hash="1"
    rm $path/Mediakit.hash
    curl -u $license -o $path/Mediakit.hash -C - -O $server/Mediakit.hash
    hash="`cat $path/Mediakit.hash`"
    #echo "hash of downloaded file should be: $hash"
    yellow_msg "Checking downloaded file ... this will take some time...please wait..."
    localHash="0"
    md5sum $path/$file | awk '{ print $1}' > $path/Mediakitlocal.hash 
    localHash="`cat $path/Mediakitlocal.hash`"
    #echo "hash of downloaded file is: $localHash"
    if [ $hash != $localHash ]; then
      red_msg "Updatefile corrupted. Removing corrupted updatefile and retry."
      rm $path/$file
      sudo rm $path/update.txt
      #sudo reboot
    fi
    green_msg "Updatefilecheck ok ... continue..."
    green_msg "Mediakit $externalVersion ready to install" > /$path/update.txt
  else
    red_msg "Mediakitsystem already installed. Try to start update process in Mediakitsystem..."
    read -rsn1 -p"Press any key to restart";echo
    echo "$file" > /media/pi/berryboot/data/default
    sudo /sbin/bootIntoMediakit.sh
    exit
  fi
fi
if [ -e $path/$file ]; then
  green_msg "Install Update..."
  ### Overwrite old image
  yellow_msg "Moving image File..."  
  sudo mv $path/$file /media/pi/berryboot/images/
  ### Deleting all changes of old System
  sudo rm -R /media/pi/berryboot/data/$file
  ### Set new Image as default system
  sudo rm /media/pi/berryboot/data/default 
  echo "$file" > /media/pi/berryboot/data/default
  ### Reboot into new Image
  sudo /sbin/bootIntoMediakit.sh
  exit
fi
if  [ $usb != "0" ]; then
  yellow_msg "Copying image file..."
  sudo rm /media/pi/berryboot/images/$file 
  sudo cp /media/pi/usbImage/$file /media/pi/berryboot/images
  ### Deleting all changes of old System
  sudo rm -R /media/pi/berryboot/data/$file
  ### Set new Image as default system
  sudo rm /media/pi/berryboot/data/default
  sudo touch /media/pi/berryboot/data/default
  sudo chmod 777 /media/pi/berryboot/data/default
  echo "$file" > /media/pi/berryboot/data/default
  ### Reboot into new Image
  sudo umount $usbDevice
  red_msg "Please remove USB Stick!"
  read -rsn1 -p"Press key to start reboot";echo
  sudo /sbin/bootIntoMediakit.sh
  exit
else
  red_msg "Found update.txt but no downloaded Image. No update possible! Reboot and retry"
  sudo rm $path/update.txt
fi
read -rsn1 -p"Press any key to continue";echo
sudo reboot
exit

