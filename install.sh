#!/bin/sh
echo "install and configure everything..."
echo "copying every script to the right place..."
sudo cp -R ./install/* /
echo "done! A restart is necessary!"
echo "sudo shutdown -r now" 
